import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/ClassificationModel.dart';

class ClassifierScreen extends StatelessWidget {
  const ClassifierScreen({required this.prediction, Key? key})
      : super(key: key);

  final ClassifierModel prediction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        // extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("Prediction"),
        ),
        body: Container(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: image),
                Text(
                  prediction.toString(),
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ));
  }

  Image get image {
    if (prediction.isAsset)
      return Image.asset(prediction.imagePath);
    else
      return Image.file(File(prediction.imagePath));
  }
}
