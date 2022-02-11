import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_app/annotation/Annotation.dart';
import 'package:flutter_app/mrcnn/utils.dart' as utils;
import 'package:flutter_app/utils/prediction_result.dart';
import 'package:image/image.dart' as image_package;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class PredictionImage {
  image_package.Image image;
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

  PredictionImage.decodeImage(List<int> data)
      : image = image_package.decodeImage(data)!;

  PredictionImage.decodeImageFromPath(String path)
      : image = image_package.decodeImage(File(path).readAsBytesSync())!,
        path = path;

  PredictionImage.fromImage(image_package.Image image) : image = image;

  PredictionImage.fromBytes(int width, int height, List<int> bytes,
      {image_package.Format format = image_package.Format.rgb})
      : image =
            image_package.Image.fromBytes(width, height, bytes, format: format);

  PredictionImage.from(PredictionImage imageExtender)
      : image = imageExtender.image,
        path = imageExtender.path;

  Uint8List getBytes({format = image_package.Format.rgb}) {
    return image.getBytes(format: format);
  }

  List get imageList {
    return image
        .getBytes(format: image_package.Format.rgb)
        .reshape([image.height, image.width, 3]);
  }

  Size get size => Size(image.width.toDouble(), image.height.toDouble());

  int get height => image.height;

  int get width => image.width;

  List<int> get encodeJpg => image_package.encodeJpg(image);

  List<int> get encodePng => image_package.encodePng(image);

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
    image = image_package.copyResize(image,
        width: width,
        height: height,
        interpolation: image_package.Interpolation.cubic);
  }

  rotate(num angle) async {
    image = image_package.copyRotate(image, angle);
    if (path != null) {
      await save(path);
    }
  }

  drawRect(int x1, int y1, int x2, int y2, int color) {
    image = image_package.drawRect(image, x1, y1, x2, y2, color);
  }

  drawString(image_package.BitmapFont font, x, y, String string) {
    image = image_package.drawString(image, font, x, y, string);
  }

  drawImage(image_package.Image src) {
    image = image_package.drawImage(image, src);
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
