import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? newImagePath;
  String? originalImagePath;

  bool predictionRunning = false;
  bool connected = false;

  PredictionResult? predictResult;
  double predictProgress = 0.0;

  WhereInference? inferenceOn = WhereInference.device;
  String serverIP = '193.2.231.155';
  int serverPort = 65432;
  Socket? socket;

  var textControllerIP = TextEditingController();
  var textControllerPort = TextEditingController();

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

    textControllerIP.text = serverIP;
    textControllerPort.text = serverPort.toString();

    initializeCameraController();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    controller.dispose();
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

  Future<String> saveData(data, filename, {tempDir = true}) async {
    if (tempDir) {
      Directory appCacheDirectory = await getTemporaryDirectory();
      String appCachesPath = appCacheDirectory.path;

      filename = '$appCachesPath/$filename';
      await File(filename).writeAsBytes(data);
      return filename;
    }
    return "";
  }

  Future predictionDevice() async {
    if (!controller.value.isInitialized || predictionRunning) {
      return;
    }

    setState(() {
      predictProgress = 0.1;
      predictionRunning = true;
    });

    XFile file = await controller.takePicture();

    ImageExtender originalIE = ImageExtender.decodeImageFromPath(file.path);

    setState(() {
      predictProgress = 0.3;
      originalImagePath = originalIE.path!;
    });

    bool spawnIsolate = true;
    if (spawnIsolate) {
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
    }

    setState(() {
      predictProgress = 0.7;
    });
    if (predictResult != null) {
      var path =
          DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) + '.png';
      newImagePath = await predictResult!.image.saveToTempDir(path);

      bool? saveExternal = prefs.getBool('saveToDownloadDir');
      if (saveExternal != null && saveExternal) {
        var imagePath = await predictResult!.image.saveToDownloadDir(path);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Image saved to $imagePath"),
        ));
      }
      setState(() {
        predictProgress = 0.9;
        _onItemTapped(1);
      });
    } else {
      predictProgress = 1.0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No instances found'),
      ));
    }
    setState(() {
      predictProgress = 1.0;
      predictionRunning = false;
    });
  }

  predictionServer() async {
    if (!controller.value.isInitialized || predictionRunning) {
      return;
    }
    if (socket != null) {
      predictionRunning = true;

      XFile file = await controller.takePicture();

      ImageExtender originalIE = ImageExtender.decodeImageFromPath(file.path);

      setState(() {
        predictProgress = 0.3;
        originalImagePath = originalIE.path!;
      });

      // socket = await Socket.connect(serverIP, serverPort);
      print(
          'Connected to: ${socket!.remoteAddress.address}:${socket!.remotePort}');

      String fullData = '';

      socket!.listen(
        (Uint8List data) async {
          final serverResponse = String.fromCharCodes(data);

          if (serverResponse[0] == '{') {
            fullData = serverResponse;
          } else {
            fullData += serverResponse;
          }

          if (fullData[fullData.length - 1] == '}') {
            var response = jsonDecode(fullData);
            print("Server: ${response['response']}");
            ImageExtender? image;
            if (response['response'] == 'Results') {
              image = displayInstances(
                  originalIE,
                  response['rois'],
                  response['masks'],
                  response['class_ids'],
                  CarPartsConfig.CLASS_NAMES,
                  scores: response['scores']);
              var path =
                  DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) +
                      '_server.png';
              await image.saveToTempDir(path);

              predictResult = PredictionResult(image, response['rois'],
                  response['masks'], response['class_ids'], response['scores']);

              setState(() {
                predictProgress = 0.9;
                _onItemTapped(1);
              });
            }
          }
        },

        // handle errors
        onError: (error) {
          print(error);
          socket!.destroy();

          setState(() {
            predictProgress = 1.0;
            predictionRunning = false;
          });
        },

        // handle server ending connection
        onDone: () {
          print('Server left.');
          socket!.destroy();

          setState(() {
            predictProgress = 1.0;
            predictionRunning = false;
          });
        },
      );

      var imageFile = File(originalIE.path!);
      var fileBytes = imageFile.readAsBytesSync();

      sendMessage(socket, fileBytes);
    }
  }

  void sendMessage(socket, Uint8List message) {
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
              : Theme.of(context).colorScheme.primary,
          unselectedItemColor: predictionRunning
              ? Colors.grey[400]
              : Theme.of(context).colorScheme.background,
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
    setState(() {
      _selectedIndex = index;
      pageController.animateToPage(index,
          duration: Duration(milliseconds: 500), curve: Curves.ease);
    });
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
      0.3: "Start prediction",
      0.5: "Running model",
      0.4: "Waiting for result",
      0.6: "Visualizing result",
      0.7: "Saving picture",
      0.9: "Done"
    };

    if (!predictionRunning) {
      if (controller.value.isInitialized) {
        return Container(
          color: Colors.black,
          child: Stack(
            alignment: AlignmentDirectional.topCenter,
            children: [
              CameraPreview(controller),
              Container(
                width: double.infinity,
                // height: double.infinity,
                color: Colors.white,
                child: Row(
                  children: [
                    Flexible(
                        child: RadioListTile(
                            title: Text("Device"),
                            value: WhereInference.device,
                            groupValue: inferenceOn,
                            onChanged: (WhereInference? value) {
                              if (connected) {
                                showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                          title:
                                              Text("Disconnect from server?"),
                                          actions: [
                                            TextButton(
                                                onPressed: () {
                                                  inferenceOn =
                                                      WhereInference.server;
                                                  Navigator.pop(context);
                                                },
                                                child: Text("No")),
                                            TextButton(
                                                onPressed: () {
                                                  socket!.destroy();
                                                  setState(() {
                                                    connected = false;
                                                    inferenceOn =
                                                        WhereInference.device;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: Text("Yes"))
                                          ],
                                        ));
                              } else {
                                setState(() {
                                  inferenceOn = value;
                                });
                              }
                            })),
                    Flexible(
                      child: RadioListTile(
                          title: Text("Server"),
                          subtitle: connected
                              ? Text("Connected")
                              : Text("Disconnected"),
                          value: WhereInference.server,
                          groupValue: inferenceOn,
                          onChanged: (WhereInference? value) {
                            setState(() {
                              inferenceOn = value;
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return connectAlertDialog();
                                  });
                            });
                          }),
                    ),
                  ],
                ),
              )
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

  AlertDialog connectAlertDialog() {
    return AlertDialog(
      title: Text("Connect to server"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: textControllerIP,
            decoration: InputDecoration(hintText: "Server IP"),
            onChanged: (String value) {
              serverIP = value;
            },
          ),
          TextField(
            controller: textControllerPort,
            decoration: InputDecoration(hintText: "Server port"),
            onChanged: (String value) {
              serverPort = int.parse(value);
            },
          ),
        ],
      ),
      actions: [
        ElevatedButton(
            onPressed: () {
              setState(() {
                inferenceOn = WhereInference.device;
              });
              Navigator.pop(context);
            },
            child: Text("Cancel")),
        ElevatedButton(
            onPressed: () async {
              try {
                socket = await Socket.connect(serverIP, serverPort,
                    timeout: Duration(seconds: 5));
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
            },
            child: Text("OK"))
      ],
    );
  }
}
