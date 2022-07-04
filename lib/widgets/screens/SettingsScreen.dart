import 'package:flutter/material.dart';
import 'package:enum_to_string/enum_to_string.dart';

import '../../controllers/DetectionController.dart';
import '../../controllers/TensorflowController.dart';
import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final serverIPController = TextEditingController();

  late ModelType modelType;
  late bool isDemo;
  late InferenceType inferenceType;

  @override
  void initState() {
    getOptions();

    serverIPController.text = prefs.getString("serverIP") ?? "";
    serverIPController.addListener(() {
      print("text ${serverIPController.text}");
      prefs.setString('serverIP', serverIPController.text);
    });
    super.initState();
  }

  @override
  void dispose() {
    serverIPController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color _tileColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: Container(
        alignment: Alignment.center,
        child: ListView(
          children: ListTile.divideTiles(context: context, tiles: [
            ListTile(
              title: const Text("Model"),
              trailing: Text(
                  EnumToString.convertToString(modelType, camelCase: true)),
              onTap: () {
                setState(() {
                  if (modelType == ModelType.classifier)
                    modelType = ModelType.detection;
                  else
                    modelType = ModelType.classifier;
                });
                prefs.setString(
                    'modelType', EnumToString.convertToString(modelType));
              },
              tileColor: _tileColor,
            ),
            CheckboxListTile(
              title: const Text('Demo'),
              value: isDemo,
              onChanged: (bool? value) {
                setState(() {
                  isDemo = !isDemo;
                });
                prefs.setBool("isDemo", isDemo);
              },
              tileColor: _tileColor,
            ),
            ListTile(
              title: const Text("Inference"),
              trailing: Text(
                  EnumToString.convertToString(inferenceType, camelCase: true)),
              enabled: modelType == ModelType.detection,
              onTap: () {
                setState(() {
                  if (inferenceType == InferenceType.server)
                    inferenceType = InferenceType.device;
                  else
                    inferenceType = InferenceType.server;
                });
                prefs.setString('inferenceType',
                    EnumToString.convertToString(inferenceType));
              },
              tileColor: _tileColor,
            ),
            ListTile(
              title: Text("Server IP"),
              enabled: modelType == ModelType.detection,
              trailing: Container(
                width: 150,
                child: TextField(
                  enabled: modelType == ModelType.detection,
                  textAlign: TextAlign.end,
                  controller: serverIPController,
                  style: TextStyle(
                      color: modelType == ModelType.detection
                          ? null
                          : Colors.grey),
                  decoration: InputDecoration.collapsed(
                    hintText: "Enter here",
                    enabled: modelType == ModelType.detection,
                  ),
                ),
              ),
              tileColor: _tileColor,
            ),
          ]).toList(),
        ),
      ),
    );
  }

  getOptions() {
    isDemo = prefs.getBool("isDemo") ?? false;
    inferenceType = EnumToString.fromString(
            InferenceType.values, prefs.getString("inferenceType") ?? "") ??
        InferenceType.server;
    modelType = EnumToString.fromString(
            ModelType.values, prefs.getString("modelType") ?? "") ??
        ModelType.classifier;
  }
}
