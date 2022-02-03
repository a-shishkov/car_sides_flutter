import 'package:flutter/material.dart';

class TouchBubble extends StatelessWidget {
  TouchBubble({
    required this.position,
    required this.bubbleSize,
  });

  final Offset position;
  final double bubbleSize;

  @override
  Widget build(BuildContext context) {
    return Positioned(
        top: position.dy - bubbleSize / 2,
        left: position.dx - bubbleSize / 2,
        child: Container(
          width: bubbleSize,
          height: bubbleSize,
          color: Colors.red,
        ));
  }
}