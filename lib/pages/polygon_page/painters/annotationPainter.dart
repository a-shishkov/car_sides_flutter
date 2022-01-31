import 'package:flutter/material.dart';
import 'package:flutter_app/annotation/Annotation.dart';
import 'package:flutter_app/pages/polygon_page/AnnotationPage.dart';
import 'package:flutter_app/utils/ImageExtender.dart';

class MyCustomPainter extends CustomPainter {
  int currentAnnotation;
  Position? selectedPoint;

  List<Annotation> annotations;

  double _pointStrokeWidth = 1;
  double pointRadius;
  double get _circleRadius => pointRadius - _pointStrokeWidth;

  MyCustomPainter(this.annotations, this.currentAnnotation, this.selectedPoint,
      this.pointRadius);

  @override
  void paint(Canvas canvas, Size size) {
    Paint pointPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _pointStrokeWidth;

    Paint polygonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1;
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

    /* for (var i = -1; i < annotations.length; i++) {
      var segmentation;
      Color color;
      if (i == -1) {
        segmentation = points;
        color = Colors.white;
      } else {
        segmentation = annotations[i].segmetation;
        color = HSVColor.fromAHSV(1, (i * 100) % 360, 1, 1).toColor();
      }
      canvas.drawPath(
          Path()..addPolygon(segmentation, true), polygonPaint..color = color);
      canvas.drawPath(Path()..addPolygon(points, true),
          Paint()..color = color.withOpacity(0.15));
      for (var j = 0; j < segmentation.length; j++) {
        if (j == selectedPoint) {
          canvas.drawCircle(
              segmentation[j], _circleRadius * 2, pointPaint..color = color);
        } else {
          canvas.drawCircle(
              segmentation[j], _circleRadius, pointPaint..color = color);
        }
      }
      // canvas.drawPoints(PointMode.points, points, pointPaint);}
    } */
  }

  @override
  bool shouldRepaint(MyCustomPainter oldDelegate) {
    return true;
  }
}
