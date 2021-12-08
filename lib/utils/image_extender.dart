import 'dart:io';
import 'package:flutter_app/mrcnn/utils.dart' as utils;
import 'package:image/image.dart' as ImagePackage;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class ImageExtender {
  ImagePackage.Image image;
  String? path;

  ImageExtender.decodeImage(List<int> data)
      : image = ImagePackage.decodeImage(data)!;

  ImageExtender.decodeImageFromPath(String path)
      : image = ImagePackage.decodeImage(File(path).readAsBytesSync())!,
        path = path;

  ImageExtender.fromImage(ImagePackage.Image image) : image = image;

  ImageExtender.from(ImageExtender imageExtender) : image = imageExtender.image, path = imageExtender.path;

  List get imageList {
    return image
        .getBytes(format: ImagePackage.Format.rgb)
        .reshape([image.height, image.width, 3]);
  }

  int get height => image.height;

  int get width => image.width;

  get encodePng {
    return ImagePackage.encodePng(image);
  }

  setImage(image) async {
    this.image = image;
    await save(path);
  }

  rotate(num angle) async {
    image = ImagePackage.copyRotate(image, angle);
    if (path != null) {
      await save(path);
    }
  }

  save(path) async {
    await File(path).writeAsBytes(encodePng);
    return this.path = path;
  }

  saveToTempDir(path) async {
    return await save((await getTemporaryDirectory()).path + '/' + path);
  }

  addPadding(padding)
  {
    return utils.addPadding(imageList, padding);
  }
}
