import 'dart:isolate';
import 'package:flutter_app/mrcnn/config.dart';
import 'package:flutter_app/mrcnn/model.dart';
import 'package:flutter_app/mrcnn/utils.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:image/image.dart';

class IsolateMsg {
  Image image;
  int interpreterAddress;

  IsolateMsg(this.image, this.interpreterAddress);
}

Future<void> predictIsolate(SendPort sendPort) async {
  ReceivePort port = ReceivePort();

  sendPort.send(port.sendPort);

  await for (var msg in port) {
    IsolateMsg data = msg[0];
    SendPort replyTo = msg[1];

    Image? image = data.image;
    var address = data.interpreterAddress;

    var model = MaskRCNN.fromAddress(address);
    var r = await model.detect(image);

    image = await displayInstances(imageTo3DList(image), r["rois"], r["masks"],
        r["class_ids"], CarPartsConfig.CLASS_NAMES);

    replyTo.send(image);
  }
}

Future sendReceive(SendPort port, msg) {
  ReceivePort response = ReceivePort();
  port.send([msg, response.sendPort]);
  return response.first;
}
