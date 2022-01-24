import 'package:flutter/material.dart';

class Crosshair extends StatelessWidget {
  Crosshair({required this.position, this.size = 20.0});

  final Offset position;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
        top: position.dy - size / 2,
        left: position.dx - size / 2,
        child: Container(
          width: size,
          height: size,
          child: Icon(
            Icons.add,
            size: size,
          ),
        ));
  }
}
