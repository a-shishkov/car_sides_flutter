import 'package:flutter_app/mrcnn/utils.dart';
import 'package:flutter_app/utils/PredictionImage.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'configs.dart';
import 'package:collection/collection.dart';

//  Utility Functions
List computeBackboneShapes(List imageShape, List<int> backboneStrides) {
  return List.generate(
      backboneStrides.length,
      (i) =>
          List.generate(2, (j) => (imageShape[j] / backboneStrides[i]).ceil()),
      growable: false);
}

class MaskRCNN {
  Interpreter interpreter;

  late TensorBufferFloat detections;
  late TensorBufferFloat mrcnnMask;

  MaskRCNN(this.interpreter);

  MaskRCNN.fromAddress(int address)
      : interpreter = Interpreter.fromAddress(address);

  Map<String, List> moldInputs(PredictionImage image) {
    var resize = resizeImage(PredictionImage.from(image),
        minDim: CarPartsConfig.IMAGE_MIN_DIM,
        maxDim: CarPartsConfig.IMAGE_MAX_DIM,
        minScale: CarPartsConfig.IMAGE_MIN_SCALE,
        mode: CarPartsConfig.IMAGE_RESIZE_MODE);

    List moldedImage =
        moldImage((resize['image'] as PredictionImage).imageList);

    var imageMeta = composeImageMeta(0, [image.height, image.width, 3],
        moldedImage.shape, resize['window'], resize['scale']);

    return {
      'molded_images': [moldedImage],
      'image_metas': [imageMeta],
      'windows': [resize['window']]
    };
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

    if (N == 0) return List.filled(4, List.empty());

    window = normBoxes([window], imageShape)[0];
    var wy1 = window[0];
    var wx1 = window[1];
    var wy2 = window[2];
    var wx2 = window[3];
    var shift = [wy1, wx1, wy1, wx1];
    var wh = wy2 - wy1;
    var ww = wx2 - wx1;
    var scale = [wh, ww, wh, ww];

    var boxes = List.generate(
        N,
        (i) =>
            List.generate(4, (j) => (detections[i][j] - shift[j]) / scale[j]));
    boxes = denormBoxes(boxes, originalImageShape);

    // Checking for similar results
    List<List> noDuplicateBoxes = [];
    var equals = false;
    for (var box in boxes) {
      for (var noDuplicateBox in noDuplicateBoxes) {
        if (ListEquality().equals(box, noDuplicateBox)) {
          equals = true;
          break;
        }
      }
      if (!equals)
        noDuplicateBoxes.add(box);
      else
        equals = false;
    }
    boxes = noDuplicateBoxes;
    N = boxes.length;

    var classIDs = List.generate(N, (i) => detections[i][4].toInt());
    var scores = List.generate(N, (i) => detections[i][5]);
    var masks = List.generate(
        N,
        (i) => List.generate(
            mrcnnMask[i].length,
            (j) => List.generate(mrcnnMask[i][j].length,
                (k) => mrcnnMask[i][j][k][classIDs[i]])));

/*     List maskImages = [];
    print(N);
    print(masks.shape);
    print(boxes.shape);
    for (var i = 0; i < N; i++) {
      print('before maskImages');
      maskImages.add(await unmoldBboxMask(masks[i], boxes[i]));
      print('afte  maskImages');
    } */
/*     List fullMasks = List.generate(
        N, (i) => unmoldFullMask(masks[i], boxes[i], originalImageShape));

    List stackedFullMask = List.generate(
        originalImageShape[0],
        (i) => List.generate(
            originalImageShape[1],
            (j) =>
                List.generate(fullMasks.shape[0], (k) => fullMasks[k][i][j]))); */

    return [boxes, classIDs, scores, masks];
  }

  detect(PredictionImage image) {
    var mold = moldInputs(PredictionImage.from(image));

    var anchors = [getAnchors(mold['molded_images']!.shape.sublist(1))];

    var inputs = [mold['molded_images']!, mold['image_metas']!, anchors];
    var outputTensors = getOutputTensors();

    var outputShapes = outputTensors['output_shapes'];
    var outputs = outputTensors['outputs'];

    interpreter.runForMultipleInputs(inputs, outputs);

    List detectionsList = detections.getDoubleList().reshape(outputShapes[3]);
    List mrcnnMaskList = mrcnnMask.getDoubleList().reshape(outputShapes[4]);

    var unmold = unmoldDetections(
        detectionsList[0],
        mrcnnMaskList[0],
        image.imageList.shape,
        mold['molded_images']!.shape.sublist(1),
        mold['windows']![0]);
    var result = {
      'boxes': unmold[0],
      'class_ids': unmold[1],
      'scores': unmold[2],
      'masks': unmold[3]
    };
    return result;
  }

  getOutputTensors() {
    var outputTensors = interpreter.getOutputTensors();
    var outputShapes = [];
    outputTensors.forEach((tensor) {
      outputShapes.add(tensor.shape);
    });

    detections = TensorBufferFloat(outputShapes[3]);
    mrcnnMask = TensorBufferFloat(outputShapes[4]);
    var outputs = <int, Object>{};
    for (var i = 0; i < outputTensors.length; i++) {
      if (i == 3)
        outputs[i] = detections.buffer;
      else if (i == 4)
        outputs[i] = mrcnnMask.buffer;
      else
        outputs[i] = TensorBufferFloat(outputShapes[i]).buffer;
    }

    return {'output_shapes': outputShapes, 'outputs': outputs};
  }

  List getAnchors(List imageShape) {
    /* Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
    String appDocumentsPath = appDocumentsDirectory.path;
    
    var filename = '$appDocumentsPath/anchors';
    for (var shape in imageShape) filename += '_$shape';
    filename += '.json';
    if (await File(filename).exists()) {
      print('Anchors exist');
      return jsonDecode(await File(filename).readAsString());
    } */
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

List composeImageMeta(imageId, originalImageShape, imageShape, window, scale,
    [activeClassIds]) {
  if (activeClassIds == null) {
    activeClassIds = List.filled(CarPartsConfig.NUM_CLASSES, 0);
  }

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
