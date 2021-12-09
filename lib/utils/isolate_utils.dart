import 'dart:isolate';
import 'package:flutter_app/mrcnn/config.dart';
import 'package:flutter_app/mrcnn/model.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:flutter_app/utils/image_extender.dart';

class IsolateMsg {
  ImageExtender image;
  int? interpreterAddress;
  int? foundInstances;

  IsolateMsg(this.image, {this.interpreterAddress, this.foundInstances});
}

Future<void> predictIsolate(SendPort sendPort) async {
  ReceivePort port = ReceivePort();

  sendPort.send(port.sendPort);

  await for (var msg in port) {
    IsolateMsg data = msg[0];
    SendPort replyTo = msg[1];

    ImageExtender image = data.image;
    var address = data.interpreterAddress;

    var model = MaskRCNN.fromAddress(address!);
    var r = await model.detect(image);

    if (r["class_ids"].length > 0) {
      image.image = await displayInstances(image.imageList, r["rois"],
          r["masks"], r["class_ids"], CarPartsConfig.CLASS_NAMES, scores: r["scores"]);
    }

    replyTo.send(IsolateMsg(image, foundInstances: r["class_ids"].length));
  }
}

Future sendReceive(SendPort port, msg) {
  ReceivePort response = ReceivePort();
  port.send([msg, response.sendPort]);
  return response.first;
}
