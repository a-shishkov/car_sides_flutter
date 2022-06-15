import 'dart:ui';

class Position {
  int row;
  int column;
  Position(this.row, this.column);

  @override
  bool operator ==(other) {
    if (other is Position && row == other.row && column == other.column)
      return true;
    return false;
  }

  @override
  String toString() {
    return '($row, $column)';
  }

  @override
  int get hashCode => hashValues(row, column);
}
