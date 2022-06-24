import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'PaintModel.dart';

class PredictionModel {
  static get class_names => {
        1: "person",
        2: "bicycle",
        3: "car",
        4: "motorcycle",
        5: "airplane",
        6: "bus",
        7: "train",
        8: "truck",
        9: "boat",
        10: "traffic light",
        11: "fire hydrant",
        13: "stop sign",
        14: "parking meter",
        15: "bench",
        16: "bird",
        17: "cat",
        18: "dog",
        19: "horse",
        20: "sheep",
        21: "cow",
        22: "elephant",
        23: "bear",
        24: "zebra",
        25: "giraffe",
        27: "backpack",
        28: "umbrella",
        31: "handbag",
        32: "tie",
        33: "suitcase",
        34: "frisbee",
        35: "skis",
        36: "snowboard",
        37: "sports ball",
        38: "kite",
        39: "baseball bat",
        40: "baseball glove",
        41: "skateboard",
        42: "surfboard",
        43: "tennis racket",
        44: "bottle",
        46: "wine glass",
        47: "cup",
        48: "fork",
        49: "knife",
        50: "spoon",
        51: "bowl",
        52: "banana",
        53: "apple",
        54: "sandwich",
        55: "orange",
        56: "broccoli",
        57: "carrot",
        58: "hot dog",
        59: "pizza",
        60: "donut",
        61: "cake",
        62: "chair",
        63: "couch",
        64: "potted plant",
        65: "bed",
        67: "dining table",
        70: "toilet",
        72: "tv",
        73: "laptop",
        74: "mouse",
        75: "remote",
        76: "keyboard",
        77: "cell phone",
        78: "microwave",
        79: "oven",
        80: "toaster",
        81: "sink",
        82: "refrigerator",
        84: "book",
        85: "clock",
        86: "vase",
        87: "scissors",
        89: "hair drier",
        90: "toothbrush",
      };

  final List boxes;
  List? masks;
  final List classes;
  final List scores;
  final int width;
  final int height;
  final String imagePath;
  final bool isAsset;

  PredictionModel(
    this.boxes,
    this.classes,
    this.scores,
    this.width,
    this.height,
    this.imagePath,
    this.isAsset, [
    this.masks,
  ]);

  PredictionModel.fromMap(Map map, this.imagePath, this.isAsset)
      : this.width = map['width'],
        this.height = map['height'],
        this.boxes = map['detection_boxes'],
        this.classes = map['detection_classes'],
        this.scores = map['detection_scores']
  // this.masks = map['detection_masks_reframed']
  // Code below is for np.packbits data
  {
    if (!map.containsKey('detection_masks_reframed')) return;

    var new_masks = [];
    for (var mask in map['detection_masks_reframed']) {
      var decoded = base64.decode(mask);

      var bool_mask = [];
      for (var byte in decoded) {
        for (var bit = 0; bit < 8; bit++) {
          bool_mask.add((byte >> (7 - bit) & 1) == 1);
        }
      }
      new_masks.add(bool_mask);
    }
    this.masks = new_masks;
  }

  // Convert mask list to ui.Image
  getMaskImage(mask,
      {color = const ui.Color.fromARGB(100, 255, 255, 255)}) async {
    List<int> pixels = [];
    for (var pixel in mask) {
      List<int> pixelColor = [
        (color.red * color.opacity).toInt(),
        (color.green * color.opacity).toInt(),
        (color.blue * color.opacity).toInt(),
        color.alpha
      ];
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

  // Function to filter instances by threshold and convert masks from list to ui.Image
  Future<List<PaintModel>> paint(
      {color = const ui.Color.fromARGB(100, 255, 255, 255),
      threshold = 0.3}) async {
    List<PaintModel> passed_detections = [];
    for (var i = 0; i < boxes.length; i++) {
      var score = scores[i];

      if (score >= threshold) {
        var classID = classes[i];
        var box = boxes[i];

        var paintModel = PaintModel(box, score, classID);
        if (masks != null) {
          var mask = masks![i];
          paintModel.mask = await getMaskImage(mask, color: color);
        }

        passed_detections.add(paintModel);
      }
    }

    return passed_detections;
  }
}
