import 'dart:math';
import 'package:flutter_app/utils/image_extender.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart';

List imageTo3DList(Image image) {
  List rgbImage = image.getBytes(format: Format.rgb);
  rgbImage = rgbImage.reshape([image.height, image.width, 3]);
  return rgbImage;
}

Future<Map> resizeImage(ImageExtender image,
    {minDim, maxDim, minScale, mode = "square"}) async {
  var h = image.height;
  var w = image.width;

  var window = [0, 0, h, w];
  var scale = 1.0;
  var padding = [
    [0, 0],
    [0, 0],
    [0, 0]
  ];
  var crop;

  if (mode == "none")
    return {
      "image": image,
      "window": window,
      "scale": scale,
      "padding": padding,
      "crop": crop
    };

  if (minDim != null)
    // Scale up but not down
    scale = max(1, minDim / min(h, w));
  if (minScale != null && scale < minScale) scale = minScale;
  // Does it exceed max dim?
  var imageMax;

  if (maxDim != null && mode == "square") {
    imageMax = max(h, w);
    if ((imageMax * scale) > maxDim) scale = maxDim / imageMax;
  }

  if (mode == "square") {

    var ratio = h / maxDim;
    int newWidth = w ~/ ratio;

    int dstX = (maxDim - newWidth) ~/ 2;

    image.image = drawImage(
        Image(maxDim, maxDim, channels: Channels.rgb), image.image,
        dstX: dstX, dstW: newWidth);

    h = image.height;
    w = newWidth;

    int topPad = (maxDim - h) ~/ 2;
    var bottomPad = maxDim - h - topPad;
    int leftPad = (maxDim - w) ~/ 2;
    var rightPad = maxDim - w - leftPad;
    padding = [
      [topPad, bottomPad],
      [leftPad, rightPad],
      [0, 0]
    ];

    window = [topPad, leftPad, h + topPad, w + leftPad];
  }

/*  // Scale?
  if (minDim != null)
    // Scale up but not down
    scale = max(1, minDim / min(h, w));
  if (minScale != null && scale < minScale) scale = minScale;
  // Does it exceed max dim?
  var imageMax;

  if (maxDim != null && mode == "square") {
    imageMax = max(h, w);
    if ((imageMax * scale) > maxDim) scale = maxDim / imageMax;
  }
  if (scale != 1) {
    if (imageMax == h) {
      image.image = copyResize(image.image, height: minDim);
      // await image.save(image.path);
      // image = ImageExtender.from(copyResize(image.image, height: minDim));
    } else {
      image = ImageExtender.fromImage(copyResize(image.image, width: minDim));
    }
    // image = ImageExtender.from(copyRotate(image.image, -90));
  }

  late List imageList;
  if (mode == "square") {
    var h = image.height;
    var w = image.width;
    int topPad = (maxDim - h) ~/ 2;
    var bottomPad = maxDim - h - topPad;
    int leftPad = (maxDim - w) ~/ 2;
    var rightPad = maxDim - w - leftPad;
    padding = [
      [topPad, bottomPad],
      [leftPad, rightPad],
      [0, 0]
    ];
    imageList = image.addPadding(padding);

    `window = [topPad, leftPad, h + topPad, w + leftPad];`
  }
  imageList = imageList.flatten();
  imageList = List.generate(imageList.length, (i) => imageList[i].toDouble());
  imageList = imageList.reshape([maxDim, maxDim, 3]);*/

  return {
    "image": image,
    "window": window,
    "scale": scale,
    "padding": padding,
    "crop": crop
  };
}

Future<List> unmoldMask(List mask, bbox, imageShape) async {
  var threshold = 0.5;
  int y1 = bbox[0];
  int x1 = bbox[1];
  int y2 = bbox[2];
  int x2 = bbox[3];

  var pixelMask = List.generate(
      mask.shape[0],
      (i) => List.generate(mask.shape[1],
          (j) => List.generate(3, (_) => (mask[i][j] * 255).toInt())));

  var maskImage = ImageExtender.fromBytes(
      mask.shape[0], mask.shape[1], pixelMask.flatten());

  var resizeScale = 1;
  maskImage.resize((x2 - x1) * resizeScale, (y2 - y1) * resizeScale);
  var maskBytes = maskImage.imageList;
  var fullMask = List.generate(
      imageShape[0],
      (i) => List.generate(
          imageShape[1],
          (j) => (i >= y1 && i < y2 && j >= x1 && j < x2)
              ? (maskBytes[i - y1][j - x1] as List).first >= threshold * 255
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
  var anchors = [];
  for (var i = 0; i < scales.length; i++) {
    anchors.add(generateAnchors(
        scales[i], ratios, featureShapes[i], featureStrides[i], anchorStride));
  }
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
  var output = [];
  for (var box in boxes) {
    output
        .add(List.generate(box.length, (i) => (box[i] - shift[i]) / scale[i]));
  }
  return output;
}

List denormBoxes(List boxes, shape) {
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
