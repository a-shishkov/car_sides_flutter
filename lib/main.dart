import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter_app/mrcnn/config.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:flutter_app/pages.dart';
import 'package:flutter_app/utils/image_extender.dart';
import 'package:flutter_app/utils/isolate_utils.dart';
import 'package:camera/camera.dart';
import 'package:flutter_app/utils/prediction_result.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regexed_validator/regexed_validator.dart';

List<CameraDescription> cameras = [];
late tfl.Interpreter interpreter;
late SharedPreferences prefs;

enum WhereInference { device, server }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  prefs = await SharedPreferences.getInstance();
  interpreter =
      await tfl.Interpreter.fromAsset('car_parts_smallest_fixed_anno.tflite');

  runApp(MyApp());
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
      home: LoaderOverlay(child: MyHomePage('TF Car Sides')),
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
  late CameraController controller;

  String? selectedTestImage =
      prefs.getString('selectedTestImage') ?? 'car_800_552.jpg';
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
  bool connected = false;

  PredictionResult? predictResult;
  double predictProgress = 0.0;

  WhereInference? inferenceOn = WhereInference.device;
  String serverIP = '';
  int serverPort = 65432;
  late Socket socket;
  int resultSize = 0;
  Map lastResponse = Map();

  TextEditingController textControllerIP = TextEditingController();
  TextEditingController textControllerPort = TextEditingController();

  int _selectedIndex = 0;
  PageController pageController = PageController(
    initialPage: 0,
    keepPage: true,
  );

  void initializeCameraController() {
    controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();

    serverIP = prefs.getString('serverIP') ?? '';

    textControllerIP.text = serverIP;
    textControllerPort.text = serverPort.toString();

    initializeCameraController();
    WidgetsBinding.instance!.addObserver(this);

    initImages();
  }

  @override
  void dispose() {
    // controller.dispose();
    socket.close();

    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;
    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    FLog.info(
        className: "ImagePreviewPageState",
        methodName: "AppState",
        text: "state changed to: $state");

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initializeCameraController();
    }
  }

  Future initImages() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');

    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    var imagePaths = manifestMap.keys
        .where((String key) => key.contains('images/'))
        .toList();

    imagePaths = List.generate(
        imagePaths.length, (index) => imagePaths[index].split('/').last);

    await prefs.setStringList('testImagesList', imagePaths);

    setState(() {});
  }

  Future saveExternal(String path) async {
    if (prefs.getBool('saveToDownloadDir') ?? false) {
      var imagePath = await predictResult!.image.saveToDownloadDir(path);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Image saved to $imagePath"),
      ));
    }
  }

  Future takePicture() async {
    var testPicture = prefs.getBool('testPicture') ?? false;
    selectedTestImage =
        prefs.getString('selectedTestImage') ?? selectedTestImage;

    if (testPicture) {
      final byteData =
          await rootBundle.load('assets/images/$selectedTestImage');
      originalIE = ImageExtender.decodeImage(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      await originalIE!.saveToTempDir(selectedTestImage);
    } else {
      XFile file = await controller.takePicture();
      originalIE = ImageExtender.decodeImageFromPath(file.path);
    }
  }

  Future predictionDevice() async {
    if (!controller.value.isInitialized || predictionRunning) {
      return;
    }

    setState(() {
      predictProgress = 0.1;
      predictionRunning = true;
    });

    await takePicture();

    setState(() {
      predictProgress = 0.3;
    });

    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(predictIsolate, receivePort.sendPort);

    setState(() {
      predictProgress = 0.4;
    });
    SendPort sendPort = await receivePort.first;

    var msg = await sendReceive(
        sendPort, IsolateMsg(originalIE, interpreter.address));
    setState(() {
      predictProgress = msg[0];
    });
    sendPort = msg[1];

    msg = await sendReceive(sendPort);
    setState(() {
      predictProgress = msg[0];
    });
    sendPort = msg[1];

    predictResult = await sendReceive(sendPort);

    setState(() {
      predictProgress = 0.7;
    });
    if (predictResult != null) {
      var path =
          DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) + '.png';
      newImagePath = await predictResult!.image.saveToTempDir(path);

      await saveExternal(path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No instances found'),
      ));
    }
    setState(() {
      predictProgress = 1.0;
      predictionRunning = false;
      if (predictResult != null) {
        _onItemTapped(1);
      }
    });
  }

  predictionServer() async {
    if (!controller.value.isInitialized || predictionRunning) {
      return;
    }
    predictionRunning = true;

    await takePicture();

    setState(() {
      predictProgress = 0.2;
    });

    var imageFile = File(originalImagePath!);
    var fileBytes = imageFile.readAsBytesSync();

    sendMessage(fileBytes);
  }

  processResponse(List<int> message) async {
    if (lastResponse['response'] != 'NoMasksResults') {
      lastResponse = jsonDecode(String.fromCharCodes(message));
      print("Server: ${lastResponse['response']}");

      if (lastResponse['response'] == 'Downloaded') {
        setState(() {
          predictProgress = 0.5;
        });
      } else if (lastResponse['response'] == 'Sending') {
        setState(() {
          resultSize = lastResponse['size'];
          predictProgress = 0.55;
        });
        print("Downloading ${lastResponse['size']} bytes");
      } else if (lastResponse['response'] == 'Error') {
        socket.destroy();

        setState(() {
          originalIE = null;
          inferenceOn = WhereInference.device;
          connected = false;
          predictionRunning = false;
        });
      } else if (lastResponse['response'] == 'MasksResults') {
        ImageExtender? image;

        if (lastResponse['class_ids'].length > 0) {
          setState(() {
            predictProgress = 1.0;
          });
          image = await displayInstances(
              originalIE!,
              lastResponse['rois'],
              lastResponse['masks'],
              lastResponse['class_ids'],
              CarPartsConfig.CLASS_NAMES,
              scores: lastResponse['scores']);

          setState(() {
            predictProgress = 0.7;
          });
          var path = DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) +
              '_server.png';
          await image.saveToTempDir(path);

          predictResult = PredictionResult.fromResult(image, lastResponse);

          await saveExternal(path);
        } else {
          predictResult = null;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('No instances found'),
          ));
        }
        setState(() {
          predictProgress = 1.0;
          predictionRunning = false;
          if (predictResult != null) {
            _onItemTapped(1);
          }
        });
      }
    } else {
      if (lastResponse['class_ids'].length > 0) {
        setState(() {
          predictProgress = 1.0;
        });
        var image = ImageExtender.decodeImage(message);
        var path = DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) +
            '_server.png';
        await image.saveToTempDir(path);

        predictResult = PredictionResult.noMask(image, lastResponse);
      } else {
        predictResult = null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No instances found'),
        ));
      }
      lastResponse = Map();
      setState(() {
        predictProgress = 1.0;
        predictionRunning = false;
        if (predictResult != null) {
          _onItemTapped(1);
        }
      });
    }
  }

  void listenSocket() {
    print('Connected to: ${socket.remoteAddress.address}:${socket.remotePort}');

    bool firstMessage = true;
    int readLen = 0;
    int msgLen = 0;
    List<int> msg = List.empty(growable: true);

    socket.listen(
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
        socket.destroy();

        setState(() {
          originalIE = null;
          predictProgress = 1.0;
          inferenceOn = WhereInference.device;
          connected = false;
          predictionRunning = false;
        });
      },

      // handle server ending connection
      onDone: () {
        print('Server left. Done');
        socket.destroy();

        setState(() {
          originalIE = null;
          predictProgress = 1.0;
          inferenceOn = WhereInference.device;
          connected = false;
          predictionRunning = false;
        });
      },
    );
  }

  void sendMessage(Uint8List message) {
    var msgSize = ByteData(4);
    msgSize.setInt32(0, message.length);
    socket.add(msgSize.buffer.asUint8List());
    socket.add(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          selectedItemColor: predictionRunning
              ? Theme.of(context).colorScheme.background
              : null,
          unselectedItemColor: predictionRunning ? Colors.grey[400] : null,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.camera),
              label: 'Camera',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.image),
              label: 'Image',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
      floatingActionButton: _selectedIndex == 0 && !predictionRunning
          ? FloatingActionButton(
              onPressed: inferenceOn == WhereInference.device
                  ? predictionDevice
                  : predictionServer,
              tooltip: 'Pick Image',
              child: Icon(Icons.add_a_photo))
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  bool onWillPop() {
    if (pageController.page!.round() == pageController.initialPage)
      return true;
    else {
      pageController.previousPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.ease,
      );
      return false;
    }
  }

  void _pageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    if (!predictionRunning) {
      setState(() {
        _selectedIndex = index;
        pageController.jumpToPage(index);
      });
    }
  }

  Widget buildPageView() {
    return PageView(
      controller: pageController,
      physics: NeverScrollableScrollPhysics(),
      onPageChanged: _pageChanged,
      children: [
        cameraPage(),
        MrcnnPage(predictResult),
        SettingsPage(prefs),
      ],
    );
  }

  Widget cameraPage() {
    var progressMsg = {
      0.0: "Nothing",
      0.1: "Taking picture",
      0.2: "Sending picture",
      0.3: "Start prediction",
      0.4: "Waiting for result",
      0.5: "Running model",
      0.55: "Receiving result\n(${filesize(resultSize)})",
      0.6: "Visualizing result",
      0.7: "Saving picture",
      0.9: "Rendering picture",
      1.0: "Done"
    };

    if (!predictionRunning) {
      if (prefs.getBool('testPicture') ?? false) {
        selectedTestImage =
            prefs.getString('selectedTestImage') ?? selectedTestImage;
        final testImages = prefs.getStringList('testImagesList') ?? [];
        final List<DropdownMenuItem<String>> dropdownItems = List.generate(
            testImages.length,
            (index) => DropdownMenuItem(
                  child: Text(index.toString()),
                  value: testImages[index],
                ));
        return Container(
          color: Colors.black,
          child: Column(
            children: [
              Container(
                  width: double.infinity,
                  // height: double.infinity,
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    children: [
                      Flexible(child: deviceServerContainer()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: DropdownButton(
                          value: selectedTestImage,
                          items: dropdownItems,
                          onChanged: (String? value) {
                            prefs.setString('selectedTestImage', value!);
                            setState(() {
                              selectedTestImage = value;
                            });
                          },
                        ),
                      )
                    ],
                  )),
              Expanded(child: Image.asset('assets/images/$selectedTestImage')),
            ],
          ),
        );
      } else if (controller.value.isInitialized) {
        return Container(
          color: Colors.black,
          child: Stack(
            alignment: AlignmentDirectional.topCenter,
            children: [
              FutureBuilder(
                  future: Future.delayed(const Duration(milliseconds: 300)),
                  builder: (context, snapshot) {
                    print(
                        "snapshot.connectionState ${snapshot.connectionState}");
                    if (snapshot.connectionState == ConnectionState.done) {
                      return CameraPreview(controller);
                    } else {
                      return Container(
                          color: Colors.black,
                          child: Center(child: CircularProgressIndicator()));
                    }
                  }),
              Container(
                  width: double.infinity,
                  // height: double.infinity,
                  color: Theme.of(context).colorScheme.surface,
                  child: deviceServerContainer()),
            ],
          ),
        );
      } else {
        return Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
    } else if (originalImagePath != null) {
      return Container(
        color: Colors.black,
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            Image.file(File(originalImagePath!)),
            Container(
              width: 150,
              height: 150,
              // color: Colors.white.withOpacity(0.2),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  border: Border.all(
                    color: Colors.transparent,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(20))),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: predictProgress,
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Text(
                      progressMsg[predictProgress]!,
                      style: TextStyle(color: Colors.white),
                    ),
                  ]),
            ),
          ],
        ),
      );
    } else {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }

  Widget deviceServerContainer() {
    return Row(
      children: [
        Flexible(
            child: RadioListTile(
                title: Text("Device"),
                value: WhereInference.device,
                groupValue: inferenceOn,
                onChanged: (WhereInference? value) {
                  setState(() {
                    inferenceOn = value;
                  });
                  if (connected) {
                    showDialog(
                        barrierDismissible: false,
                        context: context,
                        builder: (context) => AlertDialog(
                              title: Text("Disconnect from server?"),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      setState(() {
                                        inferenceOn = WhereInference.server;
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: Text("No")),
                                TextButton(
                                    onPressed: () {
                                      socket.destroy();
                                      setState(() {
                                        connected = false;
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: Text("Yes"))
                              ],
                            ));
                  }
                })),
        Flexible(
          child: RadioListTile(
              title: Text("Server"),
              subtitle: connected ? Text("Connected") : Text("Disconnected"),
              value: WhereInference.server,
              groupValue: inferenceOn,
              onChanged: (WhereInference? value) async {
                setState(() {
                  inferenceOn = value;
                });
                await showDialog(
                    barrierDismissible: false,
                    context: context,
                    builder: (context) {
                      return connectAlertDialog();
                    });
                setState(() {});
              }),
        ),
      ],
    );
  }

  Widget connectAlertDialog() {
    bool connecting = false;
    bool validateIP = true;
    bool validatePort = true;

    return StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: connecting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Connect to server"),
                  SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator())
                ],
              )
            : Text("Connect to server"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textControllerIP,
              decoration: InputDecoration(
                  labelText: "Server IP",
                  errorText: validateIP ? null : "Wrong IP"),
              onChanged: (String value) {
                if (!validateIP) {
                  setState(() {
                    validateIP = validator.ip(textControllerIP.text);
                  });
                }
                serverIP = value;
              },
            ),
            TextField(
              controller: textControllerPort,
              decoration: InputDecoration(
                  labelText: "Server port",
                  errorText: validatePort ? null : "Wrong port"),
              onChanged: (String value) {
                try {
                  serverPort = int.parse(value);
                  setState(() {
                    validatePort = true;
                  });
                } on FormatException {
                  setState(() {
                    validatePort = false;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: connecting
                  ? null
                  : () {
                      setState(() {
                        inferenceOn = WhereInference.device;
                      });
                      Navigator.pop(context);
                    },
              child: Text("Cancel")),
          TextButton(
              onPressed: connecting
                  ? null
                  : () async {
                      print("validator ${validator.ip(textControllerIP.text)}");
                      if (!validator.ip(textControllerIP.text)) {
                        setState(() {
                          validateIP = false;
                        });
                      } else {
                        setState(() {
                          validateIP = true;
                          connecting = true;
                        });

                        try {
                          socket = await Socket.connect(serverIP, serverPort,
                              timeout: Duration(seconds: 5));
                          prefs.setString('serverIP', serverIP);
                          listenSocket();

                          connected = true;
                          connecting = false;
                        } on SocketException {
                          inferenceOn = WhereInference.device;
                          connecting = false;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Can't connect to server"),
                          ));
                        }
                        Navigator.pop(context);
                      }
                    },
              child: Text("OK"))
        ],
      );
    });
  }
}
