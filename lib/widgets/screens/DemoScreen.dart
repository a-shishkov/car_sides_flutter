import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:image/image.dart' as image_package;

import '../../controllers/DetectionController.dart';
import '../../main.dart';
import '../CameraPlain.dart';
import 'AnnotationScreen.dart';
import 'DetectionScreen.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen(this.inferenceType, {Key? key}) : super(key: key);

  final InferenceType inferenceType;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  PageController pageController = PageController(initialPage: 0);
  int selectedImage = 0;
  List imageItems = prefs.getStringList('testImagesList') ?? [];

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.bottomCenter, children: [
      Container(
        child: Stack(alignment: Alignment.center, children: [
          // Swipeable gallery of all asset images
          PhotoViewGallery.builder(
              pageController: pageController,
              onPageChanged: imagePageChanged,
              itemCount: imageItems.length,
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions(
                    maxScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained,
                    imageProvider:
                        AssetImage('assets/images/${imageItems[index]}'));
              }),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
            )
          ]),
        ]),
      ),
      CameraPlain(
        onTakePicture: takePicture,
      ),
    ]);
  }

  void imagePageChanged(int index) {
    selectedImage = index;
  }

  // Send selected image to server
  void takePicture() async {
    var path = 'assets/images/${imageItems[selectedImage]}';
    final byteData = await rootBundle.load(path);

    var image_data = Uint8List.view(byteData.buffer);
    var image = image_package.decodeImage(image_data)!;

    DetectionController.detect(image, path,
            isAsset: true, type: widget.inferenceType)
        .then((value) => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DetectionScreen(detection: value)),
            ))
        .onError((error, stackTrace) => print("Error: $error"));
  }
}
