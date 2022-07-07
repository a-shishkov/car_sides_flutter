import 'dart:math';

import 'package:flutter/material.dart';

class ClassifierModel {
  static List<String> class_names = [
    "Diagonal",
    "Back",
    "Front",
    "Left",
    "Right"
  ];

  final List<double> predictions;
  final String imagePath;
  final bool isAsset;

  ClassifierModel(this.predictions, this.imagePath, this.isAsset);

  String get predictionLabel {
    return class_names[maxIndex];
  }

  int get maxIndex {
    var maxConfidence = predictions.reduce(max);
    return predictions.indexOf(maxConfidence);
  }

  List<Widget> get textWidgets => List.generate(
      5,
      (index) => Text(
            "${class_names[index]}: ${predictions[index].toStringAsFixed(2)}",
            style: TextStyle(color: Colors.white),
          ));

  // @override
  // String toString() {
  //   return "$predictionLabel ${predictions[maxIndex].toStringAsFixed(2)}";
  // }
  @override
  String toString() {
    return predictions.toString();
  }
}
