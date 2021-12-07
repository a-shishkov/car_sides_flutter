import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as ImagePackage;
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import 'config.dart';

randomColors(N, [bright = true]) {
  var brightness = bright ? 1.0 : 0.7;
  var hsv = List.generate(
      N, (i) => HSVColor.fromAHSV(1.0, i / N * 360.0, 1.0, brightness));
  var rgb = List.generate(N, (i) => hsv[i].toColor());
  // var rgb = List.generate(N, (i) =>[hsv[i].toColor().red, hsv[i].toColor().green, hsv[i].toColor().blue]);
  rgb.shuffle();
  return rgb;
}

ImagePackage.Image applyMask(
    ImagePackage.Image maskedImage, List mask, Color color,
    {alpha = 0.5}) {
  var maskImageList = List.generate(
      mask.shape[0],
          (i) => List.generate(
          mask.shape[1],
              (j) => mask[i][j]
              ? [color.red, color.green, color.blue, (255 * alpha).toInt()]
              : [0, 0, 0, 0]));
  var maskImage = ImagePackage.Image.fromBytes(
      mask.shape[1], mask.shape[0], maskImageList.flatten());
  maskedImage = ImagePackage.drawImage(maskedImage, maskImage);
  return maskedImage;
}

displayInstances(List image, List boxes, List masks, List classIds, classNames,
    {scores, title, showMask = true, showBbox = true, colors, captions}) async {
  if (boxes.isEmpty) {
    print("No instances to display");
    return;
  }
  var N = boxes.shape[0];
  if (colors == null) {
    colors = randomColors(N);
  }

  var height = image.shape[0];
  var width = image.shape[1];

  ImagePackage.Image maskedImage = ImagePackage.Image.fromBytes(
      width, height, image.flatten(),
      format: ImagePackage.Format.rgb);
  for (var i = 0; i < N; i++) {
    Color color = colors[i];
    //     if not np.any(boxes[i]):
    // # Skip this instance. Has no bbox. Likely lost in image cropping.
    // continue
    var y1 = boxes[i][0];
    var x1 = boxes[i][1];
    var y2 = boxes[i][2];
    var x2 = boxes[i][3];

    maskedImage = ImagePackage.drawRect(maskedImage, x1, y1, x2, y2,
        ImagePackage.getColor(color.red, color.green, color.blue));

    var mask = masks[i];
    if (showMask) maskedImage = applyMask(maskedImage, mask, color);

    if (captions == null) {
      var classId = classIds[i];
      var score = scores != null ? scores[i] : null;
      var label = CarPartsConfig.CLASS_NAMES[classId];
      var caption =
      score != null ? '$label ${score.toStringAsFixed(3)}' : '$label';
      maskedImage = ImagePackage.drawString(
          maskedImage, ImagePackage.arial_24, x1, y1 + 8, caption);
    }
  }
  return maskedImage;
/*
  Directory appCacheDirectory = await getTemporaryDirectory();
  String appCachesPath = appCacheDirectory.path;
  var now = DateTime.now();
  var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
  String currentTimeStamp = formatter.format(now);
  var filename = '$appCachesPath/$currentTimeStamp.png';
  await File(filename).writeAsBytes(ImagePackage.encodePng(maskedImage));
  return filename; */
}