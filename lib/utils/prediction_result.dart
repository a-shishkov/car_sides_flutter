import 'package:flutter_app/main.dart';
import 'dart:ui' as ui;

class PredictionResult {
  List boxes;
  List<ui.Image> masks;
  List classIDs;
  List scores;
  ModelType model;

  PredictionResult(
      {required this.boxes,
      required this.masks,
      required this.classIDs,
      required this.scores,
      required this.model});

  PredictionResult.fromResult(Map result, this.model)
      : this.boxes = result['boxes'],
        this.classIDs = result['class_ids'],
        this.scores = result['scores'],
        this.masks = result['masks'];
}
