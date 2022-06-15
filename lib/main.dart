import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'models/PredictionModel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/screens/CameraScreen.dart';
import 'widgets/screens/DemoScreen.dart';
import 'widgets/screens/SettingsScreen.dart';

List<CameraDescription> cameras = <CameraDescription>[];
late SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  prefs = await SharedPreferences.getInstance();

  await initImages();

  runApp(MyApp());
}

// Get list of all asset image paths
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

  var isDemo = prefs.getBool("isDemo") ?? false;

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
                  value: 0, checked: isDemo, child: Text('Demo')),
              PopupMenuItem(value: 1, child: Text('Settings')),
            ],
            onSelected: (value) {
              switch (value) {
                case 0:
                  setState(() {
                    isDemo = !isDemo;
                  });
                  prefs.setBool("isDemo", isDemo);
                  break;
                case 1:
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SettingsScreen()));
                  break;
              }
            },
          )
        ],
      ),
      body: Container(
        child: Center(
          child: isDemo ? DemoScreen() : CameraScreen(),
        ),
      ),
    );
  }
}
