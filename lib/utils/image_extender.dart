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

  ImageExtender.from(ImageExtender imageExtender)
      : image = imageExtender.image,
        path = imageExtender.path;

  List get imageList {
    return image
        .getBytes(format: ImagePackage.Format.rgb)
        .reshape([image.height, image.width, 3]);
  }

  int get height => image.height;

  int get width => image.width;

  get encodeJpg {
    return ImagePackage.encodeJpg(image);
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

  save(path, [refreshPath = true]) async {
    await File(path).writeAsBytes(encodeJpg);
    if (refreshPath) {
      this.path = path;
    }
    return path;
  }

  saveToTempDir(path) async {
    return await save((await getTemporaryDirectory()).path + '/' + path);
  }

  saveToDownloadDir(path) async {
    return await save('/storage/emulated/0/Download/$path', false);
  }

  addPadding(padding) {
    return utils.addPadding(imageList, padding);
  }

  rotateList(angle) {
    assert(angle == 90 || angle == -90 || angle == 180);

    int newH, newW;
    if (angle == 180) {
      newH = imageList.shape[0];
      newW = imageList.shape[1];
    } else {
      newW = imageList.shape[0];
      newH = imageList.shape[1];
    }

    List output = List.generate(
        newH, (e) => List.generate(newW, (e) => List.filled(3, 0)));

    for (var i = 0; i < newH; i++) {
      for (var j = 0; j < newW; j++) {
        for (var k = 0; k < 3; k++) {
          switch (angle) {
            case -90:
              output[newW - 1 - j][i][k] = imageList[i][j][k];
              break;
            case 90:
              output[j][newH - 1 - i][k] = imageList[i][j][k];
              break;
            case 180:
              output[newH - 1 - i][newW - 1 - j][k] = imageList[i][j][k];
              break;
          }
        }
      }
    }

    return output;
  }
}
