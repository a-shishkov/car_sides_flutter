import 'dart:isolate';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/mrcnn/configs.dart';
import 'package:flutter_app/mrcnn/model.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'package:flutter_app/utils/prediction_result.dart';

class IsolateMsg {
  ImageExtender image;
  int interpreterAddress;
  ModelType model;

  IsolateMsg(this.image, this.interpreterAddress, this.model);
}

void predictIsolate(SendPort sendPort) {
  ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    print('<isolate> $message received');
    if (message is IsolateMsg) {
      ImageExtender image = message.image;

      var model = MaskRCNN.fromAddress(message.interpreterAddress);
      sendPort.send('Running model');
      var r = model.detect(image);

      if (r['class_ids'].length > 0) {
        sendPort.send('Visualizing result');
        image = displayInstances(image, r['rois'], r['masks'],
            r['class_ids'], CLASS_NAMES[message.model],
            scores: r['scores']);
        sendPort.send(PredictionResult.fromResult(image, r, message.model));
      } else {
        sendPort.send(null);
      }
    }
  });
}
