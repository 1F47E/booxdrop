import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/canvas_item.dart';

/// Active stroke being drawn (screen-pixel coordinates, not yet normalized).
class ActiveStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  ActiveStroke({required this.color, required this.width}) : points = [];
}

class DrawingCanvas extends StatelessWidget {
  final List<CanvasStroke> strokes;
  final List<CanvasText> texts;
  final ActiveStroke? activeStroke;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.texts,
    this.activeStroke,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CanvasPainter(
        strokes: strokes,
        texts: texts,
        activeStroke: activeStroke,
      ),
      size: Size.infinite,
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<CanvasStroke> strokes;
  final List<CanvasText> texts;
  final ActiveStroke? activeStroke;

  _CanvasPainter({
    required this.strokes,
    required this.texts,
    this.activeStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Render committed strokes (normalized coordinates)
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        final pt = CanvasStroke.denormalize(stroke.points.first, size);
        canvas.drawCircle(pt, stroke.width / 2, paint..style = PaintingStyle.fill);
        continue;
      }

      final path = Path();
      final first = CanvasStroke.denormalize(stroke.points.first, size);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        final pt = CanvasStroke.denormalize(stroke.points[i], size);
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, paint);
    }

    // Render active stroke (screen-pixel coordinates — not yet normalized)
    if (activeStroke != null && activeStroke!.points.isNotEmpty) {
      final paint = Paint()
        ..color = activeStroke!.color
        ..strokeWidth = activeStroke!.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (activeStroke!.points.length == 1) {
        canvas.drawCircle(
          activeStroke!.points.first,
          activeStroke!.width / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path();
        path.moveTo(
            activeStroke!.points.first.dx, activeStroke!.points.first.dy);
        for (var i = 1; i < activeStroke!.points.length; i++) {
          path.lineTo(
              activeStroke!.points[i].dx, activeStroke!.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // Render text items (normalized coordinates)
    for (final t in texts) {
      final offset = Offset(t.x * size.width, t.y * size.height);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(color: t.color, fontSize: t.fontSize),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => true;
}
