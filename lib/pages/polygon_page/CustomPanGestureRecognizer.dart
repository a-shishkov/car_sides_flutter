import 'package:flutter/gestures.dart';

class CustomPanGestureRecognizer extends OneSequenceGestureRecognizer {
  final Function onPanDown;
  final Function onPanUpdate;
  final Function onPanEnd;

  CustomPanGestureRecognizer({
    required this.onPanDown,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  void addPointer(PointerEvent event) {
    print('addPointer ${event.localPosition} ${event.position}');
    startTrackingPointer(event.pointer);
    resolve(GestureDisposition.accepted);
    onPanDown(event.position);
    // if (onPanDown(event.position)) {
    //   startTrackingPointer(event.pointer);
    //   resolve(GestureDisposition.accepted);
    // } else {
    //   stopTrackingPointer(event.pointer);
    // }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onPanUpdate(DragUpdateDetails(
          globalPosition: event., localPosition: event.localPosition));
    }
    if (event is PointerUpEvent) {
      onPanEnd(event.position);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'customPan';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
