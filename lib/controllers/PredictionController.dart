import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../main.dart';
import '../models/PredictionModel.dart';

class PredictionController {


  static Future predict(List<int> image) async {
    try {
      var serverIP = prefs.getString('serverIP');
      var response = await Dio().post(
        'http://$serverIP:5000/predict',
        data: {
          'image': base64.encode(image),
        },
      );

      var predictionMap = json.decode(response.data);

      return PredictionModel.fromMap(predictionMap);
    } catch (e) {
      return Future.error(e);
    }
  }
}
