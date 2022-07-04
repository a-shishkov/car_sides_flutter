import 'dart:math';

class ClassifierModel {
  static List<String> class_names = [
    "Diagonal",
    "Back",
    "Front",
    "Left",
    "Right"
  ];

  final List<double> predictions;
  final int width;
  final int height;
  final String imagePath;
  final bool isAsset;

  ClassifierModel(
      this.predictions, this.width, this.height, this.imagePath, this.isAsset);

  String get predictionLabel {
    return class_names[maxIndex];
  }

  int get maxIndex {
    var maxConfidence = predictions.reduce(max);
    return predictions.indexOf(maxConfidence);
  }

  @override
  String toString() {
    return "$predictionLabel ${predictions[maxIndex].toStringAsFixed(2)}";
  }
  // @override
  // String toString() {
  //   return predictions.toString();
  // }
}
