import 'dart:math';
import 'dart:ui';

class Polygon {
  List<Offset> points;

  Polygon(this.points);
  Polygon.empty() : points = [];

  int get length => points.length;

  Offset get polygonMax {
    double maxX = 0;
    double maxY = 0;
    for (var point in points) {
      if (point.dx > maxX) {
        maxX = point.dx;
      }
      if (point.dy > maxY) {
        maxY = point.dy;
      }
    }
    return Offset(maxX, maxY);
  }

  Offset get polygonMin {
    double minX = double.maxFinite;
    double minY = double.maxFinite;
    for (var point in points) {
      if (point.dx < minX) {
        minX = point.dx;
      }
      if (point.dy < minY) {
        minY = point.dy;
      }
    }
    return Offset(minX, minY);
  }

  void add(Offset offset) {
    points.add(offset);
  }

  void removeAt(int i) {
    points.removeAt(i);
  }

  Offset operator [](int i) => points[i];
  void operator []=(int i, Offset value) => points[i] = value;

  // Returns true if the point p lies inside the polygon
  // https://www.geeksforgeeks.org/how-to-check-if-a-given-point-lies-inside-a-polygon/
  bool isPointInside(Offset p) {
    var n = length;

    // There must be at least 3 vertices in polygon
    if (n < 3) {
      return false;
    }

    // Check if point is inside of polygonMin and polygonMax
    if (p.dx < polygonMin.dx || p.dx > polygonMax.dx) {
      return false;
    }
    if (p.dy < polygonMin.dy || p.dy > polygonMax.dy) {
      return false;
    }

    var extreme = Offset(polygonMax.dx, p.dy);

    var count = 0;
    var i = 0;

    do {
      var next = (i + 1) % n;

      // Check if the line segment from 'p' to 'extreme' intersects
      // with the line segment from 'points[i]' to 'points[next]'
      if (_doIntersect(points[i], points[next], p, extreme)) {
        if (_orientation(points[i], p, points[next]) == 0) {
          return _onSegment(points[i], p, points[next]);
        }
        count++;
      }
      i = next;
    } while (i != 0);

    return count % 2 == 1;
  }

  bool _doIntersect(Offset px1, Offset py1, Offset px2, Offset py2) {
    var o1 = _orientation(px1, py1, px2);
    var o2 = _orientation(px1, py1, py2);
    var o3 = _orientation(px2, py2, px1);
    var o4 = _orientation(px2, py2, py1);

    // General case
    if (o1 != o2 && o3 != o4) return true;

    // Special Cases
    // p1, q1 and p2 are collinear and p2 lies on segment p1q1
    if (o1 == 0 && _onSegment(px1, px2, py1)) return true;

    // p1, q1 and p2 are collinear and q2 lies on segment p1q1
    if (o2 == 0 && _onSegment(px1, py2, py1)) return true;

    // p2, q2 and p1 are collinear and p1 lies on segment p2q2
    if (o3 == 0 && _onSegment(px2, px1, py2)) return true;

    // p2, q2 and q1 are collinear and q1 lies on segment p2q2
    if (o4 == 0 && _onSegment(px2, py1, py2)) return true;

    return false; // Doesn't fall in any of the above cases
  }

  int _orientation(Offset p, Offset q, Offset r) {
    var val =
        (((q.dy - p.dy) * (r.dx - q.dx)) - ((q.dx - p.dx) * (r.dy - q.dy)));
    if (val == 0) {
      return 0;
    } else if (val > 0) {
      return 1;
    } else {
      return 2;
    }
  }

  bool _onSegment(Offset p, Offset q, Offset r) {
    if (q.dx <= max(p.dx, r.dx) &&
        q.dx >= min(p.dx, r.dx) &&
        q.dy <= max(p.dy, r.dy) &&
        q.dy >= min(p.dy, r.dy)) return true;
    return false;
  }

  @override
  String toString() {
    return '$points';
  }
}