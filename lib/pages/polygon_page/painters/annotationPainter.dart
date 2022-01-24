import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:touchable/touchable.dart';

class AnnotationPainter extends CustomPainter {
  AnnotationPainter(this.context, this.image, this.offsets);

  final BuildContext context;
  final ui.Image image;
  final List<Offset> offsets;

  @override
  void paint(Canvas canvas, Size size) {
    var offsetss = [
      Offset(10, 100),
      Offset(50, 50),
      Offset(80, 100),
      Offset(50, 100)
    ];
    Paint myPaint = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.red;
    Paint myPaint2 = Paint()
      ..strokeWidth = 20
      ..color = Colors.green;

    var myCanvas = TouchyCanvas(context, canvas);
    myCanvas.drawImage(image, Offset.zero, Paint());
    myCanvas.drawPoints(ui.PointMode.polygon, offsetss, myPaint);
    myCanvas.drawPoints(ui.PointMode.points, offsetss, myPaint2,
        onTapDown: (_) => print('qeqwerqtwt'));
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return true;
    if (!ListEquality().equals(oldDelegate.offsets, this.offsets)) {
      return true;
    }
    return false;
  }
}
