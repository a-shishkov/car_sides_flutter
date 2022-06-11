import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.image, required this.result, Key? key})
      : super(key: key);

  final XFile image;
  final Map result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Text(widget.result['result'][0][0][0].toString()),
    );
  }
}
