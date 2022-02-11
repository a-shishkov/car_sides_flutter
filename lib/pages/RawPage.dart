import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'package:flutter_app/utils/prediction_result.dart';
import '../mrcnn/configs.dart';
import 'dart:ui' as ui;

class PredictionPainter extends CustomPainter {
  PredictionPainter(PredictionResult prediction)
      : this.boxes = prediction.boxes,
        this.masks = prediction.masks,
        this.scores = prediction.scores,
        this.classIDs = prediction.classIDs,
        this.classNames = CLASS_NAMES[prediction.model]!;

  // final List<Rect> rects;
  final List boxes;
  final List<ui.Image> masks;
  final List scores;
  final List classIDs;
  final List classNames;

  List<Rect> get rects => List.generate(
      boxes.length,
      (i) => Rect.fromLTRB((boxes[i][1]).toDouble(), (boxes[i][0]).toDouble(),
          (boxes[i][3]).toDouble(), (boxes[i][2]).toDouble()));

  @override
  void paint(Canvas canvas, Size size) async {
    drawRects(canvas);
    drawMasks(canvas);
    drawCaptions(canvas, size);
  }

  void drawRects(Canvas canvas) {
    for (var rect in rects) {
      canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void drawMasks(Canvas canvas) {
    for (var i = 0; i < rects.length; i++) {
      canvas.drawImage(masks[i], rects[i].topLeft, Paint());
    }
  }

  void drawCaptions(Canvas canvas, Size size) {
    for (var i = 0; i < rects.length; i++) {
      var builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 50));
      builder.addText(
          '${classNames[classIDs[i]]} ${scores[i].toStringAsFixed(2)}');
      canvas.drawParagraph(
          builder.build()..layout(ui.ParagraphConstraints(width: size.width)),
          rects[i].topLeft);
    }
  }

  @override
  bool shouldRepaint(covariant PredictionPainter oldDelegate) {
    return !listEquals(this.boxes, oldDelegate.boxes);
  }
}

class RawPage extends StatelessWidget {
  const RawPage(this.image, {Key? key}) : super(key: key);
  final PredictionImage? image;

  @override
  Widget build(BuildContext context) {
    return image != null && image!.prediction != null
        ? InteractiveViewer(
            child: Container(
              child: Center(
                child: FittedBox(
                  child: SizedBox(
                    width: image!.width.toDouble(),
                    height: image!.height.toDouble(),
                    child: CustomPaint(
                      foregroundPainter: PredictionPainter(image!.prediction!),
                      child: image!.imageWidget(),
                    ),
                  ),
                ),
              ),
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 100,
                color: Colors.grey,
              ),
              Text(
                'Take image first',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          );
  }
}
