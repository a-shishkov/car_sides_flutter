import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../models/PredictionModel.dart';

// Used to display bboxes masks and captions from server on image
class PredictionPainter extends CustomPainter {
  PredictionPainter(this.instances);

  final List instances;

  @override
  void paint(Canvas canvas, Size size) {
    for (var class_i = 0; class_i < instances.length; class_i++) {
      for (var instance in instances[class_i]) {
        var box = instance[0];
        var mask = instance[1];

        drawBox(canvas, box);
        canvas.drawImage(mask, Offset.zero, Paint());
        drawCaptions(canvas, box, class_i);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  drawBox(Canvas canvas, List box) {
    var left = box[0], top = box[1], right = box[2], bottom = box[3];
    var rect = Rect.fromLTRB(left, top, right, bottom);
    canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  void drawCaptions(Canvas canvas, List box, int class_i) {
    var rect = Rect.fromLTRB(box[0], box[1], box[2], box[3]);
    var className = PredictionModel.classes[class_i];
    var score = box[4].toStringAsFixed(2);

    var builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 50));
    builder.addText('$className $score');
    canvas.drawParagraph(
        builder.build()..layout(ui.ParagraphConstraints(width: 200)),
        rect.topLeft);
  }
}
