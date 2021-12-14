import 'package:flutter_app/utils/image_extender.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as ImagePackage;
import 'dart:ui';
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

ImageExtender applyMask(ImageExtender maskedImage, List mask, Color color,
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
  maskedImage.drawImage(maskImage);
  return maskedImage;
}

displayInstances(ImageExtender originalImage, List boxes, List masks,
    List classIds, classNames,
    {scores,
    title,
    showMask = true,
    showBbox = true,
    colors,
    captions,
    saveMasks = false}) async {
  if (boxes.isEmpty) {
    print("No instances to display");
    return;
  }
  var N = boxes.shape[0];
  if (colors == null) {
    colors = randomColors(N);
  }

  for (var i = 0; i < N; i++) {
    Color color = colors[i];
    //     if not np.any(boxes[i]):
    // # Skip this instance. Has no bbox. Likely lost in image cropping.
    // continue
    var y1 = boxes[i][0];
    var x1 = boxes[i][1];
    var y2 = boxes[i][2];
    var x2 = boxes[i][3];

    originalImage.drawRect(x1, y1, x2, y2,
        ImagePackage.getColor(color.red, color.green, color.blue));

    var mask = masks[i];
    if (saveMasks) {
      ImageExtender maskIE = ImageExtender.fromImage(mask);
      await maskIE.saveToTempDir(
          "${originalImage.path!.split('/').last.split('.').first}_MASK_$i.jpg");
    }
    if (showMask) {
      if (saveMasks) {
        ImageExtender maskIE = ImageExtender.fromImage(mask);
        var maskBytes = maskIE.imageList;
        var boolMask = List.generate(maskBytes.shape[0],
            (index) => List.generate(maskBytes.shape[1], (index) => false));
        for (var i = 0; i < maskBytes.shape[0]; i++) {
          for (var j = 0; j < maskBytes.shape[1]; j++) {
            if ((maskBytes[i][j] as List).first > 0.5 * 255) {
              boolMask[i][j] = true;
            }
          }
        }
        maskIE.resize(originalImage.width, originalImage.height);
        originalImage = applyMask(originalImage, boolMask, color);
      } else {
        originalImage = applyMask(originalImage, mask, color);
        // originalImage.image = ImagePackage.drawImage(originalImage.image, mask);
      }
    }

    if (captions == null) {
      var classId = classIds[i];
      var score = scores != null ? scores[i] : null;
      var label = CarPartsConfig.CLASS_NAMES[classId];
      var caption =
          score != null ? '$label ${score.toStringAsFixed(3)}' : '$label';
      originalImage.drawString(ImagePackage.arial_24, x1, y1 + 8, caption);
    }
  }
  return originalImage;
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
