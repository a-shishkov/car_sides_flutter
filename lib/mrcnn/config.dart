class CarPartsConfig {
  static const List<int> BACKBONE_STRIDES = [4, 8, 16, 32, 64];
  static const int IMAGE_MAX_DIM = 512;
  static const int IMAGE_MIN_DIM = 512;
  static const int IMAGE_MIN_SCALE = 0;
  static const String IMAGE_RESIZE_MODE = 'square';
  static const List<double> MEAN_PIXEL = [123.7, 116.8, 103.9];
  static const int NUM_CLASSES = 19;
  static const List<double> RPN_ANCHOR_RATIOS = [0.5, 1, 2];
  static const List<double> RPN_ANCHOR_SCALES = [8, 16, 32, 64, 128];
  static const int RPN_ANCHOR_STRIDE = 1;
  static const List CLASS_NAMES = [
    'BG',
    'back_bumper',
    'back_glass',
    'back_left_door',
    'back_left_light',
    'back_right_door',
    'back_right_light',
    'front_bumper',
    'front_glass',
    'front_left_door',
    'front_left_light',
    'front_right_door',
    'front_right_light',
    'hood',
    'left_mirror',
    'right_mirror',
    'tailgate',
    'trunk',
    'wheel'
  ];
}