import 'package:enum_to_string/enum_to_string.dart';

import '../main.dart';
import 'ClassificationController.dart';
import 'DetectionController.dart';
import 'package:image/image.dart' as image_package;

// classifier - car sides_classifier
// detection - COCO ssd_mobilenet
enum ModelType { classifier, detection }

Future inferenceWrapper(image_package.Image image, String imagePath,
    {bool isAsset = false}) async {
  ModelType modelType = EnumToString.fromString(
          ModelType.values, prefs.getString("modelType") ?? "") ??
      ModelType.classifier;

  // Run inference depending on the model type
  if (modelType == ModelType.classifier)
    // Class sides classification
    ClassifierController.predict(image, imagePath, isAsset: isAsset);
  else
    DetectionController.detect(image, imagePath, isAsset: isAsset);
}
