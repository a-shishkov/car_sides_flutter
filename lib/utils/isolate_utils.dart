import 'dart:isolate';
import 'package:flutter_app/mrcnn/configs.dart';
import 'package:flutter_app/mrcnn/model.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'package:flutter_app/utils/prediction_result.dart';

class IsolateMsg {
  ImageExtender image;
  int interpreterAddress;
  String modelType;

  IsolateMsg(this.image, this.interpreterAddress, this.modelType);
}

void predictIsolate(SendPort sendPort) {
  ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    print('<isolate> $message received');
    if (message is IsolateMsg) {
      ImageExtender image = message.image;

      var model = MaskRCNN.fromAddress(message.interpreterAddress);
      sendPort.send(['progress', 0.5]);
      var r = await model.detect(image);
      sendPort.send(['progress', 0.6]);

      if (r["class_ids"].length > 0) {
        image = await displayInstances(
            image,
            r["rois"],
            r["masks"],
            r["class_ids"],
            message.modelType == 'parts'
                ? CarPartsConfig.CLASS_NAMES
                : CarDamageConfig.CLASS_NAMES,
            scores: r["scores"]);
        sendPort.send(['result', PredictionResult.fromResult(image, r)]);
      } else {
        sendPort.send(['result', null]);
      }
    }
  });
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
