import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class CameraPage extends StatefulWidget {
  const CameraPage(
      {required this.cameraController,
      required this.cameraEnabled,
      required this.imageItems,
      required this.inferenceOn,
      required this.isDemo,
      required this.onChangedDevice,
      required this.onChangedServer,
      required this.onImageChanged,
      required this.onTakePicture,
      this.initialImage,
      Key? key})
      : super(key: key);

  final CameraController? cameraController;
  final bool cameraEnabled;
  final int? initialImage;
  final List imageItems;
  final WhereInference inferenceOn;
  final bool isDemo;
  final Function() onTakePicture;
  final Function() onChangedDevice;
  final Function() onChangedServer;
  final Function(int index) onImageChanged;

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late PageController pageController;

  late int selectedImage;

  ButtonStyle get enabledStyle => TextButton.styleFrom(
      primary: Colors.black, backgroundColor: Colors.white);

  ButtonStyle get disabledStyle => TextButton.styleFrom(
      primary: Colors.grey[900], backgroundColor: Colors.grey);

  @override
  void initState() {
    selectedImage = widget.initialImage ?? 0;
    pageController = PageController(initialPage: selectedImage);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant CameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Widget cameraWidget() {
    if (widget.isDemo)
      return Center(
        child: Text(
          'Demo image is only on server.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 25),
        ),
      );

    if (!widget.cameraEnabled)
      return Stack(alignment: Alignment.center, children: [
        PhotoViewGallery.builder(
            pageController: pageController,
            onPageChanged: imagePageChanged,
            itemCount: widget.imageItems.length,
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                  maxScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  imageProvider:
                      AssetImage('assets/images/${widget.imageItems[index]}'));
            }),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white,
          )
        ])
      ]);

    if (widget.cameraController != null &&
        widget.cameraController!.value.isInitialized)
      return CameraPreview(widget.cameraController!);

    return Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        cameraWidget(),
        Container(
          color: Colors.black45,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 8),
                  child: TextButton(
                    onPressed: widget.onChangedDevice,
                    style: widget.inferenceOn == WhereInference.device
                        ? enabledStyle
                        : disabledStyle,
                    child: Text('Device'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  child: null,
                  onPressed: widget.onTakePicture,
                  style: ElevatedButton.styleFrom(
                      primary: Colors.white,
                      fixedSize: const Size(50, 50),
                      shape: const CircleBorder()),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 8),
                  child: TextButton(
                      onPressed: widget.onChangedServer,
                      style: widget.inferenceOn == WhereInference.server
                          ? enabledStyle
                          : disabledStyle,
                      child: Text('Server')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void imagePageChanged(int index) {
    selectedImage = index;
    widget.onImageChanged(index);
  }
}
