import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/models/PredictionModel.dart';

import '../../models/AnnotationModel.dart';
import '../../models/PolygonModel.dart';
import '../../models/PositionModel.dart';
import '../../models/enums/ModelType.dart';
import '../Magnifier.dart';
import '../painters/PolygonPainter.dart';

// AnnotationScreen is a widget to create annotations directly in flutter and
// send them to server for storing
class AnnotationScreen extends StatefulWidget {
  const AnnotationScreen({
    this.image,
    this.imagePath,
    this.isAsset = false,
    required this.size,
    Key? key,
  }) : super(key: key);

  final XFile? image;
  final String? imagePath;
  final bool isAsset;
  final Size size;

  @override
  _AnnotationScreenState createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  /* List<Offset> _points = [
    Offset(42.7, 120.4),
    Offset(58.0, 95.7),
    Offset(73.3, 69.1),
    Offset(93.3, 63.7),
    Offset(110.0, 61.1),
    Offset(129.3, 65.7),
    Offset(149.3, 68.4),
    Offset(168.7, 68.4),
    Offset(184.0, 79.1),
    Offset(198.7, 88.4),
    Offset(215.3, 96.4),
    Offset(232.7, 99.1),
    Offset(246.7, 106.4),
    Offset(259.3, 113.7),
    Offset(262.0, 135.0),
    Offset(254.0, 153.7),
    Offset(239.3, 165.7),
    Offset(222.0, 171.0),
    Offset(205.3, 160.4),
    Offset(184.0, 165.1),
    Offset(162.0, 165.7),
    Offset(154.7, 177.0),
    Offset(137.3, 179.1),
    Offset(119.3, 161.7),
    Offset(91.3, 151.7),
    Offset(68.0, 149.1),
    Offset(59.3, 162.4),
    Offset(44.7, 149.7)
  ]; */
  List<Annotation> annotations = [];

  bool magnifierEnabled = false;

  Position? _selectedPoint;

  ModelType modelType = ModelType.parts;

  List<String> get classNames => PredictionModel.classes;

  Annotation get _currentAnnotation => annotations[_currentAnnotationIndex];
  int _currentAnnotationIndex = -1;

  double pointRadius = 2;
  double pointExtraReact = 3;

  Offset? _cursor;
  Offset? _globalCursor;

  GlobalKey _imageKey = GlobalKey();

