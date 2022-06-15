import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_package;

import '../../controllers/PredictionController.dart';
import '../../main.dart';
import '../CameraPlain.dart';
import 'AnnotationScreen.dart';
import 'PredictionScreen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;

  // Handle camera lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("didChangeAppLifecycleState overlay");
    // App state changed before we got the chance to initialize.
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        onNewCameraSelected(_controller!.description);
      }
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance!.addObserver(this);
    onNewCameraSelected(cameras[0]);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CameraPreview(_controller!),
        CameraPlain(onTakePicture: takePicture),
      ],
    );
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
        cameraDescription, ResolutionPreset.high,
        enableAudio: false);

    _controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (cameraController.value.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Camera error ${cameraController.value.errorDescription}')));
      }
    });

    try {
      await cameraController.initialize();
      // The exposure mode is currently not supported on the web.

    } on CameraException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.code}\n${e.description}')));
    }

    if (mounted) {
      setState(() {});
    }
  }

  // Send taken image to server and get prediction
  void takePicture() async {
    if (_controller!.value.isTakingPicture) {
      return;
    }

    XFile file = await _controller!.takePicture();
    var image_data = await file.readAsBytes();

    var image = image_package.decodeImage(image_data)!;

    var annotations = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AnnotationScreen(
                image: file,
                size: Size(image.width.toDouble(), image.height.toDouble()))));

    PredictionController.predict(image_data, annotations: annotations)
        .then((value) => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      PredictionScreen(image: file, prediction: value)),
            ))
        .onError((error, stackTrace) => print("Error: $error"));
  }
}
