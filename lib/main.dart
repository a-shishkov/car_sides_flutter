import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:enum_to_string/camel_case_to_words.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter_app/mrcnn/configs.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:flutter_app/pages/CameraPage.dart';
import 'package:flutter_app/pages/MrcnnPage.dart';
import 'package:flutter_app/pages/SettingsPage.dart';
import 'package:flutter_app/pages/polygon_page/AnnotationPage.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'package:flutter_app/utils/isolate_utils.dart';
import 'package:camera/camera.dart';
import 'package:flutter_app/utils/prediction_result.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

List<CameraDescription> cameras = [];

Map<ModelType, tfl.Interpreter> interpreters = {};
late SharedPreferences prefs;

enum WhereInference { device, server }
enum ModelType { damage, parts }

Future<void> main() async {
  // debugPrintGestureArenaDiagnostics = true;
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  prefs = await SharedPreferences.getInstance();
  interpreters[ModelType.parts] =
      await tfl.Interpreter.fromAsset('car_parts_smallest_fixed_anno.tflite');
  interpreters[ModelType.damage] =
      await tfl.Interpreter.fromAsset('car_damage.tflite');
  initImages();
  runApp(MyApp());
}

Future initImages() async {
  final manifestContent = await rootBundle.loadString('AssetManifest.json');

  final Map<String, dynamic> manifestMap = json.decode(manifestContent);

  var imagePaths =
      manifestMap.keys.where((String key) => key.contains('images/')).toList();

  imagePaths = List.generate(
      imagePaths.length, (index) => imagePaths[index].split('/').last);

  await prefs.setStringList('testImagesList', imagePaths);
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: MyHomePage('TF Car Sides'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage(this.title, {Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  CameraController? cameraController;

  TextEditingController ipController = TextEditingController()
    ..text = prefs.getString('ip') ?? '';
  TextEditingController portController = TextEditingController()
    ..text = prefs.getString('port') ?? '';

  bool saveExternal = prefs.getBool('saveExternal') ?? false;

  bool testImage = prefs.getBool('testImage') ?? false;

  bool predictDialogShowing = false;
  bool get cameraEnabled => !testImage;

  List imageItems = prefs.getStringList('testImagesList') ?? [];

  int selectedImage = prefs.getInt('selectedImage') ?? 0;

  ModelType model = ModelType.values[prefs.getInt('model') ?? 0];

  bool socketConnected = false;

  /* ValueNotifier<double> predictProgress = ValueNotifier(0.0);
  set setProgress(double value) {
    print('setProgress');
    predictProgress.value = value;
  } */
  final ValueNotifier<String> predictMessage = ValueNotifier('');
  set setPredictMessage(String message) => predictMessage.value = message;

  WhereInference inferenceOn = WhereInference.device;

  Socket? socket;

  int resultSize = 0;

  int selectedPage = 1;
  PageController pageController = PageController(
    initialPage: 1,
    keepPage: true,
  );

  ImageExtender? image;

  @override
  void initState() {
    initCameraController();
    WidgetsBinding.instance!.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    socket?.close();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('state changed to: $state');
    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;

    if (state == AppLifecycleState.inactive) {
      cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initCameraController();
    }
  }

  void initCameraController() async {
    if (!cameraEnabled) return;
    if (cameraController != null) await cameraController!.dispose();

    cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    cameraController!.addListener(() {
      if (mounted) setState(() {});
      if (cameraController!.value.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Camera error ${cameraController!.value.errorDescription}')));
      }
    });

    try {
      await cameraController!.initialize();
    } on CameraException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() {});
  }

  Future saveResultExternal(String path) async {
    if (!saveExternal) return;
    var imagePath = await image?.prediction?.image.saveToDownloadDir(path);
    if (imagePath != null)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Image saved to $imagePath'),
      ));
  }

  startPrediction() async {
    if (inferenceOn == WhereInference.device) {
      var deviceInfo = DeviceInfoPlugin();
      var androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.isPhysicalDevice != null &&
          !androidInfo.isPhysicalDevice!) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Can\'t run prediction on emulator')));
        return;
      }
    }

    if (cameraEnabled) {
      XFile file = await cameraController!.takePicture();
      image = ImageExtender.decodeImageFromPath(file.path);
    } else {
      var path = 'assets/images/${imageItems[selectedImage]}';
      final byteData = await rootBundle.load(path);
      image = ImageExtender.decodeImage(Uint8List.view(byteData.buffer))
        ..path = path
        ..isAsset = true;
    }
    image!.annotations = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PolygonPage(image: image!)),
    );

    predictDialogShowing = true;
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return ValueListenableBuilder(
              valueListenable: predictMessage,
              builder: (BuildContext context, String value, Widget? child) {
                return AlertDialog(
                  content: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [CircularProgressIndicator(), Text(value)],
                  ),
                );
              });
        }).then((value) => predictDialogShowing = value);

    switch (inferenceOn) {
      case WhereInference.device:
        var address = interpreters[model]!.address;

        ReceivePort receivePort = ReceivePort();
        Completer sendPortCompleter = new Completer<SendPort>();

        receivePort.listen((message) async {
          print('<root> $message received');
          if (message is SendPort)
            sendPortCompleter.complete(message);
          else if (message is String)
            setPredictMessage = message;
          else if (message is PredictionResult) {
            image!.prediction = message;
            var path = DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) +
                '_device.png';
            await image!.prediction!.image.saveToTempDir(path);
            saveResultExternal(path);
            if (predictDialogShowing) Navigator.of(context).pop(false);
            jumpToPage(0);
          } else if (message == null) {
            if (predictDialogShowing) Navigator.of(context).pop(false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('No instances found'),
            ));
          }
        });

        await Isolate.spawn(predictIsolate, receivePort.sendPort);

        SendPort sendPort = await sendPortCompleter.future;
        sendPort.send(IsolateMsg(image!, address, model));
        break;

      case WhereInference.server:
        void _sendMessage(Uint8List message) {
          print('messageLength ${message.length}');
          var msgSize = ByteData(4);
          msgSize.setInt32(0, message.length);
          socket!.add(msgSize.buffer.asUint8List());
          socket!.add(message);
        }

        var imageEncoded = base64.encode(image!.encodeJpg);
        _sendMessage(Uint8List.fromList(jsonEncode({
          'model': EnumToString.convertToString(model),
          'image': imageEncoded,
          'annotations': image!.mapAnnotations
        }).codeUnits));
        break;
    }
  }

  processResponse(List<int> message) async {
    Map response = jsonDecode(String.fromCharCodes(message));
    print('Server: ${response['response']}');

    switch (response['response']) {
      case 'Message':
        print(response['message']);
        setPredictMessage = response['message'];
        break;
      case 'Error':
        throw SocketException('Server sended error');
      case 'Results':
        var img;
        if (response.containsKey('masks'))
          img = await displayInstances(image!, response['rois'],
              response['masks'], response['class_ids'], CLASS_NAMES[model],
              scores: response['scores']);
        else {
          var imageDecoded = base64Decode(response['image']);
          img = ImageExtender.decodeImage(imageDecoded);
        }
        var path = DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) +
            '_server.png';
        await img.saveToTempDir(path);
        saveResultExternal(path);

        image!.prediction = PredictionResult.fromResult(img, response, model);
        if (predictDialogShowing) Navigator.of(context).pop(false);
        jumpToPage(0);
        break;
      case 'NoResults':
        if (predictDialogShowing) Navigator.of(context).pop(false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No instances found'),
        ));
        break;
    }
  }

  void listenSocket() {
    void _resetToDevice() {
      setState(() {
        image = null;
        inferenceOn = WhereInference.device;
        socketConnected = false;
      });
    }

    print(
        'Connected to: ${socket!.remoteAddress.address}:${socket!.remotePort}');

    bool firstMessage = true;
    int readLen = 0;
    int msgLen = 0;
    List<int> msg = List.empty(growable: true);

    socket!.listen(
      (Uint8List data) async {
        while (true) {
          if (firstMessage) {
            readLen = 0;
            msg.clear();
            msgLen = ByteData.view(data.sublist(0, 4).buffer)
                .getInt32(0, Endian.big);
            data = data.sublist(4, data.length);
            firstMessage = false;
          }

          if (data.length + readLen < msgLen) {
            msg.addAll(data);
            readLen += data.length;
            break;
          } else {
            msg.addAll(data.sublist(0, msgLen - readLen));

            // TODO: do i really need await?
            await processResponse(msg);

            firstMessage = true;
            if (data.length + readLen == msgLen) {
              break;
            }
            data = data.sublist(msgLen - readLen);
          }
        }
      },
      onError: (error) {
        print('onError $error');
        socket!.destroy();
        _resetToDevice();
      },
      onDone: () {
        print('Server left. Done');
        socket!.destroy();
        _resetToDevice();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: selectedPage == 1 ? Colors.black : null,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WillPopScope(
        onWillPop: () => Future.sync(onWillPop),
        child: PageView(
          controller: pageController,
          physics: NeverScrollableScrollPhysics(),
          onPageChanged: (int index) {
            setState(() {
              selectedPage = index;
            });

            if (index == 1)
              initCameraController();
            else {
              cameraController?.dispose();
              cameraController = null;
            }
          },
          children: [
            MrcnnPage(image),
            CameraPage(
              cameraController: cameraController,
              cameraEnabled: cameraEnabled,
              imageItems: imageItems,
              initialImage: selectedImage,
              inferenceOn: inferenceOn,
              onTakePicture: startPrediction,
              onChangedDevice: changeDevice,
              onChangedServer: changeServer,
              onImageChanged: (int index) {
                selectedImage = index;
              },
            ),
            SettingsPage(
              saveExternal: saveExternal,
              onSaveExternal: (bool value) {
                setState(() {
                  saveExternal = value;
                });
                prefs.setBool('saveExternal', value);
              },
              testImage: testImage,
              onTestImage: (bool value) {
                setState(() {
                  testImage = value;
                });
                prefs.setBool('testImage', value);
              },
              model: model,
              onModelType: (ModelType? value) {
                setState(() {
                  model = value!;
                });
                prefs.setInt('model', value!.index);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedPage,
        onTap: jumpToPage,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.image),
            label: 'Image',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.camera,
            ),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  bool onWillPop() {
    if (pageController.page!.round() == pageController.initialPage)
      return true;
    else {
      selectedPage -= 1;
      pageController.jumpToPage(selectedPage);
      return false;
    }
  }

  void jumpToPage(int index) {
    setState(() {
      selectedPage = index;
      pageController.jumpToPage(index);
    });
  }

  changeDevice() {
    print('changeDevice');
    if (inferenceOn == WhereInference.device) return;

    setState(() {
      inferenceOn = WhereInference.device;
    });

    if (socketConnected)
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
                content: Text('Disconnect from server?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        inferenceOn = WhereInference.server;
                      });
                      Navigator.pop(context);
                    },
                    child: Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      socket!.destroy();
                      setState(() {
                        socketConnected = false;
                      });
                      Navigator.pop(context);
                    },
                    child: Text('Yes'),
                  )
                ]);
          });
  }

  changeServer() async {
    if (inferenceOn == WhereInference.server) return;

    setState(() {
      inferenceOn = WhereInference.server;
    });

    var result = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            scrollable: true,
            title: const Text('Connect to server'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ipController,
                  decoration: InputDecoration(labelText: 'Server IP'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: portController,
                  decoration: InputDecoration(labelText: 'Server port'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    inferenceOn = WhereInference.device;
                  });
                  Navigator.pop(context, false);
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: Text('Connect'),
              ),
            ],
          );
        });
    if (!result) return;
    print('changeServer');

    var ip = ipController.text;
    var port = int.parse(portController.text);

    Socket.connect(ip, port, timeout: Duration(seconds: 5)).then((value) {
      socket = value;
      listenSocket();
      socketConnected = true;

      prefs.setString('ip', ipController.text);
      prefs.setString('port', portController.text);
    }).catchError((e) {
      print('Socket connect error $e');
      setState(() {
        inferenceOn = WhereInference.device;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Can\'t connect to server'),
      ));
    });
  }
}
