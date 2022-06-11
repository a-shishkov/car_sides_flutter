import 'package:flutter_app/main.dart';

class CarPartsConfig {
  static const List<int> BACKBONE_STRIDES = [4, 8, 16, 32, 64];
  static const int IMAGE_MAX_DIM = 512;
  static const int IMAGE_MIN_DIM = 512;
  static const int IMAGE_MIN_SCALE = 0;
  static const String IMAGE_RESIZE_MODE = 'square';
  static const List<double> MEAN_PIXEL = [123.7, 116.8, 103.9];
  static const int NUM_CLASSES = 9;
  static const List<double> RPN_ANCHOR_RATIOS = [0.5, 1, 2];
  static const List<double> RPN_ANCHOR_SCALES = [8, 16, 32, 64, 128];
  static const int RPN_ANCHOR_STRIDE = 1;
  static const List<String> CLASS_NAMES = [
    'BG',
    'bumper',
    'glass',
    'door',
    'light',
    'hood',
    'mirror',
    'trunk',
    'wheel'
  ];
}

class CarDamageConfig {
  static const List<int> BACKBONE_STRIDES = [4, 8, 16, 32, 64];
  static const int IMAGE_MAX_DIM = 512;
  static const int IMAGE_MIN_DIM = 512;
  static const int IMAGE_MIN_SCALE = 0;
  static const String IMAGE_RESIZE_MODE = 'square';
  static const List<double> MEAN_PIXEL = [123.7, 116.8, 103.9];
  static const int NUM_CLASSES = 9;
  static const List<double> RPN_ANCHOR_RATIOS = [0.5, 1, 2];
  static const List<double> RPN_ANCHOR_SCALES = [8, 16, 32, 64, 128];
  static const int RPN_ANCHOR_STRIDE = 1;
  static const List<String> CLASS_NAMES = ['BG', 'damage'];
}

const Map<ModelType, List<String>> CLASS_NAMES = {
  ModelType.damage: CarDamageConfig.CLASS_NAMES,
  ModelType.parts: CarPartsConfig.CLASS_NAMES
};
