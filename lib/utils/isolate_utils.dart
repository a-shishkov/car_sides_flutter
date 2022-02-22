import 'dart:isolate';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/mrcnn/model.dart';
import 'package:flutter_app/mrcnn/visualize.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import '../mrcnn/utils.dart';
import 'PredictionImage.dart';


void predictIsolate(SendPort sendPort) {
  ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    print('<isolate> $message received');
    if (message is Map) {
      PredictionImage image = message['image'];

      Map addresses = message['model_addresses'];

      sendPort.send({'response': 'Message', 'message': 'Running model'});

      Map predictions = {};

      for (var modelType in addresses.keys) {
        var model = MaskRCNN.fromAddress(addresses[modelType]);
        var r = model.detect(image);
        if (r['boxes'].length == 0) {
          sendPort.send({'response': 'No results'});
          return;
        }
        predictions[enumToString(modelType)] = r;
      }

      var intersections = List.generate(
          predictions['parts']['boxes'].length, (i) => []);

      for (int i = 0; i < predictions['damage']['boxes'].length; i++) {
        var damageMask = unmoldFullMask(
            predictions['damage']['masks'][i],
            predictions['damage']['boxes'][i],
            [image.height, image.width]);
        for (int j = 0; j < predictions['parts']['boxes'].length; j++) {
          var partsMask = unmoldFullMask(
              predictions['parts']['masks'][j],
              predictions['parts']['boxes'][j],
              [image.height, image.width]);

          for (int h = 0; h < image.height; h++) {
            for (int w = 0; w < image.width; w++) {
              if (damageMask[h][w] && partsMask[h][w]) {
                intersections[j].add(i);
              }
            }
          }
        }
      }

      sendPort.send({
        'response': 'Results',
        'predictions': predictions,
        'intersections': intersections
      });
    }
  });
}
