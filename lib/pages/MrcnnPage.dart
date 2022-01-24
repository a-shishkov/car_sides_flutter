import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_app/utils/prediction_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';
import '../mrcnn/configs.dart';

class MrcnnPage extends StatelessWidget {
  final PredictionResult? predictionResult;
  final SharedPreferences prefs;

  const MrcnnPage(this.predictionResult, this.prefs, {Key? key})
      : super(key: key);

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
