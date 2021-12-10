import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/utils/cache_folder_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget cameraPage(
    predictProgress, getImageRunning, controller, originalImagePath) {
  var progressMsg = {
    0.1: "Taking picture",
    0.3: "Start prediction",
    0.4: "Waiting for result",
    0.7: "Saving picture",
    0.9: "Done"
  };

  return Container(
      color: Colors.black,
      child: !getImageRunning && controller.value.isInitialized
          ? CameraPreview(controller)
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(
                value: predictProgress,
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                progressMsg[predictProgress]!,
                style: TextStyle(color: Colors.white),
              ),
            ]));
}

Widget mrcnnPage(newImagePath) {
  return Container(
      child: (newImagePath != null && File(newImagePath).existsSync()
          ? Image.file(File(newImagePath!))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 100,
                  color: Colors.grey,
                ),
                Text(
                  'Take a picture first',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            )));
}

class SettingsPage extends StatefulWidget {
  final SharedPreferences prefs;

  const SettingsPage(this.prefs, {Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool saveImagesToDownloadDir;
  String cacheDirInfo = "Calculating...";

  @override
  void initState() {
    bool? saveExternal = widget.prefs.getBool('saveToDownloadDir');
    if (saveExternal == null) {
      saveImagesToDownloadDir = false;
    } else {
      saveImagesToDownloadDir = saveExternal;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
                widget.prefs.setBool('saveToDownloadDir', value);
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
                              setState(() {});
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