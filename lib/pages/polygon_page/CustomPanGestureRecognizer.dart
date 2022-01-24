import 'package:flutter/gestures.dart';

class CustomPanGestureRecognizer extends OneSequenceGestureRecognizer {
  final Function onPanDown;
  final Function onPanUpdate;

  CustomPanGestureRecognizer({
    required this.onPanDown,
    required this.onPanUpdate,
  });

  @override
  void addPointer(PointerEvent event) {
    startTrackingPointer(event.pointer);
    onPanDown(event.position);
    // resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onPanUpdate(event.position);
    }
    if (event is PointerUpEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'customPan';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
