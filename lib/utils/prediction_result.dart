import 'package:flutter_app/main.dart';

import 'ImageExtender.dart';

class PredictionResult {
  ImageExtender image;
  List boxes;
  List? masks;
  List classIds;
  List scores;
  ModelType model;

  PredictionResult(
      {required this.image,
      required this.boxes,
      this.masks,
      required this.classIds,
      required this.scores,
      required this.model});

  PredictionResult.fromResult(this.image, Map result, this.model)
      : this.boxes = result['rois'],
        this.classIds = result['class_ids'],
        this.scores = result['scores'],
        this.masks = result['masks'];
}
