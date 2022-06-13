import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../controllers/PredictionController.dart';
import '../models/PredictionModel.dart';
import '../main.dart';
import '../widgets/CameraPlain.dart';
import 'PredictionScreen.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({Key? key}) : super(key: key);

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

  void takePicture() async {
    var path = 'assets/images/${imageItems[selectedImage]}';
    final byteData = await rootBundle.load(path);

    var image = Uint8List.view(byteData.buffer);
    var prediction = await PredictionController.predict(image);

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PredictionScreen(
              imagePath: path, prediction: prediction, isAsset: true)),
    );
  }
}
