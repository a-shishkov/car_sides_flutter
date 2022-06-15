import 'package:flutter/material.dart';

import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final serverIPController = TextEditingController();

  @override
  void initState() {
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
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: Container(
        alignment: Alignment.center,
        child: ListView(
          children: ListTile.divideTiles(context: context, tiles: [
            ListTile(
              title: Text("Server IP"),
              trailing: Container(
                width: 150,
                child: TextField(
                  textAlign: TextAlign.end,
                  controller: serverIPController,
                  decoration: InputDecoration.collapsed(hintText: "Enter here"),
                ),
              ),
              tileColor: Theme.of(context).colorScheme.surface,
            ),
          ]).toList(),
        ),
      ),
    );
  }
}
