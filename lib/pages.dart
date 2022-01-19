import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/utils/cache_folder_info.dart';
import 'package:flutter_app/utils/prediction_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';
import 'mrcnn/configs.dart';

class MrcnnPage extends StatelessWidget {
  final PredictionResult? predictionResult;
  final SharedPreferences prefs;
  const MrcnnPage(this.predictionResult, this.prefs, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (predictionResult != null &&
        File(predictionResult!.image.path!).existsSync()) {
      var path = predictionResult!.image.path!;
      var classIds = predictionResult!.classIds;
      var boxes = predictionResult!.boxes;
      var scores = predictionResult!.scores;

      return Container(
        child: ListView.builder(
          itemCount: boxes.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Stack(
                  alignment: AlignmentDirectional.bottomCenter,
                  children: [
                    GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) {
                            return MrcnnImage(path);
                          }));
                        },
                        child: Hero(
                            tag: 'ImageHero', child: Image.file(File(path)))),
                    Padding(
                      padding: EdgeInsets.all(15),
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    )
                  ]);
            } else {
              var classNames;
              var modelType = prefs.getString('modelType') ?? 'parts';
              if (modelType == 'parts') {
                classNames = CarPartsConfig.CLASS_NAMES;
              } else if (modelType == 'damage') {
                classNames = CarDamageConfig.CLASS_NAMES;
              }
              var className = classNames[classIds[index - 1]];
              className = className[0].toUpperCase() + className.substring(1);

              var score = (scores[index - 1] * 100).round();
              return ListTile(
                title: Text("$className"),
                subtitle: Text(
                  "(${boxes[index - 1][1]}, ${boxes[index - 1][0]}); (${boxes[index - 1][3]}, ${boxes[index - 1][2]})",
                ),
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

class MrcnnImage extends StatelessWidget {
  final String path;

  const MrcnnImage(this.path, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: PhotoView(
        imageProvider: FileImage(File(path)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        heroAttributes: const PhotoViewHeroAttributes(tag: 'ImageHero'),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final SharedPreferences prefs;

  const SettingsPage(this.prefs, {Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool saveImagesToDownloadDir =
      widget.prefs.getBool('saveToDownloadDir') ?? false;
  late bool testPicture = widget.prefs.getBool('testPicture') ?? false;
  late String modelType = widget.prefs.getString('modelType') ?? 'parts';
  late String selectedTestImage =
      widget.prefs.getString('selectedTestImage') ?? 'car_800_552.jpg';

  String cacheDirInfo = "Calculating...";

  @override
  void initState() {
    // _initImages();
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
                  borderRadius: BorderRadius.all(Radius.circular(0))),
            ),
            SwitchListTile(
              title: Text('Show test picture instead of camera'),
              value: testPicture,
              onChanged: (bool value) {
                widget.prefs.setBool('testPicture', value);
                setState(() {
                  testPicture = value;
                });
              },
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(0))),
            ),
            ListTile(
              title: Text("Model type"),
              trailing: DropdownButton(
                value: modelType,
                items: [
                  DropdownMenuItem(
                    child: Text('parts'),
                    value: 'parts',
                  ),
                  DropdownMenuItem(
                    child: Text('damage'),
                    value: 'damage',
                  )
                ],
                onChanged: (String? value) {
                  widget.prefs.setString('modelType', value!);
                  setState(() {
                    modelType = value;
                  });
                },
              ),
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(0))),
            ),
            FutureBuilder(
              future: cacheDirImagesSize(),
              builder: (context, snapshot) {
                cacheDirInfo =
                    widget.prefs.getString('cacheDirInfo') ?? 'Calculating...';
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.data.toString() == "0 items") {
                    deleteEnabled = false;
                  } else {
                    deleteEnabled = true;
                  }
                  cacheDirInfo = snapshot.data.toString();
                  widget.prefs
                      .setString('cacheDirInfo', snapshot.data.toString());
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
                      barrierDismissible: false,
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
                    );
                  },
                  tileColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(0))),
                );
              },
            ),
          ],
        ).toList(),
      ),
    );
  }
}
