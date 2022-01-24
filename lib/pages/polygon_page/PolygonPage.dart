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
  Offset _cursor = Offset(-1, -1);
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
                      onPanDown: _onPanDown, onPanUpdate: _onPanUpdate),
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
                    type: MagnifierType.topRight,
                    scale: 5,
                    cursor: _cursor,
                    child: FittedBox(
                      key: _imageKey,
                      child: SizedBox(
                        width: image.width.toDouble(),
                        height: image.height.toDouble(),
                        child: CanvasTouchDetector(builder: (context) {
                          return CustomPaint(
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

  void _onPanDown(Offset position) {
    setState(() {
      _cursor = position;
    });
  }

  void _onPanUpdate(Offset position) {
    setState(() {
      _cursor = position;
    });
  }

  void addPoint() {
    RenderBox box = _imageKey.currentContext!.findRenderObject() as RenderBox;
    Offset offset = box.localToGlobal(Offset.zero);
    var localPoint = _cursor - offset;
    setState(() {
      if (localPoint.dx >= 0 &&
          localPoint.dx < box.size.width &&
          localPoint.dy >= 0 &&
          localPoint.dy < box.size.height) {
        print('addPoint');
        late Offset point;
        if (image != null) {
          point = localPoint.scale(image!.width.toDouble() / box.size.width,
              image!.height.toDouble() / box.size.height);
        } else {
          futureImage.then((value) => point = localPoint.scale(
              image!.width / box.size.width, image!.height / box.size.height));
        }
        offsets.add(point);
      }
    });
  }
}
