import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/PredictionModel.dart';

class PredictionController {
  static predict(List<int> image) async {
    try {
      var response = await Dio().post(
        'http://193.2.231.115:5000/predict',
        data: {
          'image': base64.encode(image),
        },
      );

      var predictionMap = json.decode(response.data);

      return PredictionModel.fromMap(predictionMap);
    } catch (e) {
      print(e);
    }
  }
}
