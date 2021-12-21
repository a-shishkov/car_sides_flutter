import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
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

  String? testImageName =
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
  Socket? socket;

  TextEditingController textControllerIP = TextEditingController();
  TextEditingController textControllerPort = TextEditingController();

  bool validateIP = true;
  bool validatePort = true;

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
  }

  @override
  void dispose() {
    controller.dispose();
    if (socket != null) {
      socket!.close();
    }
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
    testImageName = prefs.getString('selectedTestImage') ?? testImageName;

    if (testPicture) {
      final byteData = await rootBundle.load('assets/$testImageName');
      originalIE = ImageExtender.decodeImage(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      await originalIE!.saveToTempDir(testImageName);
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
    if (socket != null) {
      predictionRunning = true;

      await takePicture();

      setState(() {
        predictProgress = 0.2;
      });

      var imageFile = File(originalImagePath!);
      var fileBytes = imageFile.readAsBytesSync();

      sendMessage(fileBytes);
    }
  }

  void listenSocket() {
    print(
        'Connected to: ${socket!.remoteAddress.address}:${socket!.remotePort}');

    String fullData = '';

    socket!.listen(
      (Uint8List data) async {
        print('Got answer');
        final serverResponse = String.fromCharCodes(data);

        if (serverResponse[0] == '{') {
          fullData = serverResponse;
          print('Answer beginning');
        } else {
          fullData += serverResponse;
        }

        if (fullData[fullData.length - 1] == '}') {
          print('Answer END');
          var response = jsonDecode(fullData);
          print("Server: ${response['response']}");

          if (response['response'] == 'Downloaded') {
            setState(() {
              predictProgress = 0.5;
            });
          } else if (response['response'] == 'Error') {
            socket!.destroy();

            setState(() {
              originalIE = null;
              inferenceOn = WhereInference.device;
              connected = false;
              predictionRunning = false;
            });
          } else if (response['response'] == 'Results') {
            ImageExtender? image;

            if (response['class_ids'].length > 0) {
              image = displayInstances(
                  originalIE!,
                  response['rois'],
                  response['masks'],
                  response['class_ids'],
                  CarPartsConfig.CLASS_NAMES,
                  scores: response['scores']);

              setState(() {
                predictProgress = 0.7;
              });
              var path =
                  DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) +
                      '_server.png';
              await image.saveToTempDir(path);

              predictResult = PredictionResult.fromResult(image, response);

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
        }
      },

      // handle errors
      onError: (error) {
        print(error);
        socket!.destroy();

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
        print('Server left.');
        socket!.destroy();

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
    socket!.add(msgSize.buffer.asUint8List());
    socket!.add(message);
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
      0.6: "Visualizing result",
      0.7: "Saving picture",
      0.9: "Rendering picture",
      1.0: "Done"
    };

    if (!predictionRunning) {
      if (prefs.getBool('testPicture') ?? false) {
        testImageName = prefs.getString('selectedTestImage') ?? testImageName;
        return Container(
          color: Colors.black,
          child: Stack(
            alignment: AlignmentDirectional.topCenter,
            children: [
              Center(child: Image.asset('assets/$testImageName')),
              deviceServerContainer(),
            ],
          ),
        );
      } else if (controller.value.isInitialized) {
        return Container(
          color: Colors.black,
          child: Stack(
            alignment: AlignmentDirectional.topCenter,
            children: [
              CameraPreview(controller),
              deviceServerContainer(),
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
    return Container(
      width: double.infinity,
      // height: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
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
                                        socket!.destroy();
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
                onChanged: (WhereInference? value) {
                  setState(() {
                    inferenceOn = value;
                  });
                  showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder: (context) {
                        return connectAlertDialog();
                      });
                }),
          ),
        ],
      ),
    );
  }

  AlertDialog connectAlertDialog() {
    return AlertDialog(
      title: Text("Connect to server"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: textControllerIP,
            decoration: InputDecoration(
                labelText: "Server IP",
                errorText: validateIP ? null : "Wrong IP"),
            onChanged: (String value) {
              serverIP = value;
            },
          ),
          TextField(
            controller: textControllerPort,
            decoration: InputDecoration(labelText: "Server port"),
            onChanged: (String value) {
              serverPort = int.parse(value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () {
              setState(() {
                inferenceOn = WhereInference.device;
              });
              Navigator.pop(context);
            },
            child: Text("Cancel")),
        TextButton(
            onPressed: () async {
              print("validator ${validator.ip(textControllerIP.text)}");
              if (!validator.ip(textControllerIP.text)) {
                setState(() {
                  validateIP = false;
                });
              } else {
                setState(() {
                  validateIP = true;
                });
                try {
                  socket = await Socket.connect(serverIP, serverPort,
                      timeout: Duration(seconds: 5));
                  prefs.setString('serverIP', serverIP);
                  listenSocket();
                  setState(() {
                    connected = true;
                  });
                } on SocketException {
                  setState(() {
                    inferenceOn = WhereInference.device;
                  });
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
  }
}
