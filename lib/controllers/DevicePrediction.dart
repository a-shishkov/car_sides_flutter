import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as image_package;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:path_provider/path_provider.dart';

import '../models/AnnotationModel.dart';
import '../models/PredictionModel.dart';

class DevicePrediction {
  // Send base64 image to the server
  // Get detection of type:
  // {'width': int, 'height': int,
  // 'boxes': [instances * [left, top, right, bottom, confidence]],
  // 'masks': [instances * [bool mask of size (h,w)]
  // 'scores': [instances of double],
  // 'classes': [instances of int]}

  static Uint8List imageToByteListFloat32(
      image_package.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (image_package.getRed(pixel) - mean) / std;
        buffer[pixelIndex++] = (image_package.getGreen(pixel) - mean) / std;
        buffer[pixelIndex++] = (image_package.getBlue(pixel) - mean) / std;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  static Future predict(image_package.Image image, String path,
      {List<Annotation>? annotations}) async {
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

    // inference
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
        image.width, image.height, renormBoxes, offsetClasses, scores, path);
  }
}
