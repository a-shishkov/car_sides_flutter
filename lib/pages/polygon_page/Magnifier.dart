import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'Crosshair.dart';
import 'painters/magnifierPainters.dart';

enum MagnifierType { center, top, bottom }
enum _SidedMagnifierType { center, topLeft, topRight, bottomLeft, bottomRight }

class Magnifier extends StatefulWidget {
  final Widget child;
  final Offset? cursor;
  final Function(DragStartDetails)? onPanStart;
  final Function(DragUpdateDetails)? onPanUpdate;
  final Function(DragEndDetails)? onPanEnd;
  final bool enabled;
  final MagnifierType type;
  final double scale;
  final double size;
  final CustomPainter painter;

  const Magnifier(
      {required this.child,
      this.cursor,
      this.onPanStart,
      this.onPanUpdate,
      this.onPanEnd,
      this.enabled = true,
      this.type = MagnifierType.top,
      this.scale = 1.2,
      this.size = 100,
      this.painter = const CrosshairMagnifierPainter(),
      Key? key})
      : super(key: key);

  @override
  _MagnifierState createState() => _MagnifierState();
}

class _MagnifierState extends State<Magnifier> {
  late double _size;
  late double _scale;

  late _SidedMagnifierType _type;
  late GlobalKey _key;

  late Offset _cursor;
  Matrix4 _matrix = Matrix4.identity();
  Offset _childGlobalOffset = Offset(0, 0);
  Size _childSize = Size(0, 0);

  Offset get crosshairPosition => _cursor - _childGlobalOffset;

  bool get _cursorInWidget {
    if (crosshairPosition.dx < 0) return false;
    if (crosshairPosition.dy < 0) return false;
    if (crosshairPosition.dx > _childSize.width) return false;
    if (crosshairPosition.dy > _childSize.height) return false;
    return true;
  }

  Widget get _body {
    double? left;
    double? right;
    double? top;
    double? bottom;
    switch (_type) {
      case _SidedMagnifierType.center:
        left = crosshairPosition.dx - _size / 2;
        top = crosshairPosition.dy - _size / 2;
        break;
      case _SidedMagnifierType.topLeft:
        left = 0;
        top = 0;
        break;
      case _SidedMagnifierType.topRight:
        right = 0;
        top = 0;
        break;
      case _SidedMagnifierType.bottomLeft:
        left = 0;
        bottom = 0;
        break;
      case _SidedMagnifierType.bottomRight:
        right = 0;
        bottom = 0;
        break;
    }
    return Stack(
      key: _key,
      alignment: Alignment.center,
      children: [
        widget.child,
        if (widget.enabled && _cursorInWidget)
          Positioned(
            left: left,
            right: right,
            top: top,
            bottom: bottom,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.matrix(_matrix.storage),
                child: CustomPaint(
                  painter: widget.painter,
                  size: Size(_size, _size),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    _cursor = widget.cursor ?? Offset(-1, -1);

    switch (widget.type) {
      case MagnifierType.center:
        _type = _SidedMagnifierType.center;
        break;
      case MagnifierType.top:
        _type = _SidedMagnifierType.topLeft;
        break;
      case MagnifierType.bottom:
        _type = _SidedMagnifierType.bottomLeft;
    }
    _size = widget.size;
    _scale = widget.scale;
    _key = GlobalKey();
    super.initState();
  }

  @override
  void didUpdateWidget(Magnifier oldWidget) {
    if (oldWidget.size != widget.size) {
      _size = widget.size;
    }
    if (oldWidget.scale != widget.scale) {
      _scale = widget.scale;
    }
    if (oldWidget.type != widget.type) {
      switch (widget.type) {
        case MagnifierType.center:
          _type = _SidedMagnifierType.center;
          break;
        case MagnifierType.top:
          _type = _SidedMagnifierType.topLeft;
          break;
        case MagnifierType.bottom:
          _type = _SidedMagnifierType.bottomLeft;
      }
    }
    if (oldWidget.cursor != widget.cursor) {
      _cursor = widget.cursor ?? Offset(0, 0);
    }
    if (widget.enabled) {
      _calculateMatrix();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return _body;
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.onPanStart != null) widget.onPanStart!(details);
    setState(() {
      _cursor = details.globalPosition;
      _calculateMatrix();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.onPanUpdate != null) widget.onPanUpdate!(details);
    setState(() {
      _cursor = details.globalPosition;
      _calculateMatrix();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.onPanEnd != null) widget.onPanEnd!(details);
  }

  void _calculateMatrix() {
    RenderBox box = _key.currentContext!.findRenderObject() as RenderBox;
    _childGlobalOffset = box.localToGlobal(Offset.zero);
    _childSize = box.size;
    double newX = _cursor.dx;
    double newY = _cursor.dy;

    if (_cursor.dx > (_childSize.width + _childGlobalOffset.dx) / 2) {
      if (_type == _SidedMagnifierType.topLeft ||
          _type == _SidedMagnifierType.topRight) {
        _type = _SidedMagnifierType.topLeft;
      } else {
        _type = _SidedMagnifierType.bottomLeft;
      }
    } else {
      if (_type == _SidedMagnifierType.topLeft ||
          _type == _SidedMagnifierType.topRight) {
        _type = _SidedMagnifierType.topRight;
      } else {
        _type = _SidedMagnifierType.bottomRight;
      }
    }
    late Matrix4 newMatrix;
    switch (_type) {
      case _SidedMagnifierType.center:
        newMatrix = Matrix4.identity()
          ..translate(newX, newY)
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
      case _SidedMagnifierType.topLeft:
        newX -= (_size / 2 + _childGlobalOffset.dx) / _scale;
        newY -= (_size / 2 + _childGlobalOffset.dy) / _scale;
        newMatrix = Matrix4.identity()
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
      case _SidedMagnifierType.topRight:
        newX -= (_childSize.width + _childGlobalOffset.dx - _size / 2) / _scale;
        newY -= (_size / 2 + _childGlobalOffset.dy) / _scale;
        newMatrix = Matrix4.identity()
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
      case _SidedMagnifierType.bottomLeft:
        newX -= (_size / 2 + _childGlobalOffset.dx) / _scale;
        newY -=
            (_childSize.height + _childGlobalOffset.dy - _size / 2) / _scale;
        newMatrix = Matrix4.identity()
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
      case _SidedMagnifierType.bottomRight:
        newX -= (_childSize.width + _childGlobalOffset.dx - _size / 2) / _scale;
        newY -=
            (_childSize.height + _childGlobalOffset.dy - _size / 2) / _scale;
        newMatrix = Matrix4.identity()
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
    }
    _matrix = newMatrix;
  }
}
