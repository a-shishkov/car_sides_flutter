import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../main.dart';
import '../models/AnnotationModel.dart';
import '../models/PredictionModel.dart';

class PredictionController {
  // Send base64 image to the server
  // Get detection of type:
  // {'width': int, 'height': int, 
  // 'boxes': [instances * [left, top, right, bottom, confidence]],
  // 'masks': [instances * [bool mask of size (h,w)]
  // 'scores': [instances of double],
  // 'classes': [instances of int]}
  static Future predict(List<int> image,
      {List<Annotation>? annotations}) async {
    Map<String, dynamic> data = {'image': base64.encode(image)};
    if (annotations != null)
      data['annotations'] = annotations.map((e) => e.toMap).toList();

    try {
      var serverIP = prefs.getString('serverIP');
      var response = await Dio().post(
        'http://$serverIP:5000/predict',
        data: data,
      );

      var predictionMap = json.decode(response.data);

      return PredictionModel.fromMap(predictionMap);
    } catch (e) {
      return Future.error(e);
    }
  }
}
