import 'PolygonModel.dart';
import 'enums/ModelType.dart';

class Annotation {
  ModelType superCategory;
  int categoryId;
  Polygon polygon;

  Annotation(this.superCategory, this.categoryId, this.polygon);

  List<int> get segmentation {
    List<int> segmentation = [];
    for (var point in polygon.points) {
      segmentation.add(point.dx.round());
      segmentation.add(point.dy.round());
    }
    return segmentation;
  }

  Map<String, dynamic> get toMap => {
        'super_category': superCategory.toShortString(),
        'category_id': categoryId,
        'segmentation': segmentation
      };

  Polygon scalePolygon(double scaleX, double scaleY) {
    return Polygon(List.generate(
        polygon.length, (index) => polygon[index].scale(scaleX, scaleY)));
  }

  @override
  String toString() {
    return 'Annotation($categoryId ${polygon.toString()})';
  }
}
