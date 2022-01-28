import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_app/pages/polygon_page/Magnifier.dart';
import 'package:flutter_app/pages/polygon_page/painters/AnnotationPainter.dart';
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
  List<Offset> _points = [];
  Offset? _cursor;

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
          child: ChangeNotifierProvider<AnnotationController>(
            create: (context) =>
                AnnotationController(_points, (Offset position) {
              setState(() {
                _cursor = position;
              });
            }),
            child: Consumer<AnnotationController>(
              builder: (context, controller, child) => Magnifier(
                cursor: controller.cursor,
                child: CanvasTouchDetector(builder: (context) {
                  return CustomPaint(
                      child: Image.file(widget.imageFile),
                      foregroundPainter: AnnotationPainter(context, controller.points));
                }),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              label: Text('Add point'),
              icon: Icon(Icons.add),
              onPressed: _cursor == null ? null : addPoint,
              style: _cursor == null ? null : buttonStyle,
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

  void addPoint() {
    setState(() {
      _points.add(_cursor!);
    });
  }
}
