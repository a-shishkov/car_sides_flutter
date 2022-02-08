import 'package:flutter/material.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'MyCustomPainter.dart';
import 'dart:ui' as ui;

class RawPage extends StatelessWidget {
  const RawPage(this.image, this.img, this.boxes, this.mrcnnMasks, {Key? key})
      : super(key: key);
  final ImageExtender? image;
  final ui.Image? img;
  final List? boxes;
  final List? mrcnnMasks;

  @override
  Widget build(BuildContext context) {
    print('$boxes');
    print('$mrcnnMasks');
    print('${image?.size}');
    return Container(
        child: Center(
            child: image != null
                ? CustomPaint(
                    foregroundPainter:
                        MyCustomPainter(boxes!, mrcnnMasks!, img!, image!.size),
                    child: image!.imageWidget() ?? Container())
                : Text('asdasd')));
  }
}