  ButtonStyle get buttonStyle => ButtonStyle(
      foregroundColor: MaterialStateProperty.all<Color>(Colors.white));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black45,
        title: const Text('Annotation page'),
        actions: [
          IconButton(
              onPressed: showTutorial,
              tooltip: 'Tutorial',
              icon: Icon(Icons.help))
        ],
      ),
      // Use magnifier as parent
      body: Magnifier(
        cursor: _globalCursor,
        enabled: magnifierEnabled,
        child: InteractiveViewer(
          maxScale: 10,
          child: Center(
            child: GestureDetector(
              onDoubleTapDown: onDoubleTapDown,
              onDoubleTap: onDoubleTap,
              onLongPressDown: onLongPressDown,
              onLongPressStart: onLongPressStart,
              onLongPressMoveUpdate: onLongPressMoveUpdate,
              onLongPressUp: onLongPressUp,
              child: CustomPaint(
                  foregroundPainter: PolygonPainter(annotations,
                      _currentAnnotationIndex, _selectedPoint, pointRadius),
                  child: image(_imageKey)),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              label: Text('Add'),
              icon: Icon(Icons.add),
              onPressed: onAddInstance,
              style: buttonStyle,
            ),
            Row(
              children: [
                TextButton.icon(
                  label: Text('Confirm'),
                  icon: Icon(Icons.check),
                  onPressed: onConfirm,
                  style: buttonStyle,
                ),
                TextButton.icon(
                  label: Text('Cancel'),
                  icon: Icon(Icons.close),
                  onPressed: onCancel,
                  style: buttonStyle,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Check if cursor is on point in raduis
  Position? get touchIndex {
    if (_cursor != null) {
      for (var i = 0; i < annotations.length; i++) {
        for (var j = 0; j < annotations[i].polygon.length; j++) {
          var point = annotations[i].polygon[j];
          if (pow(point.dx - _cursor!.dx, 2) + pow(point.dy - _cursor!.dy, 2) <
              pow(pointRadius + pointExtraReact, 2)) {
            print('touching $point');
            return Position(i, j);
          }
        }
      }
    }
    return null;
  }

  // Check if curser is in polygon
  int? get touchPolygon {
    if (_cursor != null) {
      for (var i = 0; i < annotations.length; i++) {
        var segmentation = annotations[i].polygon;
        if (segmentation.isPointInside(_cursor!)) {
          return i;
        }
      }
    }
    return null;
  }

  void onDoubleTapDown(TapDownDetails details) {
    setState(() {
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
    });
  }

  void onDoubleTap() {
    setState(() {
      var index = touchIndex;
      // Delete point under cursor
      if (index != null && index.row == _currentAnnotationIndex) {
        annotations[index.row].polygon.removeAt(index.column);
        if (annotations[index.row].polygon.length <= 0) {
          annotations.removeAt(index.row);
        }
        _selectedPoint = null;
        return;
      }

      print('${_currentAnnotation.polygon.length}');
      if (_currentAnnotation.polygon.length < 3) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: const Text('Add 3 point atleast')));
        return;
      }

      // Change active polygon
      var polygonIndex = touchPolygon;
      if (polygonIndex != null) {
        setState(() {
          _currentAnnotationIndex = polygonIndex;
        });
      }
    });
  }

  void onLongPressDown(LongPressDownDetails details) {
    setState(() {
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
    });
  }

  // onLognPress add new point
  void onLongPressStart(LongPressStartDetails details) async {
    // if no annotation(polygon) created ask user to create new
    if (_currentAnnotationIndex == -1) {
      if (!await addNewAnnotationDialog()) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Add new annotation first')));
        return;
      }
    }

    setState(() {
      magnifierEnabled = true;
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
      _selectedPoint = touchIndex;
      // If cursor is not on the point then create new
      if (_selectedPoint == null) {
        _selectedPoint = Position(
            _currentAnnotationIndex, _currentAnnotation.polygon.length);
        _currentAnnotation.polygon.add(_cursor!);
      }
    });
  }

  // Update the location of point
  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    setState(() {
      if (_selectedPoint != null) {
        _cursor = details.localPosition;
        _globalCursor = details.globalPosition;
        annotations[_selectedPoint!.row].polygon[_selectedPoint!.column] =
            _cursor!;
      }
    });
  }

  // Hide magnifier and unselect point
  void onLongPressUp() {
    setState(() {
      magnifierEnabled = false;
      _selectedPoint = null;
    });
  }

  // Add new polygon
  void onAddInstance() {
    if (_currentAnnotation.polygon.length < 3) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: const Text('Add 3 points atleast')));
      return;
    }
    addNewAnnotationDialog();
  }

  // Ask user for confirmation and return list of points
  void onConfirm() {
    if (annotations.length <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Create atleast 1 annotation'),
      ));
      return;
    }

    if (_currentAnnotation.polygon.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Create atleast 3 points'),
      ));
      return;
    }
    var scaleX = widget.size.width / _imageKey.currentContext!.size!.width;
    var scaleY = widget.size.height / _imageKey.currentContext!.size!.height;
    Navigator.pop(
        context,
        annotations
            .map((e) => Annotation(
                e.superCategory, e.categoryId, e.scalePolygon(scaleX, scaleY)))
            .toList());
  }

  // Return null
  void onCancel() {
    Navigator.pop(context);
  }

  // TODO: something wrong with categories
  Future<bool> addNewAnnotationDialog() async {
    int categoryId = 0;

    var result = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: const Text('New annotation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: ListTile(
                          contentPadding: EdgeInsets.only(right: 2),
                          leading: Radio(
                              value: ModelType.parts,
                              groupValue: modelType,
                              onChanged: (ModelType? value) {
                                setState(() {
                                  categoryId = 0;
                                  modelType = value!;
                                });
                              }),
                          title: Text('Parts'),
                        ),
                      ),
                      Flexible(
                        child: ListTile(
                          contentPadding: EdgeInsets.only(left: 2),
                          leading: Radio(
                              value: ModelType.damage,
                              groupValue: modelType,
                              onChanged: (ModelType? value) {
                                setState(() {
                                  categoryId = 0;
                                  modelType = value!;
                                });
                              }),
                          title: Text('Damages'),
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<int>(
                    value: categoryId,
                    onChanged: (int? value) {
                      setState(() {
                        categoryId = value!;
                      });
                    },
                    items: classNames.map((String value) {
                      return DropdownMenuItem(
                        value: classNames.indexOf(value),
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, {
                          'super_category': modelType,
                          'category_id': categoryId
                        }),
                    child: Text('Add'))
              ],
            );
          });
        });

    if (result != null) {
      setState(() {
        _currentAnnotationIndex = annotations.length;
      });
      annotations.add(Annotation(modelType, categoryId + 1, Polygon([])));
      return true;
    }
    return false;
  }

  void showTutorial() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Tutorial'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. You can zoom image'),
                Text('2. Long Press to add new point'),
                Text('3. Double click on point to delete it'),
                Text('4. Add button adds new polygon'),
                Text('5. Double click on polygon to switch between active'),
              ],
            ),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            ],
          );
        });
  }

  Image image(key) {
    if (widget.isAsset) return Image.asset(widget.imagePath!, key: key);

    return Image.file(
        File(
          widget.image!.path,
        ),
        key: key);
  }
}
