import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'Crosshair.dart';
import 'painters/magnifierPainters.dart';

enum MagnifierType { center, topLeft, topRight, bottomLeft, bottomRight }

class Magnifier extends StatefulWidget {
  final Widget child;
  final Offset? cursorLocal;
  final Offset? cursorGlobal;
  final bool enabled;
  final MagnifierType type;
  final double scale;
  final Size size;
  final CustomPainter painter;

  const Magnifier(
      {required this.child,
      this.cursorLocal,
      this.cursorGlobal,
      this.enabled = true,
      this.type = MagnifierType.bottomRight,
      this.scale = 1.2,
      this.size = const Size(100, 100),
      this.painter = const CrosshairMagnifierPainter(),
      Key? key})
      : super(key: key);

  @override
  _MagnifierState createState() => _MagnifierState();
}

class _MagnifierState extends State<Magnifier> {
  late Size _size;
  late double _scale;

  late MagnifierType _type;
  late GlobalKey _key;

  late Offset _cursorLocal;
  late Offset _cursorGlobal;
  Matrix4 _matrix = Matrix4.identity();
  Offset _childGlobalOffset = Offset(0, 0);
  Size _childSize = Size(0, 0);

  bool get _cursorInWidget {
    if (_cursorLocal.dx < 0) return false;
    if (_cursorLocal.dy < 0) return false;
    if (_cursorLocal.dx > _childSize.width) return false;
    if (_cursorLocal.dy > _childSize.height) return false;
    return true;
  }

  Widget get _body {
    double? left;
    double? right;
    double? top;
    double? bottom;
    switch (_type) {
      case MagnifierType.center:
        left = _cursorLocal.dx - _size.width / 2;
        top = _cursorLocal.dy - _size.height / 2;
        break;
      case MagnifierType.topLeft:
        left = 0;
        top = 0;
        break;
      case MagnifierType.topRight:
        right = 0;
        top = 0;
        break;
      case MagnifierType.bottomLeft:
        left = 0;
        bottom = 0;
        break;
      case MagnifierType.bottomRight:
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
                  size: _size,
                ),
              ),
            ),
          ),
        Crosshair(position: _cursorLocal),
      ],
    );
  }

  @override
  void initState() {
    _cursorLocal = widget.cursorLocal ?? Offset(-1, -1);
    _cursorGlobal = widget.cursorGlobal ?? Offset(-1, -1);
    _type = widget.type;
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
      _type = widget.type;
    }
    if (oldWidget.cursorLocal != widget.cursorLocal) {
      _cursorLocal = widget.cursorLocal ?? Offset(0, 0);
    }
    if (oldWidget.cursorGlobal != widget.cursorGlobal) {
      _cursorGlobal = widget.cursorGlobal ?? Offset(0, 0);
    }
    _calculateMatrix();
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return widget.cursorLocal == null
        ? GestureDetector(
            onPanUpdate: _onPanUpdate,
            child: _body,
          )
        : _body;
  }

  void _onPanUpdate(DragUpdateDetails dragDetails) {
    setState(() {
      _cursorLocal = dragDetails.localPosition;
      _cursorGlobal = dragDetails.globalPosition;
      _calculateMatrix();
    });
  }

  void _calculateMatrix([Offset? position]) {
    RenderBox box = _key.currentContext!.findRenderObject() as RenderBox;
    _childGlobalOffset = box.localToGlobal(Offset.zero);
    _childSize = box.size;

    double newX = position?.dx ?? _cursorGlobal.dx;
    double newY = position?.dy ?? _cursorGlobal.dy;
    late Matrix4 newMatrix;
    switch (_type) {
      case MagnifierType.center:
        newMatrix = Matrix4.identity()
          ..translate(newX, newY)
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
      case MagnifierType.topLeft:
        newX -= (_size.width / 2 + _childGlobalOffset.dx) / _scale;
        newY -= (_size.width / 2 + _childGlobalOffset.dy) / _scale;
        newMatrix = Matrix4.identity()
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
      case MagnifierType.topRight:
        newX -= (_childSize.width - _childGlobalOffset.dx - _size.width / 2) /
            _scale;
        newY -= (_size.width / 2 + _childGlobalOffset.dy) / _scale;
        newMatrix = Matrix4.identity()
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
      case MagnifierType.bottomLeft:
        newX -= (_size.width / 2 + _childGlobalOffset.dx) / _scale;
        newY -= (_childSize.height + _childGlobalOffset.dy - _size.height / 2) /
            _scale;
        newMatrix = Matrix4.identity()
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
      case MagnifierType.bottomRight:
        newX -= (_childSize.width - _childGlobalOffset.dx - _size.width / 2) /
            _scale;
        newY -= (_childSize.height + _childGlobalOffset.dy - _size.height / 2) /
            _scale;
        newMatrix = Matrix4.identity()
          ..scale(_scale, _scale)
          ..translate(-newX, -newY);
        break;
    }
    _matrix = newMatrix;
  }
}
