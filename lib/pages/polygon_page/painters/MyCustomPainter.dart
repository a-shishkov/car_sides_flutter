import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MyCustomPainter extends CustomPainter {
  int? selectedPoint;
  List<Offset> points;
  double pointRadius;

  MyCustomPainter(this.points, this.selectedPoint, this.pointRadius);

  @override
  void paint(Canvas canvas, Size size) {
    Paint pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    Paint polygonPaint = Paint()
      ..color = Colors.yellow.withOpacity(1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    Paint fillPaint = Paint()..color = Colors.yellow.withOpacity(0.3);

    canvas.drawPath(Path()..addPolygon(points, true), polygonPaint);
    canvas.drawPath(Path()..addPolygon(points, true), fillPaint);
    for (var i = 0; i < points.length; i++) {
      if (i == selectedPoint) {
        canvas.drawCircle(points[i], pointRadius * 2, pointPaint);
      } else {
        canvas.drawCircle(points[i], pointRadius, pointPaint);
      }
    }
    // canvas.drawPoints(PointMode.points, points, pointPaint);
  }

  @override
  bool shouldRepaint(covariant MyCustomPainter oldDelegate) {
    if (!listEquals(points, oldDelegate.points)) {
      return true;
    }
    if (selectedPoint != oldDelegate.selectedPoint) {
      return true;
    }
    return false;
  }
}
