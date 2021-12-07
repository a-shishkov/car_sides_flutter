import 'package:flutter_app/mrcnn/utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'config.dart';
import 'package:collection/collection.dart';

//  Utility Functions
List computeBackboneShapes(List imageShape, List<int> backboneStrides) {
  var output = [];
  for (int value in backboneStrides)
    output
        .add([(imageShape[0] / value).ceil(), (imageShape[1] / value).ceil()]);

  return output;
}

class MaskRCNN {
  Interpreter interpreter;

  MaskRCNN(this.interpreter);

  MaskRCNN.fromAddress(int address)
      : interpreter = Interpreter.fromAddress(address);

  moldInputs(image) {
    var resizeOutput = resizeImage(image,
        minDim: CarPartsConfig.IMAGE_MIN_DIM,
        maxDim: CarPartsConfig.IMAGE_MAX_DIM,
        minScale: CarPartsConfig.IMAGE_MIN_SCALE,
        mode: CarPartsConfig.IMAGE_RESIZE_MODE);
    List moldedImage = resizeOutput[0];
    var window = resizeOutput[1];
    var scale = resizeOutput[2];
    // var padding = resizeOutput[3];
    // var crop = resizeOutput[4];
    moldedImage = moldImage(moldedImage);
    var zerosList = List.filled(CarPartsConfig.NUM_CLASSES, 0);
    var imageMeta = composeImageMeta(0, [image.height, image.width, 3],
        moldedImage.shape, window, scale, zerosList);
    return [
      [moldedImage],
      [imageMeta],
      [window]
    ];
  }

  List unmoldDetections(
      detections, List mrcnnMask, originalImageShape, imageShape, window) {
    var N = detections.length;
    for (var i = 0; i < detections.length; i++) {
      if (detections[i][4] == 0) {
        N = i;
        break;
      }
    }
    var boxes = [];
    var classIds = [];
    var scores = [];
    List masks = [];

    if (N == 0) return [boxes, classIds, scores, masks];

    for (var i = 0; i < N; i++) {
      boxes.add(List.generate(4, (j) => detections[i][j]));
      classIds.add(detections[i][4].toInt());
      scores.add(detections[i][5]);
      var tempList = [];
      for (var j = 0; j < mrcnnMask[i].length; j++) {
        var tempList2 = [];
        for (var k = 0; k < mrcnnMask[i][j].length; k++) {
          tempList2.add(mrcnnMask[i][j][k][classIds[i]]);
        }
        tempList.add(tempList2);
      }
      masks.add(tempList);
    }
    window = normBoxes([window], imageShape)[0];
    var wy1 = window[0];
    var wx1 = window[1];
    var wy2 = window[2];
    var wx2 = window[3];
    var shift = [wy1, wx1, wy1, wx1];
    var wh = wy2 - wy1;
    var ww = wx2 - wx1;
    var scale = [wh, ww, wh, ww];
    for (var i = 0; i < boxes.shape[0]; i++) {
      for (var j = 0; j < boxes.shape[1]; j++) {
        boxes[i][j] = (boxes[i][j] - shift[j]) / scale[j];
      }
    }
    boxes = denormBoxes(boxes, originalImageShape);
    Function eq = const ListEquality().equals;
    var boxesOutput = [];
    var equals = false;
    for (var box in boxes) {
      for (var boxOut in boxesOutput) {
        if (eq(box, boxOut)) {
          equals = true;
          break;
        }
      }
      if (!equals)
        boxesOutput.add(box);
      else
        equals = false;
    }
    boxes = boxesOutput;
    N = boxes.length;
    List fullMasks = [];
    for (var i = 0; i < N; i++) {
      var fullMask = unmoldMask(masks[i], boxes[i], originalImageShape);
      fullMasks.add(fullMask);
    }
    return [boxes, classIds, scores, fullMasks];
  }

