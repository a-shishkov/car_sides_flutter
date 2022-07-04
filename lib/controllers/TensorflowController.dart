import 'package:enum_to_string/enum_to_string.dart';

import '../main.dart';
import 'ClassifierController.dart';
import 'DetectionController.dart';
import 'package:image/image.dart' as image_package;

// classifier - car sides_classifier
// detection - COCO ssd_mobilenet
enum ModelType { classifier, detection }

class TensorflowController {
  static Future inference(image_package.Image image, String imagePath,
      {bool isAsset = false}) async {
    ModelType modelType = EnumToString.fromString(
            ModelType.values, prefs.getString("modelType") ?? "") ??
        ModelType.classifier;

    if (modelType == ModelType.classifier)
      ClassifierController.predict(image, imagePath, isAsset: isAsset);
    else
      DetectionController.detect(image, imagePath, isAsset: isAsset);
  }
}
