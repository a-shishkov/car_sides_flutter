import 'dart:convert';
import 'package:image/image.dart' as image_package;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

import 'package:dio/dio.dart';

import '../main.dart';
import '../models/AnnotationModel.dart';
import '../models/PredictionModel.dart';

enum InferenceType { device, server }

class PredictionController {
  // Send base64 image to the server
  // Get detection of type:
  // {'width': int, 'height': int,
  // 'boxes': [instances * [left, top, right, bottom]],
  // 'masks': [instances * [bool mask of size (h,w)]
  // 'scores': [instances of double],
  // 'classes': [instances of int]}
  static Future _serverPrediction(image_package.Image image, String imagePath,
      {List<Annotation>? annotations, bool isAsset = false}) async {
    Map<String, dynamic> data = {
      'image': base64.encode(image.getBytes(format: image_package.Format.rgb)),
      'width': image.width,
      'height': image.height
    };
    if (annotations != null)
      data['annotations'] = annotations.map((e) => e.toMap).toList();

    try {
      var serverIP = prefs.getString('serverIP');
      var response = await Dio().post(
        'http://$serverIP:5000/predict',
        data: data,
      );

      var predictionMap = json.decode(response.data);

      return PredictionModel.fromMap(predictionMap, imagePath, isAsset);
    } catch (e) {
      return Future.error(e);
    }
  }

  // Inference on device using converted to TFLite model from
  // https://github.com/tensorflow/models/tree/master/research/object_detection
  static Future _devicePrediction(image_package.Image image, String path,
      {List<Annotation>? annotations, bool isAsset = false}) async {
    int modelWidth = 640;
    int modelHeight = 640;
    final interpreter = await tfl.Interpreter.fromAsset('ssd_mobilenet.tflite');

    // Crop image to 640x640 needed for model
    var croppedImage =
        image_package.copyResize(image, width: modelWidth, height: modelHeight);

    // Norm image to range [0.,1.]
    var bytesImage = croppedImage.getBytes(format: image_package.Format.rgb);
    List<double> normImage = [];
    for (var byte in bytesImage) {
      normImage.add(byte / 255);
    }
    var reshapedImage = normImage.reshape([1, modelHeight, modelWidth, 3]);

    // Initialize and allocate output tensors for model
    var outputTensors = interpreter.getOutputTensors();
    List<TensorBuffer> bufferTensors = [];
    for (var tensor in outputTensors) {
      bufferTensors.add(
          TensorBuffer.createFixedSize(tensor.shape, tfl.TfLiteType.float32));
    }
    // Create Map<int, ByteBuffer> for inference
    var outputs = {
      for (int i = 0; i < bufferTensors.length; i++) i: bufferTensors[i].buffer
    };

    // Inference
    interpreter.runForMultipleInputs([reshapedImage], outputs);

    var scores = bufferTensors[0].getDoubleList();

    var boxes = bufferTensors[1].getDoubleList().reshape([10, 4]);
    // Re-normalize boxes for original image resolution
    var renormBoxes = boxes.map((box) {
      double ymin = box[0] * image.height;
      double xmin = box[1] * image.width;
      double ymax = box[2] * image.height;
      double xmax = box[3] * image.width;

      return [ymin, xmin, ymax, xmax];
    }).toList();

    var classes = bufferTensors[3].getDoubleList();
    // Output classes doesn't include __background__ class from COCO classes
    var offsetClasses = classes.map((_class) => _class.toInt() + 1).toList();

    interpreter.close();

    return PredictionModel(
      renormBoxes,
      offsetClasses,
      scores,
      image.width,
      image.height,
      path,
      isAsset,
    );
  }

  static Future predict(
    image_package.Image image,
    String imagePath, {
    List<Annotation>? annotations,
    bool isAsset = false,
    InferenceType type = InferenceType.server,
  }) async {
    if (type == InferenceType.server)
      return _serverPrediction(image, imagePath,
          annotations: annotations, isAsset: isAsset);
    if (type == InferenceType.device)
      return _devicePrediction(image, imagePath,
          annotations: annotations, isAsset: isAsset);
  }
}
