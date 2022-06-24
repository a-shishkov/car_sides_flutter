import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../models/PaintModel.dart';
import '../../models/PredictionModel.dart';

// Used to display bboxes masks and captions from server on image
class PredictionPainter extends CustomPainter {
  PredictionPainter(this.detections);

  final List<PaintModel> detections;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < detections.length; i++) {
      var score = detections[i].score;
      var _class = detections[i].classID;
      var box = detections[i].box;
      var mask = detections[i].mask;

      if (mask != null) canvas.drawImage(mask, Offset.zero, Paint());
      drawBox(canvas, box);
      drawCaptions(canvas, score, _class, box);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  drawBox(Canvas canvas, List box) {
    var rect = Rect.fromLTRB(box[1], box[0], box[3], box[2]);
    canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  void drawCaptions(Canvas canvas, double score, int _class, List box) {
    var rect = Rect.fromLTRB(box[1], box[0], box[3], box[2]);
    var className = PredictionModel.class_names[_class];

    var builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 20));
    builder.addText('$className ${score.toStringAsFixed(2)}');
    canvas.drawParagraph(
        builder.build()..layout(ui.ParagraphConstraints(width: 200)),
        rect.topLeft);
  }
}
