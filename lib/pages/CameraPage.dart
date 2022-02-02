import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:regexed_validator/regexed_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class CameraPage extends StatefulWidget {
  const CameraPage(this.cameraController, this.sharedPreferences,
      this.connectSocket, this.destroySocket,
      {Key? key})
      : super(key: key);

  final CameraController? cameraController;
  final SharedPreferences sharedPreferences;
  final Function(String, int) connectSocket;
  final Function() destroySocket;

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  TextEditingController textControllerIP = TextEditingController();
  TextEditingController textControllerPort = TextEditingController();

  late String selectedTestImage;

  bool connected = false;
  WhereInference inferenceOn = WhereInference.device;
  set setInferenceOn(WhereInference value) {
    setState(() {
      inferenceOn = value;
    });
  }

  @override
  void initState() {
    textControllerIP.text = prefs.getString('serverIP') ?? '';
    textControllerPort.text = (prefs.getInt('serverPort') ?? 65432).toString();

    selectedTestImage =
        prefs.getString('selectedTestImage') ?? 'car_800_552.jpg';
    super.initState();
  }

  @override
  void dispose() {
    textControllerIP.dispose();
    textControllerPort.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CameraPage oldWidget) {
    selectedTestImage =
        prefs.getString('selectedTestImage') ?? 'car_800_552.jpg';
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // TODO move cameraController to this widget
        widget.cameraController != null
            ? CameraPreview(widget.cameraController!)
            : Image.asset('assets/images/$selectedTestImage'),
        Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              print(details.globalPosition);
              if (details.delta.direction < 0) {
                showModal();
              }
            },
            child: Container(
              alignment: Alignment.bottomCenter,
              width: double.infinity,
              height: 20,
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.filled(
                  2,
                  Container(
                    width: 80,
                    height: 7,
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  showModal() {
    selectedTestImage =
        prefs.getString('selectedTestImage') ?? 'car_800_552.jpg';
    final testImages = prefs.getStringList('testImagesList') ?? [];
    final List<DropdownMenuItem<String>> dropdownItems = List.generate(
        testImages.length,
        (index) => DropdownMenuItem(
              child: Text(index.toString()),
              value: testImages[index],
            ));
    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RadioListTile(
                    title: const Text('Device'),
                    value: WhereInference.device,
                    groupValue: inferenceOn,
                    onChanged: (WhereInference? value) =>
                        onChangedDevice(value, setModalState)),
                RadioListTile(
                    title: const Text('Server'),
                    value: WhereInference.server,
                    groupValue: inferenceOn,
                    onChanged: (WhereInference? value) =>
                        onChangedServer(value, setModalState)),
                ListTile(
                  leading: DropdownButton(
                    value: selectedTestImage,
                    items: dropdownItems,
                    onChanged: (prefs.getBool('testPicture') ?? false)
                        ? (String? value) {
                            prefs.setString('selectedTestImage', value!);
                            setState(() {
                              setModalState(() {
                                selectedTestImage = value;
                              });
                            });
                          }
                        : null,
                  ),
                  title: const Text('Choose test image'),
                )
              ],
            );
          });
        });
  }

  void onChangedDevice(WhereInference? value, StateSetter setState) {
    setState(() {
      inferenceOn = value!;
    });
    if (connected) {
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) => AlertDialog(
                title: Text("Disconnect from server?"),
                actions: [
                  TextButton(
                    child: Text("No"),
                    onPressed: () {
                      setState(() {
                        setInferenceOn = WhereInference.server;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  TextButton(
                    child: Text("Yes"),
                    onPressed: () {
                      widget.destroySocket();
                      connected = false;
                      Navigator.pop(context);
                    },
                  )
                ],
              ));
    }
  }

  void onChangedServer(WhereInference? value, StateSetter setState) async {
    bool connecting = false;
    bool validateIP = true;
    bool validatePort = true;
    setState(() {
      inferenceOn = value!;
    });

    void _onChangedIP(String value) {
      if (!validateIP) {
        setState(() {
          validateIP = validator.ip(textControllerIP.text);
        });
      }
    }

    void _onChangedPort(String value) {
      try {
        var port = int.parse(value);
        setState(() {
          validatePort = 0 <= port && port <= 65535;
        });
      } on FormatException {
        setState(() {
          validatePort = false;
        });
      }
    }

    void _cancel() {
      setInferenceOn = WhereInference.device;
      Navigator.pop(context);
    }

    void _connect() async {
      setState(() {
        validateIP = validator.ip(textControllerIP.text);

        if (!validateIP) {
          return;
        }
        connecting = true;
      });
      connected = await widget.connectSocket(
          textControllerIP.text, int.parse(textControllerPort.text));

      Navigator.pop(context);
    }

    await showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Connect to server"),
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: connecting ? null : Colors.transparent))
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textControllerIP,
                    decoration: InputDecoration(
                        labelText: "Server IP",
                        errorText: validateIP ? null : "Wrong IP"),
                    onChanged: _onChangedIP,
                  ),
                  TextField(
                    controller: textControllerPort,
                    decoration: InputDecoration(
                        labelText: "Server port",
                        errorText: validatePort ? null : "Wrong port"),
                    onChanged: _onChangedPort,
                  ),
                ],
              ),
              actions: [
                TextButton(
                    child: Text("Cancel"),
                    onPressed: connecting ? null : _cancel),
                TextButton(
                    child: Text("Connect"),
                    onPressed: connecting ? null : _connect)
              ],
            );
          });
        });
  }
}
