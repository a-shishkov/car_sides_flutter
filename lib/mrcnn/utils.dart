import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart';
import 'package:image/image.dart' as image_package;

Map resizeImage(PredictionImage image,
    {minDim, maxDim, minScale, mode = 'square'}) {
  int h = image.height;
  int w = image.width;

  List<int> window = [0, 0, h, w];
  double scale = 1.0;
  List<List<int>> padding = [
    [0, 0],
    [0, 0],
    [0, 0]
  ];
  var crop;

  if (mode == 'none') {
    return {
      'image': image,
      'window': window,
      'scale': scale,
      'padding': padding,
      'crop': crop
    };
  }

  if (minDim != null) {
    // Scale up but not down
    scale = max(1, minDim / min(h, w));
  }
  if (minScale != null && scale < minScale) {
    scale = minScale;
  }
  // Does it exceed max dim?
  int imageMax;

  if (maxDim != null && mode == 'square') {
    imageMax = max(h, w);
    if ((imageMax * scale) > maxDim) {
      scale = maxDim / imageMax;
    }
  }

  if (mode == 'square') {
    if (max(h, w) == h) {
      int newWidth = (w * scale).round();

      int dstX = (maxDim - newWidth) ~/ 2;

      image.image = drawImage(
          Image(maxDim, maxDim, channels: Channels.rgb), image.image,
          dstX: dstX, dstW: newWidth);

      h = image.height;
      w = newWidth;
    } else {
      int newHeight = (h * scale).round();

      int dstY = (maxDim - newHeight) ~/ 2;

      image.image = drawImage(
          Image(maxDim, maxDim, channels: Channels.rgb), image.image,
          dstY: dstY, dstH: newHeight);

      h = newHeight;
      w = image.width;
    }

    int topPad = (maxDim - h) ~/ 2;
    int bottomPad = maxDim - h - topPad;
    int leftPad = (maxDim - w) ~/ 2;
    int rightPad = maxDim - w - leftPad;
    padding = [
      [topPad, bottomPad],
      [leftPad, rightPad],
      [0, 0]
    ];

    window = [topPad, leftPad, h + topPad, w + leftPad];
  }

  return {
    'image': image,
    'window': window,
    'scale': scale,
    'padding': padding,
    'crop': crop
  };
}

List unmoldMask(List mask, bbox) {
  int y1 = bbox[0];
  int x1 = bbox[1];
  int y2 = bbox[2];
  int x2 = bbox[3];

  // TODO: probably bug with width and height
  var maskGrayscale = PredictionImage.fromBytes(
      mask.shape[1],
      mask.shape[0],
      List.generate(
          mask.shape[0],
          (i) => List.generate(
              mask.shape[1], (j) => (mask[i][j] * 255).toInt())).flatten(),
      format: image_package.Format.luminance);

  maskGrayscale.resize((x2 - x1), (y2 - y1));
  var maskBytes = maskGrayscale
      .getBytes(format: image_package.Format.luminance)
      .reshape([maskGrayscale.height, maskGrayscale.width]);
  return maskBytes;
}

Future<ui.Image> unmoldBboxMask(List mask, List bbox,
    {threshold = 0.5,
    color = const ui.Color.fromARGB(255, 255, 255, 255)}) async {
  List maskBytes = unmoldMask(mask, bbox);
  var maskImage = image_package.Image.fromBytes(
      maskBytes.shape[1],
      maskBytes.shape[0],
      List.generate(
          maskBytes.shape[0],
          (i) => List.generate(
              maskBytes.shape[1],
              (j) => [
                    color.red,
                    color.green,
                    color.blue,
                    maskBytes[i][j] > 255 * threshold ? (255 * 0.8).toInt() : 0
                  ])).flatten());
  var uiImage = Completer<ui.Image>();
  ui.decodeImageFromList(Uint8List.fromList(image_package.encodePng(maskImage)),
      (result) => uiImage.complete(result));
  return uiImage.future;
}

List unmoldFullMask(List mask, bbox, imageShape, {threshold = 0.5}) {
  int y1 = bbox[0];
  int x1 = bbox[1];
  int y2 = bbox[2];
  int x2 = bbox[3];

  List maskBytes = unmoldMask(mask, bbox);
  var fullMask = List.generate(
      imageShape[0],
      (i) => List.generate(
          imageShape[1],
          (j) => (i >= y1 && i < y2 && j >= x1 && j < x2)
              ? maskBytes[i - y1][j - x1] >= threshold * 255
              : false));

  return fullMask;
}

