import 'package:flutter/material.dart';

class AnnotationController extends ChangeNotifier {
  List<Offset> points;
  Function(Offset) setState;
  int j = 0;

  AnnotationController(this.points, this.setState);

  Offset? cursor;
  void updatePositions(Offset localPosition, Offset globalPosition)
  {
    cursor = globalPosition;
    setState(localPosition);
    notifyListeners();
  }

  void onPanStart(DragStartDetails details)
  {
    print(j++);
    // print('pan start');
    updatePositions(details.localPosition, details.globalPosition);
  }

  void onPanDown(DragDownDetails details)
  {
    // print('pan down');
    updatePositions(details.localPosition, details.globalPosition);
  }

  void onPanUpdate(DragUpdateDetails details)
  {
    // print('pan update');
    updatePositions(details.localPosition, details.globalPosition);
  }
}