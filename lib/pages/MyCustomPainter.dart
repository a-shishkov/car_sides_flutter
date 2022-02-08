import 'package:flutter/material.dart';
import 'package:flutter_app/mrcnn/utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:ui' as ui;

import '../utils/ImageExtender.dart';

class MyCustomPainter extends CustomPainter {
  MyCustomPainter(this.boxes, this.masks, this.img, this.imageSize);

  final List boxes;
  final List masks;
  final ui.Image img;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) async {
    print('size $size $imageSize');
    var scaleX = size.width / imageSize.width;
    var scaleY = size.height / imageSize.height;

    var rects = List.generate(
        boxes.length,
        (i) => Rect.fromLTRB(boxes[i][1] * scaleX, boxes[i][0] * scaleY,
            boxes[i][3] * scaleX, boxes[i][2] * scaleY));
    for (var i = 0; i < rects.length; i++) {
      canvas.drawRect(
          rects[i],
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    canvas.drawImage(
        img, Offset(boxes[0][1] * scaleX, boxes[0][0] * scaleY), Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
