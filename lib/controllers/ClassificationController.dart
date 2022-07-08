import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_package;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'dart:math';

import '../main.dart';
import '../models/ClassificationModel.dart';
import '../widgets/screens/ClassificationScreen.dart';

class ClassifierController {
  static Future predict(image_package.Image image, String imagePath,
      {bool isAsset = false}) async {
    int modelWidth = 180;
    int modelHeight = 180;

    // Load interpreter
    final interpreter =
        await tfl.Interpreter.fromAsset('sides_classifier.tflite');

    // Crop image to 180x180 needed for model
    var croppedImage =
        image_package.copyResize(image, width: modelWidth, height: modelHeight);

    // Get list of pixels in RGB format
    var bytesImage = croppedImage.getBytes(format: image_package.Format.rgb);

    // Image will be normalized during the prediction
    // But model requires float values
    List<double> normImage = bytesImage.map((byte) => byte.toDouble()).toList();
    // Reshape image to shape [1, 180, 180, 3]
    var reshapedImage = normImage.reshape([1, modelHeight, modelWidth, 3]);

    // Allocate output tensor for 4 classes
    TensorBuffer probabilityBuffer =
        TensorBuffer.createFixedSize(<int>[1, 4], TfLiteType.float32);

    // Prediction
    interpreter.run(reshapedImage, probabilityBuffer.buffer);

    var probability = probabilityBuffer.getDoubleList();

    interpreter.close();

    // Softmax the output for percent probability
    var softmaxOut = softmax(probability);

    var output = ClassificationModel(softmaxOut, imagePath, isAsset);

    // Show result in ClassificationScreen
    navigatorKey.currentState!.push(MaterialPageRoute(
        builder: (context) => ClassificationScreen(prediction: output)));
  }

  // Softmax function
  static softmax(List<double> values) {
    double sum = 0;
    // Calculate sum of e^value
    for (var value in values) {
      sum += pow(e, value);
    }

    List<double> output = [];
    for (var value in values) {
      output.add(pow(e, value) / sum);
    }

    return output;
  }
}
