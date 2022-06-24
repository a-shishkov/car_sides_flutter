import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

class PredictionModel {
  final List boxes;
  final List classes;
  final List scores;
  late List? masks;
  final int width;
  final int height;
  final String imagePath;

  static get class_names => [
        '__background__',
        'person',
        'bicycle',
        'car',
        'motorcycle',
        'airplane',
        'bus',
        'train',
        'truck',
        'boat',
        'traffic light',
        'fire hydrant',
        'stop sign',
        'parking meter',
        'bench',
        'bird',
        'cat',
        'dog',
        'horse',
        'sheep',
        'cow',
        'elephant',
        'bear',
        'zebra',
        'giraffe',
        'backpack',
        'umbrella',
        'handbag',
        'tie',
        'suitcase',
        'frisbee',
        'skis',
        'snowboard',
        'sports ball',
        'kite',
        'baseball bat',
        'baseball glove',
        'skateboard',
        'surfboard',
        'tennis racket',
        'bottle',
        'wine glass',
        'cup',
        'fork',
        'knife',
        'spoon',
        'bowl',
        'banana',
        'apple',
        'sandwich',
        'orange',
        'broccoli',
        'carrot',
        'hot dog',
        'pizza',
        'donut',
        'cake',
        'chair',
        'couch',
        'potted plant',
        'bed',
        'dining table',
        'toilet',
        'tv',
        'laptop',
        'mouse',
        'remote',
        'keyboard',
        'cell phone',
        'microwave',
        'oven',
        'toaster',
        'sink',
        'refrigerator',
        'book',
        'clock',
        'vase',
        'scissors',
        'teddy bear',
        'hair drier',
        'toothbrush'
      ];

  PredictionModel(
    this.width,
    this.height,
    this.boxes,
    this.classes,
    this.scores,
    this.imagePath, [
    this.masks,
  ]);

  PredictionModel.fromMap(Map map)
      : this.width = map['width'],
        this.height = map['height'],
        this.boxes = map['detection_boxes'],
        this.classes = map['detection_classes'],
        this.scores = map['detection_scores'],
        this.imagePath = map['image_path']
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
  Future<Map> paint(
      {color = const ui.Color.fromARGB(100, 255, 255, 255),
      threshold = 0.3}) async {
    var passed_detections = [];
    for (var i = 0; i < boxes.length; i++) {
      var score = scores[i];

      if (score >= threshold) {
        var _class = classes[i];
        var box = boxes[i];

        passed_detections.add([score, _class, box]);
      }
    }

    return {"width": width, "height": height, "detections": passed_detections};
  }
}
