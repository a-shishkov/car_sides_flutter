import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'package:flutter_app/utils/prediction_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';
import '../mrcnn/configs.dart';

class MrcnnPage extends StatelessWidget {
  final ImageExtender? image;
  // final PredictionResult? predictionResult;
  // final ModelType model;
  const MrcnnPage(this.image, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (image != null && image!.prediction != null) {
      var path = image!.prediction!.image.path!;
      var isAsset = image!.isAsset;
      var model = image!.prediction!.model;
      var classIds = image!.prediction!.classIds;
      var boxes = image!.prediction!.boxes;
      var scores = image!.prediction!.scores;

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
                            return MrcnnImage(path, isAsset);
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
              var className = CLASS_NAMES[model]![classIds[index - 1]];
              className = className[0].toUpperCase() + className.substring(1);

              var score = (scores[index - 1] * 100).round();
              return ListTile(
                title: Text('$className'),
                subtitle: Text(
                  '(${boxes[index - 1][1]}, ${boxes[index - 1][0]}); (${boxes[index - 1][3]}, ${boxes[index - 1][2]})',
                ),
                trailing: Text('$score%'),
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
              'Take image first',
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
  final bool isAsset;

  const MrcnnImage(this.path, this.isAsset, {Key? key}) : super(key: key);

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
