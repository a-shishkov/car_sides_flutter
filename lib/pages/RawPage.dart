import 'package:flutter/material.dart';
import 'package:flutter_app/utils/PredictionImage.dart';
import '../main.dart';
import 'dart:ui' as ui;
import 'package:touchable/touchable.dart';

class PredictionPainter extends CustomPainter {
  PredictionPainter(
      this.context, this.predictions, this.showParts, this.showDamages);

  final BuildContext context;
  final Map<ModelType, PredictionResult> predictions;
  final bool showParts;
  final bool showDamages;

  List<Rect> getRects(ModelType model) {
    var boxes = predictions[model]!.boxes;
    return List.generate(
        boxes.length,
        (i) => Rect.fromLTRB(boxes[i][1].toDouble(), boxes[i][0].toDouble(),
            boxes[i][3].toDouble(), boxes[i][2].toDouble()));
  }

  @override
  void paint(Canvas canvas, Size size) async {
    // var myCanvas = TouchyCanvas(context, canvas);

    if (showParts) {
      drawMasks(canvas, ModelType.parts);
      // drawRects(canvas, ModelType.parts);
    }
    if (showDamages) {
      drawMasks(canvas, ModelType.damage);
      drawRects(canvas, ModelType.damage);
    }
  }

  void drawRects(Canvas canvas, ModelType model) {
    for (var rect in getRects(model)) {
      canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void drawMasks(Canvas canvas, ModelType model) {
    var rects = getRects(model);
    for (var i = 0; i < rects.length; i++) {
      var mask = predictions[model]!.masks[i];
      canvas.drawImage(mask, rects[i].topLeft, Paint());
    }
  }

  void drawCaptions(Canvas canvas, Size size, ModelType model) {
    var rects = getRects(model);
    for (var i = 0; i < rects.length; i++) {
      var className =
          predictions[model]!.classNames[predictions[model]!.classIDs[i]];
      var score = predictions[model]!.scores[i].toStringAsFixed(2);
      var builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 50));
      builder.addText('$className $score');
      canvas.drawParagraph(
          builder.build()..layout(ui.ParagraphConstraints(width: size.width)),
          rects[i].topLeft);
    }
  }

  @override
  bool shouldRepaint(covariant PredictionPainter oldDelegate) {
    // return !listEquals(this.boxes, oldDelegate.boxes);
    return true;
  }
}

class RawPage extends StatefulWidget {
  final PredictionImage? image;
  final bool showParts;
  final bool showDamages;

  const RawPage(
      {this.image,
      required this.showParts,
      required this.showDamages,
      Key? key})
      : super(key: key);

  @override
  _RawPageState createState() => _RawPageState();
}

class _RawPageState extends State<RawPage> {
  PredictionImage? get image => widget.image;

  bool _pagingEnabled = true;
  final TransformationController _transformationController =
      TransformationController();

  @override
  Widget build(BuildContext context) {
    return image != null && image!.predictions.isNotEmpty
        ? TabBarView(
            physics: _pagingEnabled
                ? PageScrollPhysics()
                : NeverScrollableScrollPhysics(),
            children: [
              InteractiveViewer(
                transformationController: _transformationController,
                onInteractionStart: (details) {
                  print('onInteractionStart');
                },
                onInteractionEnd: (details) {
                  print('onInteractonEnd');
                  setState(() {
                    _pagingEnabled =
                        _transformationController.value.getMaxScaleOnAxis() <=
                            1;
                  });
                },
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: FittedBox(
                      child: SizedBox(
                        width: image!.width.toDouble(),
                        height: image!.height.toDouble(),
                        child: GestureDetector(
                          onTapUp: (details) {
                            var modelType = ModelType.damage;
                            var point = details.localPosition;
                            var boxes = image!.predictions[modelType]!.boxes;
                            for (var i = 0; i < boxes.length; i++) {
                              var box = boxes[i];
                              var x1 = box[1];
                              var x2 = box[3];
                              var y1 = box[0];
                              var y2 = box[2];
                              if (x1 <= point.dx &&
                                  point.dx <= x2 &&
                                  y1 <= point.dy &&
                                  point.dy <= y2) {
                                var damages = [];
                                for (var j = 0;
                                    j < image!.intersections.length;
                                    j++) {
                                  var intersection = image!.intersections[j];
                                  var partsPredictions =
                                      image!.predictions[ModelType.parts]!;
                                  if (intersection.contains(i)) {
                                    damages.add(partsPredictions.classNames[
                                        partsPredictions.classIDs[j]]);
                                  }
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Damage on $damages')));
                              }
                            }
                          },
                          child: CustomPaint(
                            foregroundPainter: PredictionPainter(
                                context,
                                image!.predictions,
                                widget.showParts,
                                widget.showDamages),
                            child: image!.imageWidget(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ListView.builder(
                  itemCount: image!.intersections.length,
                  itemBuilder: (context, index) {
                    var className = image!
                            .predictions[ModelType.parts]!.classNames[
                        image!.predictions[ModelType.parts]!.classIDs[index]];
                    className =
                        className[0].toUpperCase() + className.substring(1);
                    var damageCount = image!.intersections[index].length;
                    var suffix = damageCount == 1 ? 'damage' : 'damages';
                    return ListTile(
                      title: Text(className),
                      trailing: Text('$damageCount $suffix'),
                    );
                  })
            ],
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
