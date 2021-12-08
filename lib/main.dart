import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter_app/mrcnn/utils.dart';
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
  Image? originalImage;
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

  rotate(List img, {angle = 90}) {
    assert(angle == 90 || angle == -90 || angle == 180);

    int newH, newW;
    if (angle == 180) {
      newH = img.shape[0];
      newW = img.shape[1];
    } else {
      newW = img.shape[0];
      newH = img.shape[1];
    }

    List output = List.generate(
        newH, (e) => List.generate(newW, (e) => List.filled(3, 0)));

    for (var i = 0; i < newH; i++) {
      for (var j = 0; j < newW; j++) {
        for (var k = 0; k < 3; k++) {
          switch (angle) {
            case -90:
              output[newW - 1 - j][i][k] = img[i][j][k];
              break;
            case 90:
              output[j][newH - 1 - i][k] = img[i][j][k];
              break;
            case 180:
              output[newH - 1 - i][newW - 1 - j][k] = img[i][j][k];
              break;
          }
        }
      }
    }

    return output;
  }

  Future getImage() async {
    if (!controller.value.isInitialized || getImageRunning) {
      return;
    }
    getImageRunning = true;

    XFile file = await controller.takePicture();

    ImageExtender originalIE = ImageExtender.decodeImageFromPath(file.path);

    // originalIE = ImageExtender.fromImage(ImagePackage.drawImage(
    //     ImagePackage.Image(newW, newH, channels: ImagePackage.Channels.rgb), originalIE.image,
    //     dstX: dstX, dstW: origSmallW));

    // image.image = ImagePackage.drawImage(image.image, image2.image);
    // image2.image;
    // await originalIE.save(file.path);
    // await image.rotate(180);

    setState(() {
      originalImage = Image.file(File(originalIE.path!));
    });

    context.loaderOverlay.show();

    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(predictIsolate, receivePort.sendPort);

    SendPort sendPort = await receivePort.first;
    var result = await sendReceive(sendPort,
        IsolateMsg(originalIE, interpreterAddress: interpreter.address));

    if (result.foundInstances > 0) {
      filename =
          DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now()) + '.png';
      filename = await result.image.saveToTempDir(filename!);

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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
      children: <Widget>[cameraPage(), mrcnnPage()],
    );
  }

  Widget cameraPage() {
    return Container(
        color: Colors.black,
        child: !getImageRunning && controller.value.isInitialized
            ? CameraPreview(controller)
            : originalImage == null
                ? Center(child: CircularProgressIndicator())
                : originalImage);
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
}
