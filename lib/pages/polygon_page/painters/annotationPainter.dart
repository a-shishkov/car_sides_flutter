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
    Paint myPaint = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.red;
    Paint myPaint2 = Paint()
      ..strokeWidth = 20
      ..color = Colors.green;

    var myCanvas = TouchyCanvas(context, canvas);
    myCanvas.drawImage(image, Offset.zero, Paint());
    myCanvas.drawPoints(ui.PointMode.polygon, offsets, myPaint);
    for (var off in offsets) {
      myCanvas.drawCircle(off, 10, myPaint2, onTapDown: (_) => print('$off'));
    }
    // myCanvas.drawPoints(ui.PointMode.points, offsets, myPaint2,
    //     onTapDown: (_) => print('qeqwerqtwt'));
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
