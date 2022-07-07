import 'package:flutter/material.dart';

import '../../models/AnnotationModel.dart';
import '../../models/PositionModel.dart';

class PolygonPainter extends CustomPainter {
  int currentAnnotation;
  Position? selectedPoint;

  List<AnnotationModel> annotations;

  double _pointStrokeWidth = 1;
  double pointRadius;
  double get _circleRadius => pointRadius - _pointStrokeWidth;

  Paint pointPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  Paint polygonPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 1;

  PolygonPainter(this.annotations, this.currentAnnotation, this.selectedPoint,
      this.pointRadius);

  @override
  void paint(Canvas canvas, Size size) {
    // Paint fillPaint = Paint()..color = color.withOpacity(0.15);

    for (var i = 0; i < annotations.length; i++) {
      var segmentation = annotations[i].polygon;
      // Color color = HSVColor.fromAHSV(1, (i * 100) % 360, 1, 1).toColor();
      Color color = currentAnnotation == i ? Colors.red : Colors.white;

      canvas.drawPath(Path()..addPolygon(segmentation.points, true),
          polygonPaint..color = color);
      canvas.drawPath(Path()..addPolygon(segmentation.points, true),
          Paint()..color = color.withOpacity(0.2));

      for (var j = 0; j < segmentation.length; j++) {
        canvas.drawCircle(
            segmentation[j],
            _circleRadius * (selectedPoint == Position(i, j) ? 2 : 1),
            pointPaint..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(PolygonPainter oldDelegate) {
    return true;
  }
}
