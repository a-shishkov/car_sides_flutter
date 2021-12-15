import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/utils/cache_folder_info.dart';
import 'package:flutter_app/utils/prediction_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mrcnn/config.dart';

Widget cameraPage(
    predictProgress, getImageRunning, controller, originalImagePath) {
  var progressMsg = {
    0.0: "Nothing",
    0.1: "Taking picture",
    0.3: "Start prediction",
    0.5: "Running model",
    0.4: "Waiting for result",
    0.6: "Visualizing result",
    0.7: "Saving picture",
    0.9: "Done"
  };

  return Container(
      color: Colors.black,
      child: !getImageRunning && controller.value.isInitialized
          ? CameraPreview(controller)
          : !getImageRunning
              ? Center(
                  child: CircularProgressIndicator(),
                )
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

class MrcnnPage extends StatelessWidget {
  final PredictionResult? predictionResult;

  const MrcnnPage(this.predictionResult, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (predictionResult != null &&
        File(predictionResult!.image.path!).existsSync()) {
      var path = predictionResult!.image.path;
      var classIds = predictionResult!.classIds;
      var boxes = predictionResult!.boxes;
      var scores = predictionResult!.scores;

      return Container(
        child: ListView.builder(
          itemCount: boxes.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Image.file(File(path!));
            } else {
              var className = CarPartsConfig.CLASS_NAMES[classIds[index - 1]];
              className = className[0].toUpperCase() + className.substring(1);

              var score = (scores[index - 1] * 100).round();
              return ListTile(
                title: Text("$className"),
                subtitle: Text(
                    "(${boxes[index - 1][1]}, ${boxes[index - 1][0]}); (${boxes[index - 1][3]}, ${boxes[index - 1][2]})",
                    style: TextStyle(color: Colors.black)),
                trailing: Text("$score%"),
              );
            }
          },
        ),
      );
    } else {
      return Container(
        child: Column(
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
        ),
      );
    }
  }
}

Widget mrcnnPage(newImagePath) {
  return Container(
      child: (newImagePath != null && File(newImagePath).existsSync()
          ? ListView(children: [
              Image.file(File(newImagePath!)),
              Container(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Some info",
                        style: TextStyle(color: Colors.white),
                      ),
                      Text(
                        "Some info",
                        style: TextStyle(color: Colors.white),
                      ),
                      Text(
                        "Some info",
                        style: TextStyle(color: Colors.white),
                      ),
                      Text(
                        "Some info",
                        style: TextStyle(color: Colors.white),
                      )
                    ],
                  ),
                ),
              )
            ])
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
