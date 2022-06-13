import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

class PredictionModel {
  final List boxes;
  late List masks;
  final int width;
  final int height;

  PredictionModel.fromMap(Map map)
      : this.width = map['width'],
        this.height = map['height'],
        this.boxes = map['damage']['boxes'],
        this.masks = map['damage']['masks'];
/*         {
    var bool_instances = [];
    for (var instances in map['damage']['masks']) {
      var bool_instance = [];
      for (var instance in instances) {
        var decoded = base64.decode(instance);

        var bool_mask = [];
        for (var byte in decoded) {
          for (var bit = 0; bit < 8; bit++) {
            bool_mask.add((byte >> bit & 1) == 1);
          }
        }
        bool_instance.add(bool_mask);
      }
      bool_instances.add(bool_instance);
    }
    this.masks = bool_instances;
  } */

  getMaskImages() async {
    var maskImages = [];
    for (var class_masks in masks) {
      var classMaskImages = [];
      for (var mask in class_masks) {
        classMaskImages.add(await getMaskImage(mask));
      }
      maskImages.add(classMaskImages);
    }
    return maskImages;
  }

  getMaskImage(mask,
      {color = const ui.Color.fromARGB(178, 255, 255, 255)}) async {
    List<int> pixels = [];
    for (var pixel in mask) {
      List<int> pixelColor = [color.red, color.green, color.blue, color.alpha];
      List<int> transparentColor = [0, 0, 0, 0];
      if (pixel)
        pixels.addAll(pixelColor);
      else
        pixels.addAll(transparentColor);
    }
    Uint8List ui8Pixels = Uint8List.fromList(pixels);

    var uiImage = Completer<ui.Image>();
    ui.decodeImageFromPixels(ui8Pixels, width, height, ui.PixelFormat.rgba8888,
        (result) {
      uiImage.complete(result);
    });
    return uiImage.future;
  }

  Future<Map> paint({threshold = 0.3}) async {
    var passed_boxes = [];
    var passed_masks = [];
    for (var class_i = 0; class_i < boxes.length; class_i++) {
      for (var instance_i = 0;
          instance_i < boxes[class_i].length;
          instance_i++) {
        var box = boxes[class_i][instance_i];
        if (box[4] >= threshold) {
          var mask = masks[class_i][instance_i];
          passed_boxes.add(box);
          passed_masks.add(await getMaskImage(mask));
        }
      }
    }

    return {
      "width": width,
      "height": height,
      "boxes": passed_boxes,
      "masks": passed_masks
    };
  }
}
