import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../models/PaintModel.dart';
import '../../models/PredictionModel.dart';
import '../painters/PredictionPainter.dart';

// Screen is using to display result of server inference
class PredictionScreen extends StatefulWidget {
  PredictionScreen({required this.prediction, Key? key}) : super(key: key) {
    // assert(image != null || imagePath != null);
  }

  final PredictionModel prediction;

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
        title: Text("Prediction"),
      ),
      body: FutureBuilder<List<PaintModel>>(
        future: widget.prediction
            .paint(threshold: 0.5, color: ui.Color.fromARGB(50, 255, 0, 0)),
        builder:
            (BuildContext context, AsyncSnapshot<List<PaintModel>> snapshot) {
          if (snapshot.hasData) {
            // Use this FittedBox and SizedBox together to correctly upscale canvas
            return InteractiveViewer(
              child: Container(
                child: Center(
                  child: FittedBox(
                    child: SizedBox(
                      width: prediction.width.toDouble(),
                      height: prediction.height.toDouble(),
                      child: CustomPaint(
                        foregroundPainter: PredictionPainter(snapshot.data!),
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
    if (prediction.isAsset) return Image.asset(prediction.imagePath);

    return Image.file(File(prediction.imagePath));
  }

  PredictionModel get prediction => widget.prediction;
}
