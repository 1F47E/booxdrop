import 'dart:ui';

class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;

  Stroke({required this.color, required this.width}) : points = [];
}
