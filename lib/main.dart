import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter_app/pages.dart';
import 'package:flutter_app/utils/cache_folder_info.dart';
import 'package:flutter_app/utils/image_extender.dart';
import 'package:flutter_app/utils/isolate_utils.dart';
import 'package:camera/camera.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = [];
late tfl.Interpreter interpreter;
late SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  prefs = await SharedPreferences.getInstance();
  interpreter = await tfl.Interpreter.fromAsset('car_parts.tflite');

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
  String cacheDirInfo = "Calculating...";

  bool getImageRunning = false;
  bool saveImagesToDownloadDir = false;

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

  _savePref(String name, bool value) async {
    await prefs.setBool(name, value);
  }

  @override
  void initState() {
    super.initState();
    bool? boolValue = prefs.getBool('saveToDownloadDir');
    print("boolValue $boolValue");
    if (boolValue != null) {
      saveImagesToDownloadDir = boolValue;
    } else {
      print("save boolValue");
      _savePref('saveToDownloadDir', true);
    }

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

  Future getImage() async {
    if (!controller.value.isInitialized || getImageRunning) {
      return;
    }
    getImageRunning = true;

    XFile file = await controller.takePicture();

    ImageExtender originalIE = ImageExtender.decodeImageFromPath(file.path);

    setState(() {
      originalImagePath = originalIE.path!;
    });

    context.loaderOverlay.show();

    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(predictIsolate, receivePort.sendPort);

    SendPort sendPort = await receivePort.first;
    var result = await sendReceive(sendPort,
        IsolateMsg(originalIE, interpreterAddress: interpreter.address));

    if (result.foundInstances > 0) {
      var path =
          DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) + '.png';
      newImagePath = await result.image.saveToTempDir(path);
      if (saveImagesToDownloadDir) {
        var imagePath = await result.image.saveToDownloadDir(path);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Image saved to $imagePath"),
        ));
      }
      setState(() {
        _onItemTapped(1);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No instances found'),
      ));
    }
    setState(() {
      getImageRunning = false;
      context.loaderOverlay.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WillPopScope(
          onWillPop: () => Future.sync(onWillPop), child: buildPageView()),
      bottomNavigationBar: BottomNavigationBar(
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: getImage,
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
        cameraPage(getImageRunning, controller, originalImagePath),
        mrcnnPage(newImagePath),
        settingsPage()
      ],
    );
  }

  Widget settingsPage() {
    bool deleteEnabled = true;
    return Container(
      alignment: Alignment.center,
      child: ListView(
        physics: NeverScrollableScrollPhysics(),
        children: ListTile.divideTiles(
          context: context,
          tiles: [
            SwitchListTile(
              title: Text('Save photos to download dir'),
              value: saveImagesToDownloadDir,
              onChanged: (bool value) {
                _savePref('saveToDownloadDir', value);
                setState(() {
                  saveImagesToDownloadDir = value;
                });
              },
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
            FutureBuilder(
              future: cacheDirImagesSize(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.data.toString() == "0 items") {
                    deleteEnabled = false;
                  } else {
                    deleteEnabled = true;
                  }
                  cacheDirInfo = snapshot.data.toString();
                }
                return ListTile(
                  enabled: deleteEnabled,
                  trailing: Icon(
                    Icons.delete,
                    color: deleteEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text('Delete all photos'),
                  subtitle: Text(cacheDirInfo),
                  onTap: () {
                    showDialog<String>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Delete files?'),
                        content:
                            const Text('Delete all files in cache folder?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'No'),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context, 'Yes');
                              await deleteAllImages();
                              setState(() {
                                newImagePath = null;
                              });
                            },
                            child: const Text('Yes'),
                            style: ButtonStyle(
                                foregroundColor:
                                    MaterialStateProperty.all<Color>(
                                        Colors.red)),
                          ),
                        ],
                      ),
                      barrierDismissible: false,
                    );
                  },
                  tileColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                );
              },
            ),
          ],
        ).toList(),
      ),
    );
  }
}
