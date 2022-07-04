import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/PaintModel.dart';
import '../../models/DetectionModel.dart';
import '../painters/DetectionPainter.dart';

// Screen is using to display result of server inference
class DetectionScreen extends StatelessWidget {
  DetectionScreen({required this.detection, Key? key}) : super(key: key);

  final DetectionModel detection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Detection"),
      ),
      body: FutureBuilder<List<PaintModel>>(
        future: detection.paint(
            threshold: 0.5, color: ui.Color.fromARGB(75, 81, 255, 0)),
        builder:
            (BuildContext context, AsyncSnapshot<List<PaintModel>> snapshot) {
          if (snapshot.hasData) {
            // Use this FittedBox and SizedBox together to correctly upscale canvas
            return InteractiveViewer(
              maxScale: 10,
              child: Container(
                child: Center(
                  child: FittedBox(
                    child: SizedBox(
                      width: detection.width.toDouble(),
                      height: detection.height.toDouble(),
                      child: CustomPaint(
                        foregroundPainter: DetectionPainter(snapshot.data!),
                        child: image,
                      ),
                    ),
                  ),
                ),
              ),
            );
          } else {
            return Container(
              child: Center(
                child: Text("Waiting"),
              ),
            );
          }
        },
      ),
    );
  }

  Image get image {
    if (detection.isAsset)
      return Image.asset(detection.imagePath);
    else
      return Image.file(File(detection.imagePath));
  }
}
