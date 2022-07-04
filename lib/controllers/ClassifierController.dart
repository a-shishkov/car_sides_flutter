import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_package;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

import '../main.dart';
import '../models/ClassifierModel.dart';
import '../widgets/screens/ClassifierScreen.dart';

class ClassifierController {
  static Future predict(image_package.Image image, String imagePath,
      {bool isAsset = false}) async {
    int modelWidth = 256;
    int modelHeight = 256;
    final interpreter =
        await tfl.Interpreter.fromAsset('sides_classifier.tflite');

    // Crop image to 640x640 needed for model
    var croppedImage =
        image_package.copyResize(image, width: modelWidth, height: modelHeight);

    var bytesImage = croppedImage.getBytes(format: image_package.Format.rgb);

    List<double> normImage =
        bytesImage.map((byte) => (byte - 117) / 1).toList();
    var reshapedImage = normImage.reshape([1, modelHeight, modelWidth, 3]);

    TensorBuffer probabilityBuffer =
        TensorBuffer.createFixedSize(<int>[5], TfLiteType.float32);
    interpreter.run(reshapedImage, probabilityBuffer.buffer);

    var probability = probabilityBuffer.getDoubleList();

    interpreter.close();

    var output = ClassifierModel(
        probability, image.width, image.height, imagePath, isAsset);

    navigatorKey.currentState!.push(MaterialPageRoute(
        builder: (context) => ClassifierScreen(prediction: output)));
  }
}
