enum ModelType { damage, parts }

extension ParseToString on ModelType {
  String toShortString() {
    return this.toString().split('.').last;
  }
}