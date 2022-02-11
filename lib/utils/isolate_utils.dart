import 'dart:isolate';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/mrcnn/configs.dart';
import 'package:flutter_app/mrcnn/model.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:flutter_app/utils/ImageExtender.dart';
import 'package:flutter_app/utils/prediction_result.dart';

class IsolateMsg {
  PredictionImage image;
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
      PredictionImage image = message.image;

      var model = MaskRCNN.fromAddress(message.interpreterAddress);
      sendPort.send({'response': 'Message', 'message': 'Running model'});
      var r = await model.detect(image);

      if (r['class_ids'].length > 0) {
        r['response'] = 'Results raw';
        sendPort.send(r);
      } else {
        sendPort.send({'response': 'No results'});
      }
    }
  });
}
