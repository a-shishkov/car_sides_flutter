import 'image_extender.dart';

class PredictionResult
{
  ImageExtender image;
  List boxes;
  List masks;
  List classIds;
  List scores;

  PredictionResult(this.image, this.boxes, this.masks, this.classIds, this.scores);
}