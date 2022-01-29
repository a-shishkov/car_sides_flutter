import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/pages/polygon_page/Magnifier.dart';
import 'package:flutter_app/pages/polygon_page/painters/AnnotationPainter.dart';
import 'package:flutter_app/pages/polygon_page/painters/MyCustomPainter.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:touchable/touchable.dart';
import 'painters/AnnotationController.dart';

class PolygonPage extends StatefulWidget {
  const PolygonPage({Key? key, required this.imageFile}) : super(key: key);

  final File imageFile;

  @override
  _PolygonPageState createState() => _PolygonPageState();
}

class _PolygonPageState extends State<PolygonPage> {
  List<Offset> _points = [
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
  ];

  double pointRadius = 5;

  List<Widget> get pointContainers {
    return List.generate(_points.length, (index) {
      double size = 20;
      return Positioned(
        top: _points[index].dy - size / 2,
        left: _points[index].dx - size / 2,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: Colors.pink, shape: BoxShape.circle),
        ),
      );
    });
  }

  Offset? _cursor;
  Offset? _globalCursor;

  ButtonStyle get buttonStyle => ButtonStyle(
      foregroundColor: MaterialStateProperty.all<Color>(Colors.white));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polygon page'),
      ),
      body: Container(
        color: Colors.black,
        child: Center(
            child: GestureDetector(
          dragStartBehavior: DragStartBehavior.down,
          onTapDown: onTapDown,
          onTapUp: onTapUp,
          onDoubleTapDown: onDoubleTapDown,
          onDoubleTap: onDoubleTap,
          onLongPressStart: onLongPressStart,
          onLongPressMoveUpdate: onLongPressMoveUpdate,
          onLongPressUp: onLongPressUp,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: Magnifier(
              cursor: _globalCursor,
              scale: 2,
              child: CustomPaint(
                child: Image.file(widget.imageFile),
                foregroundPainter:
                    MyCustomPainter(_points, _selectedPoint, pointRadius),
              )),
        )),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              label: Text('Add point'),
              icon: Icon(Icons.add),
              onPressed: addPoint,
              style: buttonStyle,
            ),
            TextButton.icon(
              label: Text('Add polygon'),
              icon: Icon(Icons.add),
              onPressed: () => print('press2'),
              style: buttonStyle,
            )
          ],
        ),
      ),
    );
  }

  int? _selectedPoint;

  int? get touchIndex {
    if (_cursor != null) {
      for (var i = 0; i < _points.length; i++) {
        if (pow(_points[i].dx - _cursor!.dx, 2) +
                pow(_points[i].dy - _cursor!.dy, 2) <
            pow(pointRadius, 2)) {
          print('touching ${_points[i]}');
          return i;
        }
      }
    }
  }

  void onTapDown(TapDownDetails details) {
    setState(() {
      print('onTapDown');
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
    });
  }

  void onTapUp(TapUpDetails details) {
    print('onTapUp');
    setState(() {
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
      if (touchIndex == null) {
        _points.add(_cursor!);
      }
    });
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
      if (index != null) {
        _points.removeAt(index);
        _selectedPoint = null;
      }
    });
  }

  void onLongPressStart(LongPressStartDetails details) {
    print('longPress');
    setState(() {
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
      _selectedPoint = touchIndex;
      print('index $_selectedPoint');
      if (_selectedPoint == null) {
        _selectedPoint = _points.length;
        _points.add(_cursor!);
      }
    });
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    setState(() {
      if (_selectedPoint != null) {
        _cursor = details.localPosition;
        _globalCursor = details.globalPosition;
        _points[_selectedPoint!] = _cursor!;
      }
    });
  }

  void onLongPressUp() {
    print('long press up');
    setState(() {
      _selectedPoint = null;
    });
  }

  void onPanStart(DragStartDetails details) {
    print('onPanStart');
    setState(() {
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
    });
    _selectedPoint = touchIndex;
  }

  void onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _cursor = details.localPosition;
      _globalCursor = details.globalPosition;
      if (_selectedPoint != null) {
        _points[_selectedPoint!] = _cursor!;
      }
    });
  }

  void onPanEnd(DragEndDetails details) {
    setState(() {
      _selectedPoint = null;
    });
  }

  void addPoint() {
    setState(() {
      _points.add(_cursor!);
    });
  }
}
