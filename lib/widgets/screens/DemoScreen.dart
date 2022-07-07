import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:image/image.dart' as image_package;

import '../../main.dart';
import '../CameraPlain.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({required this.onTakePicture, Key? key}) : super(key: key);

  final Function(image_package.Image image, String imagePath, {bool isAsset})
      onTakePicture;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  late PageController pageController;
  late int selectedImage;
  List imageItems = prefs.getStringList('testImagesList') ?? [];

  @override
  void initState() {
    selectedImage = prefs.getInt('selectedImage') ?? 0;
    pageController = PageController(initialPage: selectedImage);
    super.initState();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.bottomCenter, children: [
      Container(
        child: Stack(alignment: Alignment.center, children: [
          // Swipeable gallery of all asset images
          PhotoViewGallery.builder(
              pageController: pageController,
              onPageChanged: pageChanged,
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

  void pageChanged(int index) {
    selectedImage = index;
    prefs.setInt('selectedImage', selectedImage);
  }

  // Send selected image to server
  void takePicture() async {
    var path = 'assets/images/${imageItems[selectedImage]}';
    final byteData = await rootBundle.load(path);

    var image_data = Uint8List.view(byteData.buffer);
    var image = image_package.decodeImage(image_data)!;

    widget.onTakePicture(image, path, isAsset: true);
  }
}
