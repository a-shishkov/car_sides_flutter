import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/pages/polygon_page/Magnifier.dart';
import 'package:flutter_app/pages/polygon_page/painters/AnnotationPainter.dart';
import 'package:flutter_app/pages/polygon_page/painters/MyCustomPainter.dart';
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
  List<Offset> _points = [Offset(50, 70), Offset(100, 120), Offset(150, 170)];
  // List<Color> colors = [Colors.orange, Colors.pink, Colors.redAccent];

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
  Offset? _localCursor;

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
            child: Magnifier(
                scale: 5,
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: onPanEnd,
                child: CustomPaint(
                  child: Image.file(widget.imageFile),
                  foregroundPainter: MyCustomPainter(_points, _selectedPoint),
                ))),
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
  void onPanStart(DragStartDetails details) async {
    _cursor = details.localPosition;
    // print('onPanStart, $_cursor');
    for (var i = 0; i < _points.length; i++) {
      if (pow(_points[i].dx - _cursor!.dx, 2) +
              pow(_points[i].dy - _cursor!.dy, 2) <
          pow(10, 2)) {
        _selectedPoint = i;
        print('touching ${_points[i]}');
      }
    }
  }

  void onPanUpdate(DragUpdateDetails details) {
    _cursor = details.localPosition;
    if (_selectedPoint != null) {
      setState(() {
        _points[_selectedPoint!] += details.delta;
      });
    }
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
