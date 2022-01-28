import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:touchable/touchable.dart';
import 'AnnotationController.dart';

class AnnotationPainter extends CustomPainter {
  AnnotationPainter(this.context, this.points)
      : controller = Provider.of<AnnotationController>(context, listen: false);

  final AnnotationController controller;
  final BuildContext context;
  List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    // print(controller.j++);
    var tCanvas = TouchyCanvas(context, canvas);
    tCanvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.transparent,
        onPanStart: controller.onPanStart,
        onPanDown: controller.onPanDown,
        onPanUpdate: controller.onPanUpdate);

    tCanvas.drawPath(Path()..addPolygon(controller.points, false),
        Paint()..color = Colors.amberAccent.withOpacity(0.5),
        hitTestBehavior: HitTestBehavior.translucent);

    for (var i = 0; i < points.length; i++) {
      var offset = points[i];
      tCanvas.drawCircle(
          offset, 30, Paint()..color = Colors.green.withOpacity(0.5),
          onPanStart: (details) {
        controller.onPanStart(details);
        controller.points[i] = details.localPosition;
      }, onPanDown: (details) {
        controller.onPanDown(details);
        controller.points[i] = details.localPosition;
      }, onPanUpdate: (details) {
        controller.onPanUpdate(details);
        controller.points[i] = details.localPosition;
      });
      tCanvas.drawCircle(offset, 10, Paint()..color = Colors.green,
          hitTestBehavior: HitTestBehavior.translucent);
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    // print('points ${controller.points} old ${oldDelegate.points}');
    // print('= ${controller.points=oldDelegate.points}');
    // if(!listEquals(points, oldDelegate.points))
    // {
    //   return true;
    // }
    return false;
  }
}
