import 'dart:ui' as ui;

class PaintModel {
  final double score;
  final int classID;
  final List box;
  ui.Image? mask;

  PaintModel(this.box, this.score, this.classID, {this.mask});
}
