import 'dart:isolate';
import 'package:flutter_app/mrcnn/config.dart';
import 'package:flutter_app/mrcnn/model.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:flutter_app/utils/image_extender.dart';
import 'package:flutter_app/utils/prediction_result.dart';

class IsolateMsg {
  ImageExtender? image;
  int? interpreterAddress;

  IsolateMsg(this.image, this.interpreterAddress);
}

Future<void> predictIsolate(SendPort sendPort) async {
  var msg = await receiveSend(sendPort);
  var data = msg[0];
  SendPort replyTo = msg[1];

  ImageExtender image = data.image!;
  var address = data.interpreterAddress;

  var model = MaskRCNN.fromAddress(address!);
  replyTo = await sendReceive(replyTo, 0.5);
  var r = await model.detect(image);
  replyTo = await sendReceive(replyTo, 0.6);

  if (r["class_ids"].length > 0) {
    image = displayInstances(image, r["rois"], r["masks"], r["class_ids"],
        CarPartsConfig.CLASS_NAMES,
        scores: r["scores"]);
    replyTo.send(PredictionResult(
        image, r["rois"], r["masks"], r["class_ids"], r["scores"]));
  } else {
    replyTo.send(null);
  }
}

Future receiveSend(SendPort port) {
  ReceivePort response = ReceivePort();
  port.send(response.sendPort);
  return response.first;
}

Future sendReceive(SendPort port, [msg]) {
  ReceivePort response = ReceivePort();
  if (msg == null) {
    port.send(response.sendPort);
  } else {
    port.send([msg, response.sendPort]);
  }
  return response.first;
}
