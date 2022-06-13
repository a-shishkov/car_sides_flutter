import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'models/PredictionModel.dart';
import 'screens/CameraScreen.dart';
import 'screens/DemoScreen.dart';
import 'screens/PredictionScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = <CameraDescription>[];
late SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  prefs = await SharedPreferences.getInstance();

  await initImages();

  runApp(MyApp());
}

Future initImages() async {
  final manifestContent = await rootBundle.loadString('AssetManifest.json');

  final Map<String, dynamic> manifestMap = json.decode(manifestContent);

  var imagePathes =
      manifestMap.keys.where((String key) => key.contains('images/')).toList();

  imagePathes = List.generate(
      imagePathes.length, (index) => imagePathes[index].split('/').last);

  await prefs.setStringList('testImagesList', imagePathes);
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
  late PredictionModel prediction;
  bool doShowPrediction = false;

  var isDemo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Result Car Damage"),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                  value: 0, checked: isDemo, child: Text('Demo'))
            ],
            onSelected: (value) {
              if (value == 0) {
                setState(() {
                  isDemo = !isDemo;
                });
              }
            },
          )
        ],
      ),
      body: Center(
        child: isDemo ? DemoScreen() : CameraScreen(),
      ),
    );
  }
}
