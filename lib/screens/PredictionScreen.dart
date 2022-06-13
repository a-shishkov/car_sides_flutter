import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/PredictionModel.dart';

class PredictionPainter extends CustomPainter {
  PredictionPainter(this.boxes, this.masks);

  final List boxes;
  final List masks;

  @override
  void paint(Canvas canvas, Size size) {
    for (var box in boxes) {
      drawBox(canvas, box);
    }
    for (var mask in masks) {
      canvas.drawImage(mask, Offset.zero, Paint());
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  drawBox(Canvas canvas, List box) {
    var left = box[0], top = box[1], right = box[2], bottom = box[3];
    var rect = Rect.fromLTRB(left, top, right, bottom);
    canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  drawMask(Canvas canvas, List mask) {
    List<Offset> points = [];
    double i = 0;
    for (var row in mask) {
      double j = 0;
      for (var pixel in row) {
        if (pixel) points.add(Offset(i, j));
        j++;
      }
      i++;
    }

    canvas.drawPoints(PointMode.points, points, Paint()..color = Colors.red);
  }
}

class PredictionScreen extends StatefulWidget {
  PredictionScreen(
      {this.image,
      this.imagePath,
      required this.prediction,
      this.isAsset = false,
      Key? key})
      : super(key: key) {
    assert(image != null || imagePath != null);
  }

  final XFile? image;
  final String? imagePath;
  final PredictionModel prediction;
  final bool isAsset;

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Result Car Damage"),
      ),
      body: Center(
        child: Container(
          child: FutureBuilder<Map>(
            future: widget.prediction.paint(threshold: 0.0),
            builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
              if (snapshot.hasData) {
                return CustomPaint(
                    foregroundPainter: PredictionPainter(
                        snapshot.data!['boxes'], snapshot.data!['masks']),
                    child: image);
              } else {
                return Text("Waiting");
              }
            },
          ),
        ),
      ),
    );
  }

  Image get image {
    if (widget.isAsset) return Image.asset(widget.imagePath!);

    return Image.file(
      File(widget.image!.path),
    );
  }
}
