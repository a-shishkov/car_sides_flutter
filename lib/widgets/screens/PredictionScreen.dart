import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../models/PredictionModel.dart';
import '../painters/PredictionPainter.dart';

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
        title: Text("Prediction"),
      ),
      body: Container(
        child: Center(
          child: FutureBuilder<Map>(
            future: widget.prediction.paint(
                threshold: 0.3, color: ui.Color.fromARGB(100, 100, 100, 255)),
            builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
              if (snapshot.hasData) {
                return FittedBox(
                  child: SizedBox(
                    width: snapshot.data!['width'].toDouble(),
                    height: snapshot.data!['height'].toDouble(),
                    child: CustomPaint(
                        foregroundPainter:
                            PredictionPainter(snapshot.data!['instances']),
                        child: Image.asset(widget.imagePath!)),
                  ),
                );
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
      File(
        widget.image!.path,
      ),
    );
  }
}
