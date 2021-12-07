import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter_app/utils/image_extender.dart';
import 'package:flutter_app/utils/isolate_utils.dart';
import 'package:image/image.dart' as ImagePackage;
import 'package:camera/camera.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

List<CameraDescription> cameras = [];
late tfl.Interpreter interpreter;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
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
  String? filename;
  bool getImageRunning = false;

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




  Future getImage() async {
    if (!controller.value.isInitialized || getImageRunning) {
      return;
    }
    getImageRunning = true;
    XFile file = await controller.takePicture();
    ImagePackage.Image image =
    ImagePackage.decodeImage(File(file.path).readAsBytesSync())!;

    // ImageExtender img = ImageExtender.decodeImage(File(file.path).readAsBytesSync());
    image = ImagePackage.copyRotate(image, 90);
    context.loaderOverlay.show();

    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(predictIsolate, receivePort.sendPort);

    SendPort sendPort = await receivePort.first;
    var img = await sendReceive(sendPort, IsolateMsg(image, interpreter.address));

    Directory appCacheDirectory = await getTemporaryDirectory();
    String appCachesPath = appCacheDirectory.path;
    var now = DateTime.now();
    var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
    String currentTimeStamp = formatter.format(now);
    filename = '$appCachesPath/$currentTimeStamp.png';
    await File(filename!).writeAsBytes(ImagePackage.encodePng(img));


    context.loaderOverlay.hide();
    if (filename != null)
      setState(() {
        _onItemTapped(1);
      });
    else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No instances found'),
      ));
    }
    getImageRunning = false;
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
        items: buildBottomNavBarItems(),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _buttonFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  bool onWillPop() {
    if (pageController.page!.round() == pageController.initialPage)
      return true;
    else {
      pageController.previousPage(
        duration: Duration(milliseconds: 200),
        curve: Curves.linear,
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

  List<BottomNavigationBarItem> buildBottomNavBarItems() {
    return [
      BottomNavigationBarItem(
        icon: Icon(Icons.camera),
        label: 'Camera',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.image),
        label: 'Image',
      ),
    ];
  }

  _buttonFAB() {
    if (_selectedIndex == 0)
      return FloatingActionButton(
          onPressed: getImage,
          tooltip: 'Pick Image',
          child: Icon(Icons.add_a_photo));
    else
      return null;
  }

  Widget buildPageView() {
    return PageView(
      controller: pageController,
      physics: NeverScrollableScrollPhysics(),
      onPageChanged: _pageChanged,
      children: <Widget>[cameraPage(), mrcnnPage()],
    );
  }

  Widget mrcnnPage() {
    return Container(
        child: (filename == null
            ? Icon(
          Icons.image_not_supported,
          size: 100,
        )
            : Image.file(File(filename!))));
  }

  Widget cameraPage() {
    return Container(
        color: Colors.black,
        child: controller.value.isInitialized
            ? CameraPreview(controller)
            : Container());
  }
}
