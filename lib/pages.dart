import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

Widget cameraPage(getImageRunning, controller, originalImagePath) {
  return Container(
      color: Colors.black,
      child: !getImageRunning && controller.value.isInitialized
          ? CameraPreview(controller)
          : originalImagePath == null
          ? Center(child: CircularProgressIndicator())
          : Image.file(File(originalImagePath!)));
}

Widget mrcnnPage(newImagePath) {
  return Container(
      child: (newImagePath == null
          ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 100,
          ),
          Text('Take a picture first'),
        ],
      )
          : Image.file(File(newImagePath!))));
}