import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/annotation/Annotation.dart';
import 'package:flutter_app/mrcnn/configs.dart';
import 'package:flutter_app/pages/annotation_page/painters/PolygonPainter.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Magnifier.dart';

class AnnotationPage extends StatefulWidget {
  const AnnotationPage({Key? key, required this.image}) : super(key: key);

  final PredictionImage image;

  @override
  _AnnotationPageState createState() => _AnnotationPageState();
}

class _AnnotationPageState extends State<AnnotationPage> {
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
                  child: widget.image.imageWidget(key: _imageKey)),
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
    print('onDoubleTapDown');
    setState(() {
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
    });
  }

  void onDoubleTap() {
    print('doubleTap');
    setState(() {
      var index = touchIndex;
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

      var polygonIndex = touchPolygon;
      if (polygonIndex != null) {
        setState(() {
          _currentAnnotationIndex = polygonIndex;
        });
      }
    });
  }

  void onLongPressDown(LongPressDownDetails details) {
    print('onLongPressDown');
    setState(() {
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
    });
  }

  void onLongPressStart(LongPressStartDetails details) async {
    print('longPress');
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
      if (_selectedPoint == null) {
        _selectedPoint = Position(
            _currentAnnotationIndex, _currentAnnotation.polygon.length);
        _currentAnnotation.polygon.add(_cursor!);
      }
    });
  }

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

  void onLongPressUp() {
    print('long press up');
    setState(() {
      magnifierEnabled = false;
      _selectedPoint = null;
    });
  }

  void onAddInstance() {
    addNewAnnotationDialog();
  }

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
    var scaleX =
        widget.image.size.width / _imageKey.currentContext!.size!.width;
    var scaleY =
        widget.image.size.height / _imageKey.currentContext!.size!.height;
    Navigator.pop(
        context,
        List<Annotation>.generate(
            annotations.length,
            (index) => Annotation(annotations[index].categoryId,
                annotations[index].scalePolygon(scaleX, scaleY))));
  }

  void onCancel() {
    Navigator.pop(context);
  }

  Future<bool> addNewAnnotationDialog() async {
    int categoryId = 0;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    late List<String> classNames;
    switch (prefs.getString('modelType') ?? 'parts') {
      case 'parts':
        classNames = CarPartsConfig.CLASS_NAMES;
        break;
      case 'damage':
        classNames = CarDamageConfig.CLASS_NAMES;
        break;
      default:
    }
    classNames = classNames.skip(1).toList();

    if (classNames.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${classNames[0]}. Start annotating')));
      setState(() {
        _currentAnnotationIndex = annotations.length;
      });
      annotations.add(Annotation(categoryId + 1, Polygon([])));
      return true;
    }
    var result = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: const Text('New annotation'),
              content: DropdownButton<int>(
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
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, categoryId),
                    child: Text('Add'))
              ],
            );
          });
        });
    if (result != null) {
      setState(() {
        _currentAnnotationIndex = annotations.length;
      });
      annotations.add(Annotation(categoryId + 1, Polygon([])));
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
}
