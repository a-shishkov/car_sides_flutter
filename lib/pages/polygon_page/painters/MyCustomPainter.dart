import 'dart:ui';

import 'package:flutter/material.dart';

class MyCustomPainter extends CustomPainter {
  int? selectedPoint;
  List<Offset> points;

  MyCustomPainter(this.points, this.selectedPoint);

  @override
  void paint(Canvas canvas, Size size) {
    Paint pointPaint = Paint()..color = Colors.pink;
    Paint selectedPointPaint = Paint()..color = Colors.yellow.withOpacity(0.5);

    canvas.drawPath(
        Path()..addPolygon(points, true), Paint()..color = Colors.yellow.withOpacity(0.3));
    for (var i = 0; i < points.length; i++) {
      if (i == selectedPoint) {
        canvas.drawCircle(points[i], 10, selectedPointPaint);
      } else {
        canvas.drawCircle(points[i], 10, pointPaint);
      }
    }
    // canvas.drawPoints(PointMode.points, points, pointPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
