import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/canvas_item.dart';

/// Active stroke being drawn (virtual-canvas coordinates).
class ActiveStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final BrushType brushType;

  ActiveStroke({
    required this.color,
    required this.width,
    this.brushType = BrushType.round,
  }) : points = [];
}

class DrawingCanvas extends StatelessWidget {
  final List<CanvasStroke> strokes;
  final List<CanvasText> texts;
  final ActiveStroke? activeStroke;
  final Size virtualSize;
  final Offset offset;
  final double scale;
  final ui.Image? backgroundImage;
  final ui.Image? fillBitmap;
  final int bakedStrokeCount;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.texts,
    this.activeStroke,
    this.virtualSize = const Size(2048, 2048),
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.backgroundImage,
    this.fillBitmap,
    this.bakedStrokeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CanvasPainter(
        strokes: strokes,
        texts: texts,
        activeStroke: activeStroke,
        virtualSize: virtualSize,
        offset: offset,
        scale: scale,
        backgroundImage: backgroundImage,
        fillBitmap: fillBitmap,
        bakedStrokeCount: bakedStrokeCount,
      ),
      size: Size.infinite,
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<CanvasStroke> strokes;
  final List<CanvasText> texts;
  final ActiveStroke? activeStroke;
  final Size virtualSize;
  final Offset offset;
  final double scale;
  final ui.Image? backgroundImage;
  final ui.Image? fillBitmap;
  final int bakedStrokeCount;

  _CanvasPainter({
    required this.strokes,
    required this.texts,
    this.activeStroke,
    required this.virtualSize,
    required this.offset,
    required this.scale,
    this.backgroundImage,
    this.fillBitmap,
    this.bakedStrokeCount = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Gray background outside the virtual canvas
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE0E0E0),
    );

    // Apply viewport transform
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // Draw virtual canvas background (white rectangle)
    canvas.drawRect(
      Offset.zero & virtualSize,
      Paint()..color = Colors.white,
    );
    canvas.clipRect(Offset.zero & virtualSize);

    // Draw background reference image (legacy PNG edit)
    if (backgroundImage != null) {
      final src = Rect.fromLTWH(0, 0, backgroundImage!.width.toDouble(),
          backgroundImage!.height.toDouble());
      final dst = Offset.zero & virtualSize;
      canvas.drawImageRect(backgroundImage!, src, dst, Paint());
    }

    if (fillBitmap != null) {
      // Fill bitmap contains pre-fill strokes + fills baked in.
      final src = Rect.fromLTWH(0, 0, fillBitmap!.width.toDouble(),
          fillBitmap!.height.toDouble());
      final dst = Offset.zero & virtualSize;
      canvas.drawImageRect(fillBitmap!, src, dst, Paint());

      // Render strokes added AFTER the fill was baked
      for (var i = bakedStrokeCount; i < strokes.length; i++) {
        final stroke = strokes[i];
        if (stroke.points.isEmpty) continue;
        final paint = _paintForBrush(stroke.color, stroke.width, stroke.brushType);
        final pts = stroke.points
            .map((p) => CanvasStroke.denormalize(p, virtualSize))
            .toList();
        _drawStroke(canvas, pts, paint, stroke.width);
      }
    } else {
      // No fills — render all committed strokes
      for (final stroke in strokes) {
        if (stroke.points.isEmpty) continue;
        final paint = _paintForBrush(stroke.color, stroke.width, stroke.brushType);
        final pts = stroke.points
            .map((p) => CanvasStroke.denormalize(p, virtualSize))
            .toList();
        _drawStroke(canvas, pts, paint, stroke.width);
      }
    }

    // Render active stroke (virtual-canvas coordinates)
    if (activeStroke != null && activeStroke!.points.isNotEmpty) {
      final paint = _paintForBrush(
          activeStroke!.color, activeStroke!.width, activeStroke!.brushType);
      _drawStroke(canvas, activeStroke!.points, paint, activeStroke!.width);
    }

    // Render text items (normalized → virtual-canvas coords)
    for (final t in texts) {
      final textOffset =
          Offset(t.x * virtualSize.width, t.y * virtualSize.height);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(color: t.color, fontSize: t.fontSize),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, textOffset);
    }

    canvas.restore();
  }

  Paint _paintForBrush(Color color, double width, BrushType brush) {
    final paint = Paint()
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    switch (brush) {
      case BrushType.round:
        paint
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
      case BrushType.flat:
        paint
          ..color = color
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.bevel;
      case BrushType.marker:
        paint
          ..color = color.withAlpha(100)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
      case BrushType.crayon:
        paint
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    }
    return paint;
  }

  void _drawStroke(Canvas canvas, List<Offset> pts, Paint paint, double width) {
    if (pts.length == 1) {
      canvas.drawCircle(pts.first, width / 2, paint..style = PaintingStyle.fill);
      return;
    }
    final path = Path();
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => true;
}