// Anchors

List generateAnchors(scales, ratios, shape, featureStride, int anchorStride) {
  scales = List.generate(ratios.length, (index) => scales);

  var heights =
      List.generate(ratios.length, (i) => scales[i] / sqrt(ratios[i]));
  var widths = List.generate(ratios.length, (i) => scales[i] * sqrt(ratios[i]));
  var shiftsY = [];
  for (var i = 0; i < shape[0]; i += anchorStride) {
    shiftsY.add(i * featureStride);
  }
  var shiftsX = [];
  for (var i = 0; i < shape[1]; i += anchorStride) {
    shiftsX.add(i * featureStride);
  }
  var shiftsXY = meshGrid(shiftsX, shiftsY);
  var boxWidthsCentersX = meshGrid(widths, shiftsXY[0]);
  var boxHeightsCentersY = meshGrid(heights, shiftsXY[1]);
  var boxCenters = stack(boxHeightsCentersY[1], boxWidthsCentersX[1]);
  var boxSizes = stack(boxHeightsCentersY[0], boxWidthsCentersX[0]);
  var boxes = concatenate(boxCenters, boxSizes);
  return boxes;
}

List generatePyramidAnchors(List scales, List ratios, List featureShapes,
    featureStrides, int anchorStride) {
  var anchors = List.generate(
      scales.length,
      (i) => generateAnchors(scales[i], ratios, featureShapes[i],
          featureStrides[i], anchorStride));
  var pyramidAnchors = [];
  for (var anchor in anchors) {
    pyramidAnchors.addAll(anchor);
  }
  return pyramidAnchors;
}

List normBoxes(boxes, shape) {
  var h = shape[0];
  var w = shape[1];
  var scale = [h - 1, w - 1, h - 1, w - 1];
  var shift = [0, 0, 1, 1];
  return List.generate(
      boxes.length,
      (i) => List.generate(
          boxes[i].length, (j) => (boxes[i][j] - shift[j]) / scale[j]));
}

List<List> denormBoxes(List<List> boxes, shape) {
  var h = shape[0];
  var w = shape[1];
  var scale = [h - 1, w - 1, h - 1, w - 1];
  var shift = [0, 0, 1, 1];
  for (var i = 0; i < boxes.shape[0]; i++) {
    for (var j = 0; j < boxes.shape[1]; j++) {
      boxes[i][j] = (boxes[i][j] * scale[j] + shift[j]).round();
    }
  }
  return boxes;
}

List addPadding(List image, List padding) {
  var w = image.shape[1];
  if (padding[0].any((element) => element != 0)) {
    for (var i = 0; i < padding[0][0]; i++)
      image.insert(0, List.filled(w, [0, 0, 0]));
    for (var i = 0; i < padding[0][1]; i++)
      image.add(List.filled(w, [0, 0, 0]));
  } else if (padding[1].any((element) => element != 0)) {
    for (var i = 0; i < padding[1][0]; i++)
      image.forEach((element) => element.insert(0, [0, 0, 0]));
    for (var i = 0; i < padding[1][1]; i++)
      image.forEach((element) => element.add([0, 0, 0]));
  }
  return image;
}

List meshGrid(List x, List y) {
  var flattenX = x.flatten();
  var flattenY = y.flatten();
  var outputX = List.generate(flattenY.length,
      (i) => List.generate(flattenX.length, (j) => flattenX[j]));
  var outputY = List.generate(flattenY.length,
      (i) => List.generate(flattenX.length, (j) => flattenY[i]));
  return [outputX, outputY];
}

List stack(List x, List y, {axis = 2}) {
  var output = [];
  for (var i = 0; i < x.shape[0]; i++)
    for (var j = 0; j < x.shape[1]; j++) output.add([x[i][j], y[i][j]]);

  return output;
}

List concatenate(List x, List y, {axis = 1}) {
  var output = [];
  for (var i = 0; i < x.shape[0]; i++) {
    output.add(List.generate(x.shape[1], (j) => x[i][j] - 0.5 * y[i][j]) +
        List.generate(x.shape[1], (j) => x[i][j] + 0.5 * y[i][j]));
  }
  return output;
}
