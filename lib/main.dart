import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'screens/CameraScreen.dart';
import 'screens/ResultScreen.dart';

List<CameraDescription> cameras = <CameraDescription>[];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late XFile image;
  late Map result;
  bool showResult = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Result Car Damage"),
      ),
      body: Center(
        child: showResult
            ? ResultScreen(image: image, result: result)
            : CameraScreen(
                onShowPrediction: showPrediction,
              ),
      ),
    );
  }

  showPrediction(XFile image, Map prediction) {
    print(prediction['result'][0][0]);
    setState(() {
      image = image;
      result = prediction;
      showResult = true;
    });
  }
}
