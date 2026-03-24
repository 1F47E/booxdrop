import 'package:flutter/material.dart';
import '../models/stroke.dart';

class DrawingCanvas extends StatelessWidget {
  final List<Stroke> strokes;
  final Stroke? current;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    this.current,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CanvasPainter(strokes: strokes, current: current),
      size: Size.infinite,
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? current;

  _CanvasPainter({required this.strokes, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, ?current]) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => true;
}
