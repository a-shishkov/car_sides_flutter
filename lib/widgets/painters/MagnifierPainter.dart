import 'package:flutter/material.dart';

// Crosshair painter
class MagnifierPainter extends CustomPainter {
  final double strokeWidth;
  final Color color;
  const MagnifierPainter(
      {this.strokeWidth = 5, this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    Paint circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    Paint crossHairPaint = Paint()
      ..strokeWidth = 2
      ..color = color;

    canvas.drawCircle(
        size.center(Offset(0, 0)), size.longestSide / 2, circlePaint);
    canvas.drawLine(size.center(Offset(0, -10)), size.center(Offset(0, 10)),
        crossHairPaint);
    canvas.drawLine(size.center(Offset(-10, 0)), size.center(Offset(10, 0)),
        crossHairPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}