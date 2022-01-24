import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/pages/polygon_page/CustomPanGestureRecognizer.dart';
import 'package:flutter_app/pages/polygon_page/Magnifier.dart';
import 'package:flutter_app/pages/polygon_page/painters/annotationPainter.dart';
import 'package:touchable/touchable.dart';

class PolygonPage extends StatefulWidget {
  const PolygonPage({Key? key, required this.imagePath}) : super(key: key);

  final String imagePath;

  @override
  _PolygonPageState createState() => _PolygonPageState();
}

class _PolygonPageState extends State<PolygonPage> {
  Offset _cursorLocal = Offset(-1, -1);
  Offset _cursorGlobal = Offset(-1, -1);
  GlobalKey _imageKey = GlobalKey();

  List<Offset> offsets = [];
  late Future<ui.Image> futureImage;
  ui.Image? image;

  ButtonStyle get buttonStyle => ButtonStyle(
      foregroundColor: MaterialStateProperty.all<Color>(Colors.white));

  @override
  void initState() {
    futureImage = decodeImageFromList(File(widget.imagePath).readAsBytesSync())
        .then((value) => image = value);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polygon page'),
      ),
      body: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          CustomPanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<CustomPanGestureRecognizer>(
                  () => CustomPanGestureRecognizer(
                      onPanDown: (Offset details) {
                        print('onPannDownn;');
                      },
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: (Offset details) {
                        print('onPannEnnd;');
                      }),
                  (CustomPanGestureRecognizer instance) {})
        },
        child: Container(
          color: Colors.black,
          child: Center(
            child: FutureBuilder<ui.Image>(
              future: futureImage,
              builder:
                  (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  var image = snapshot.data!;
                  return Magnifier(
                    type: MagnifierType.topLeft,
                    cursorLocal: _cursorLocal,
                    cursorGlobal: _cursorGlobal,
                    child: FittedBox(
                      child: SizedBox(
                        width: image.width.toDouble(),
                        height: image.height.toDouble(),
                        child: CanvasTouchDetector(builder: (context) {
                          return CustomPaint(
                              key: _imageKey,
                              foregroundPainter:
                                  AnnotationPainter(context, image, offsets));
                        }),
                      ),
                    ),
                  );
                } else if (snapshot.connectionState == ConnectionState.active) {
                  return Text('active');
                }
                return Text('3');
              },
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

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _cursorLocal = details.localPosition;
      _cursorGlobal = details.globalPosition;
      print('_cursorLocal $_cursorLocal _cursorGlobal $_cursorGlobal');
    });
  }

  void addPoint() {
    RenderBox box = _imageKey.currentContext!.findRenderObject() as RenderBox;

    setState(() {
      if (_cursorLocal.dx >= 0 &&
          _cursorLocal.dx < box.size.width &&
          _cursorLocal.dy >= 0 &&
          _cursorLocal.dy < box.size.height) {
        print('addPoint');
        late Offset point;
        if (image != null) {
          point = _cursorLocal.scale(
              image!.width / box.size.width, image!.height / box.size.height);
        } else {
          futureImage.then((value) => point = _cursorLocal.scale(
              image!.width / box.size.width, image!.height / box.size.height));
        }
        offsets.add(point);
      }
    });
  }
}
