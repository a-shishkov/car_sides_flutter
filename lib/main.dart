import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
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

List<CameraDescription> cameras = [];

late Map<String, tfl.Interpreter> interpreters;
late SharedPreferences prefs;

enum WhereInference { device, server }

Future<void> main() async {
  // print('main');
  // debugPrintGestureArenaDiagnostics = true;
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  prefs = await SharedPreferences.getInstance();
  interpreters['parts'] =
      await tfl.Interpreter.fromAsset('car_parts_smallest_fixed_anno.tflite');
  interpreters['damage'] = await tfl.Interpreter.fromAsset('car_damage.tflite');
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

  ImageExtender? originalIE;

  String? newImagePath;

  String? get originalImagePath {
    if (originalIE != null) {
      return originalIE!.path;
    } else {
      return null;
    }
  }

  bool predictionRunning = false;
  set setRunning(bool value) {
    setState(() {
      predictionRunning = value;
    });
  }

  bool connected = false;

  PredictionResult? predictResult;
  ValueNotifier<double> predictProgress = ValueNotifier(0.0);

  set setProgress(double value) {
    print('setProgress');
    predictProgress.value = value;
  }

  WhereInference? inferenceOn = WhereInference.device;
  Socket? socket;
  int resultSize = 0;
  Map lastResponse = Map();

  int selectedPage = 1;
  PageController pageController = PageController(
    initialPage: 1,
    keepPage: true,
  );

  bool get testPicture => prefs.getBool('testPicture') ?? false;

  @override
  void initState() {
    super.initState();

    initCameraController();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    socket?.close();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;

    FLog.info(
        className: "ImagePreviewPageState",
        methodName: "AppState",
        text: "state changed to: $state");

    if (state == AppLifecycleState.inactive) {
      cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initCameraController();
    }
  }

  void initCameraController() async {
    if (testPicture) return;

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

  Future trySaveExternal(String path) async {
    if (prefs.getBool('saveToDownloadDir') ?? false) {
      var imagePath = await predictResult!.image.saveToDownloadDir(path);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Image saved to $imagePath"),
      ));
    }
  }

  Future takePicture() async {
    var selectedTestImage =
        prefs.getString('selectedTestImage') ?? 'car_800_552.jpg';

    if (testPicture) {
      final byteData =
          await rootBundle.load('assets/images/$selectedTestImage');
      originalIE = ImageExtender.decodeImage(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      await originalIE!.saveToTempDir(selectedTestImage);
    } else {
      XFile file = await cameraController!.takePicture();
      originalIE = ImageExtender.decodeImageFromPath(file.path);
    }
  }

  startPrediction() async {
    /* if (!testPicture) {
      return;
    } */
    setProgress = 0.1;

    await takePicture();

    originalIE!.annotations = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PolygonPage(image: originalIE!)),
    );

    setRunning = true;

    var progressMsg = {
      0.0: "Nothing",
      0.1: "Taking picture",
      0.2: "Sending picture",
      0.3: "Start prediction",
      0.4: "Waiting for result",
      0.5: "Running model",
      0.55: "Receiving result (${filesize(resultSize)})",
      0.6: "Visualizing result",
      0.7: "Saving picture",
      0.9: "Rendering picture",
      1.0: "Done"
    };

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return ValueListenableBuilder(
              valueListenable: predictProgress,
              builder: (context, value, child) {
                return AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(
                        width: 10,
                      ),
                      Text(progressMsg[value] ?? 'No text')
                    ],
                  ),
                );
              });
        });

    inferenceOn = WhereInference.values[prefs.getInt('inferenceOn') ?? 0];
    switch (inferenceOn) {
      case WhereInference.device:
        predictionDevice();
        break;
      case WhereInference.server:
        predictionServer();
        break;
      default:
        break;
    }
  }

  Future predictionDevice() async {
    setProgress = 0.3;

    var modelType = prefs.getString('modelType') ?? 'parts';
    var address = interpreters[modelType]!.address;

    ReceivePort receivePort = ReceivePort();
    Completer sendPortCompleter = new Completer<SendPort>();

    receivePort.listen((message) async {
      print('<root> $message received');
      if (message is SendPort) {
        sendPortCompleter.complete(message);
      }
      // TODO: improve
      if (message is List) {
        String action = message[0];
        if (action == 'progress') {
          setProgress = message[1];
        } else if (action == 'result') {
          predictResult = message[1];

          if (predictResult != null) {
            var path =
                DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) + '.png';
            newImagePath = await predictResult!.image.saveToTempDir(path);
            await trySaveExternal(path);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('No instances found'),
            ));
          }
          Navigator.pop(context);
          setState(() {
            setProgress = 1.0;
            setRunning = false;
            if (predictResult != null) {
              onItemTapped(1);
            }
          });
        }
      }
    });

    await Isolate.spawn(predictIsolate, receivePort.sendPort);

    SendPort sendPort = await sendPortCompleter.future;
    sendPort.send(IsolateMsg(originalIE!, address, modelType));
  }

  predictionServer() async {
    var imageFile = File(originalImagePath!);
    var imageBytes = imageFile.readAsBytesSync();
    var imageEncoded = base64.encode(imageBytes);

    sendMessage(Uint8List.fromList(jsonEncode({
      'model': prefs.getString('modelType') ?? 'parts',
      'image': imageEncoded,
      'annotations': originalIE!.annotations != null
          ? List.generate(originalIE!.annotations!.length,
              (index) => originalIE!.annotations![index].toMap)
          : null
    }).codeUnits));
  }

  processResponse(List<int> message) async {
    lastResponse = jsonDecode(String.fromCharCodes(message));
    print("Server: ${lastResponse['response']}");

    // TODO: switch
    if (lastResponse['response'] == 'Downloaded') {
      setProgress = 0.5;
    } else if (lastResponse['response'] == 'Sending') {
      setState(() {
        resultSize = lastResponse['size'];
      });
      setProgress = 0.55;
      print("Downloading ${lastResponse['size']} bytes");
    } else if (lastResponse['response'] == 'Error') {
      socket!.destroy();

      prefs.setInt('inferenceOn', WhereInference.device.index);
      setState(() {
        originalIE = null;
        inferenceOn = WhereInference.device;
        connected = false;
        setRunning = false;
      });
      Navigator.pop(context);
    } else if (lastResponse['response'] == 'MasksResults' ||
        lastResponse['response'] == 'NoMasksResults') {
      ImageExtender? image;

      if (lastResponse['class_ids'].length > 0) {
        setProgress = 1.0;

        if (lastResponse['response'] == 'MasksResults') {
          var classNames;
          var modelType = prefs.getString('modelType') ?? 'parts';
          if (modelType == 'parts') {
            classNames = CarPartsConfig.CLASS_NAMES;
          } else if (modelType == 'damage') {
            classNames = CarDamageConfig.CLASS_NAMES;
          }

          image = await displayInstances(originalIE!, lastResponse['rois'],
              lastResponse['masks'], lastResponse['class_ids'], classNames,
              scores: lastResponse['scores']);

          setProgress = 0.7;
          predictResult = PredictionResult.fromResult(image, lastResponse);
        } else {
          var imageDecoded = base64Decode(lastResponse['image']);
          image = ImageExtender.decodeImage(imageDecoded);
          predictResult = PredictionResult.noMask(image, lastResponse);
          // lastResponse = Map();
        }
        var path = DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) +
            '_server.png';
        await image.saveToTempDir(path);
        await trySaveExternal(path);
      } else {
        predictResult = null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No instances found'),
        ));
      }
      setState(() {
        Navigator.pop(context);
        setProgress = 1.0;
        setRunning = false;
        if (predictResult != null) {
          onItemTapped(1);
        }
      });
    }
  }

  void listenSocket() {
    void _resetToDevice() {
      prefs.setInt('inferenceOn', WhereInference.device.index);
      setState(() {
        originalIE = null;
        setProgress = 1.0;
        inferenceOn = WhereInference.device;
        connected = false;
        predictionRunning = false;
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

      // handle errors
      onError: (error) {
        print("onError $error");
        socket!.destroy();
        _resetToDevice();
      },

      // handle server ending connection
      onDone: () {
        print('Server left. Done');
        socket!.destroy();
        _resetToDevice();
      },
    );
  }

  void sendMessage(Uint8List message) {
    print('messageLength ${message.length}');
    var msgSize = ByteData(4);
    msgSize.setInt32(0, message.length);
    socket!.add(msgSize.buffer.asUint8List());
    socket!.add(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: selectedPage == 1 ? Colors.black : null,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WillPopScope(
          onWillPop: () => Future.sync(onWillPop), child: buildPageView()),
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: predictionRunning ? Colors.transparent : null,
          highlightColor: predictionRunning ? Colors.transparent : null,
        ),
        child: BottomNavigationBar(
          currentIndex: selectedPage,
          onTap: onItemTapped,
          selectedItemColor: predictionRunning
              ? Theme.of(context).colorScheme.background
              : Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
          unselectedItemColor: predictionRunning
              ? Colors.grey[400]
              : Theme.of(context).unselectedWidgetColor,
          backgroundColor: Theme.of(context).canvasColor,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.image),
              label: 'Image',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.camera,
                color: selectedPage == 1 ? Colors.transparent : null,
              ),
              label: 'Camera',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
      floatingActionButton: selectedPage == 1
          ? FloatingActionButton(
              onPressed: startPrediction,
              tooltip: 'Pick Image',
              child: Icon(Icons.camera))
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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

  void pageChanged(int index) {
    setState(() {
      selectedPage = index;
    });
  }

  void onItemTapped(int index) {
    if (selectedPage == 2 && index == 1) {
      if (testPicture && cameraController != null) {
        cameraController!.dispose();
        cameraController = null;
      } else if (!testPicture && cameraController == null) {
        initCameraController();
      }
    }

    if (!predictionRunning) {
      setState(() {
        selectedPage = index;
        pageController.jumpToPage(index);
      });
    }
  }

  Widget buildPageView() {
    return PageView(
      controller: pageController,
      physics: NeverScrollableScrollPhysics(),
      onPageChanged: pageChanged,
      children: [
        MrcnnPage(predictResult, prefs),
        CameraPage(cameraController, prefs, connectSocket, destroySocket),
        SettingsPage(prefs),
      ],
    );
  }

  Future<bool> connectSocket(String ip, int port) async {
    try {
      socket = await Socket.connect(ip, port, timeout: Duration(seconds: 5));
      prefs.setString('serverIP', ip);
      listenSocket();
      connected = true;
      return true;
    } on SocketException {
      prefs.setInt('inferenceOn', WhereInference.device.index);
      inferenceOn = WhereInference.device;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Can't connect to server"),
      ));
      return false;
    }
  }

  destroySocket() {
    socket?.destroy();
    // TODO: do need connected
  }
}