  detect(image) async {
    // TODO: map
    var moldOutput = moldInputs(image);
    List moldedImages = moldOutput[0];
    List imageMetas = moldOutput[1];
    List windows = moldOutput[2];

    var anchors = [await getAnchors(moldedImages.shape.sublist(1))];

    var inputs = [moldedImages, imageMetas, anchors];
    var outputTensors = interpreter.getOutputTensors();
    var outputShapes = [];
    outputTensors.forEach((tensor) {
      outputShapes.add(tensor.shape);
    });

    var detections = TensorBufferFloat(outputShapes[3]);
    var mrcnnMask = TensorBufferFloat(outputShapes[4]);
    var outputs = <int, Object>{};
    for (var i = 0; i < outputTensors.length; i++) {
      if (i == 3)
        outputs[i] = detections.buffer;
      else if (i == 4)
        outputs[i] = mrcnnMask.buffer;
      else
        outputs[i] = TensorBufferFloat(outputShapes[i]).buffer;
    }

    interpreter.runForMultipleInputs(inputs, outputs);

    // interpreter.close();

    List detectionsList = detections.getDoubleList().reshape(outputShapes[3]);
    List mrcnnMaskList = mrcnnMask.getDoubleList().reshape(outputShapes[4]);
    var unmoldOutput = unmoldDetections(detectionsList[0], mrcnnMaskList[0],
        imageTo3DList(image).shape, moldedImages.shape.sublist(1), windows[0]);

    var result = {
      "rois": unmoldOutput[0],
      "class_ids": unmoldOutput[1],
      "scores": unmoldOutput[2],
      "masks": unmoldOutput[3]
    };
    return result;
  }

  getOuputTensors() {
    var outputTensors = interpreter.getOutputTensors();
    var outputShapes = [];
    outputTensors.forEach((tensor) {
      outputShapes.add(tensor.shape);
    });

    var detections = TensorBufferFloat(outputShapes[3]);
    var mrcnnMask = TensorBufferFloat(outputShapes[4]);
    var outputs = <int, Object>{};
    for (var i = 0; i < outputTensors.length; i++) {
      if (i == 3)
        outputs[i] = detections.buffer;
      else if (i == 4)
        outputs[i] = mrcnnMask.buffer;
      else
        outputs[i] = TensorBufferFloat(outputShapes[i]).buffer;
    }
    return [detections, mrcnnMask, outputShapes, outputs];
  }

  Future<List> getAnchors(List imageShape) async {
    // Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
    // String appDocumentsPath = appDocumentsDirectory.path;
    //
    // var filename = '$appDocumentsPath/anchors';
    // for (var shape in imageShape) filename += '_$shape';
    // filename += '.json';
    // if (await File(filename).exists()) {
    //   print('Anchors exist');
    //   return jsonDecode(await File(filename).readAsString());
    // }
    // TODO: cache anchors
    var backboneShapes =
        computeBackboneShapes(imageShape, CarPartsConfig.BACKBONE_STRIDES);
    var anchors = generatePyramidAnchors(
        CarPartsConfig.RPN_ANCHOR_SCALES,
        CarPartsConfig.RPN_ANCHOR_RATIOS,
        backboneShapes,
        CarPartsConfig.BACKBONE_STRIDES,
        CarPartsConfig.RPN_ANCHOR_STRIDE);
    anchors = normBoxes(anchors, [imageShape[0], imageShape[1]]);
    // await File(filename).writeAsString(jsonEncode(anchors));
    return anchors;
  }
}

List composeImageMeta(
    imageId, originalImageShape, imageShape, window, scale, activeClassIds) {
  var meta = [imageId] +
      originalImageShape +
      imageShape +
      window +
      [scale] +
      activeClassIds;
  meta = List.generate(meta.length, (i) => meta[i].toDouble());
  return meta;
}

List moldImage(List image) {
  for (int i = 0; i < image.length; i++)
    for (int j = 0; j < image[i].length; j++)
      for (int k = 0; k < 3; k++)
        image[i][j][k] -= CarPartsConfig.MEAN_PIXEL[k];

  return image;
}
