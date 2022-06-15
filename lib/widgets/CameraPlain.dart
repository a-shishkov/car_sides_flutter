import 'package:flutter/material.dart';

// Small plain with button
class CameraPlain extends StatelessWidget {
  CameraPlain({this.onTakePicture, Key? key}) : super(key: key);

  final void Function()? onTakePicture;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          child: null,
          onPressed: onTakePicture,
          style: ElevatedButton.styleFrom(
              primary: Colors.white,
              fixedSize: const Size(50, 50),
              shape: const CircleBorder()),
        ),
      ),
    );
  }
}
