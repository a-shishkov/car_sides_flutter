import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_app/annotation/Annotation.dart';
import 'package:flutter_app/mrcnn/utils.dart' as utils;
import 'package:flutter_app/utils/prediction_result.dart';
import 'package:image/image.dart' as ImagePackage;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class ImageExtender {
  ImagePackage.Image image;
  bool isAsset = false;
  String? path;
  List<Annotation>? annotations;
  PredictionResult? prediction;

  List<Map>? get mapAnnotations {
    if (annotations != null)
      return List.generate(
          annotations!.length, (index) => annotations![index].toMap);
    return null;
  }

  ImageExtender.decodeImage(List<int> data)
      : image = ImagePackage.decodeImage(data)!;

  ImageExtender.decodeImageFromPath(String path)
      : image = ImagePackage.decodeImage(File(path).readAsBytesSync())!,
        path = path;

  ImageExtender.fromImage(ImagePackage.Image image) : image = image;

  ImageExtender.fromBytes(int width, int height, List<int> bytes,
      {ImagePackage.Format format = ImagePackage.Format.rgb})
      : image =
            ImagePackage.Image.fromBytes(width, height, bytes, format: format);

  ImageExtender.from(ImageExtender imageExtender)
      : image = imageExtender.image,
        path = imageExtender.path;

  Uint8List get getBytes => image.getBytes(format: ImagePackage.Format.rgb);
  List get imageList {
    return image
        .getBytes(format: ImagePackage.Format.rgb)
        .reshape([image.height, image.width, 3]);
  }

  Size get size => Size(image.width.toDouble(), image.height.toDouble());

  int get height => image.height;

  int get width => image.width;

  get encodeJpg {
    return ImagePackage.encodeJpg(image);
  }

  Widget? imageWidget({Key? key}) => path != null
      ? isAsset
          ? Image.asset(
              path!,
              key: key,
            )
          : Image.file(
              File(path!),
              key: key,
            )
      : null;

  setImage(image) async {
    this.image = image;
    await save(path);
  }

  resize(width, height) {
    image = ImagePackage.copyResize(image,
        width: width,
        height: height,
        interpolation: ImagePackage.Interpolation.cubic);
  }

  rotate(num angle) async {
    image = ImagePackage.copyRotate(image, angle);
    if (path != null) {
      await save(path);
    }
  }

  drawRect(int x1, int y1, int x2, int y2, int color) {
    image = ImagePackage.drawRect(image, x1, y1, x2, y2, color);
  }

  drawString(ImagePackage.BitmapFont font, x, y, String string) {
    image = ImagePackage.drawString(image, font, x, y, string);
  }

  drawImage(ImagePackage.Image src) {
    image = ImagePackage.drawImage(image, src);
  }

  save(path, [refreshPath = true]) async {
    await File(path).writeAsBytes(encodeJpg);
    if (refreshPath) this.path = path;

    return path;
  }

  saveToTempDir(String path) async {
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
