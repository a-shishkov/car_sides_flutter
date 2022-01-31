import 'ImageExtender.dart';

class PredictionResult {
  ImageExtender image;
  List boxes;
  List? masks;
  List classIds;
  List scores;

  PredictionResult(this.image, this.boxes, this.masks, this.classIds,
      this.scores);

  PredictionResult.fromResult(this.image, result)
      : this.boxes = result['rois'],
        this.masks = result['masks'],
        this.classIds = result['class_ids'],
        this.scores = result['scores'];

  PredictionResult.noMask(this.image, result)
      : this.boxes = result['rois'],
        this.classIds = result['class_ids'],
        this.scores = result['scores'];
}
