import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/DetectionController.dart';

import 'widgets/screens/CameraScreen.dart';
import 'widgets/screens/DemoScreen.dart';
import 'widgets/screens/SettingsScreen.dart';

List<CameraDescription> cameras = <CameraDescription>[];
late SharedPreferences prefs;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      navigatorKey: navigatorKey,
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
  late bool isDemo;
  late InferenceType inferenceType;

  @override
  void initState() {
    getOptions();
    super.initState();
  }

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
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Colors.white,
            ),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()));
              setState(getOptions);
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

  getOptions() {
    isDemo = prefs.getBool("isDemo") ?? false;
    inferenceType = EnumToString.fromString(
            InferenceType.values, prefs.getString("inferenceType") ?? "") ??
        InferenceType.server;
  }
}
