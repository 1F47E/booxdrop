import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazyka/models/canvas_item.dart';

void main() {
  group('CanvasStroke', () {
    test('JSON serialization round-trip', () {
      final stroke = CanvasStroke(
        id: 'stroke_abc',
        authorId: 'dev123',
        colorValue: 0xFF000000,
        width: 6.0,
        points: [
          [0.1, 0.2],
          [0.3, 0.4],
          [0.5, 0.6],
        ],
        createdAt: 1000,
      );

      final json = stroke.toJson();
      final restored = CanvasStroke.fromJson(json);

      expect(restored.id, 'stroke_abc');
      expect(restored.authorId, 'dev123');
      expect(restored.colorValue, 0xFF000000);
      expect(restored.width, 6.0);
      expect(restored.points.length, 3);
      expect(restored.points[0], [0.1, 0.2]);
      expect(restored.points[2], [0.5, 0.6]);
      expect(restored.createdAt, 1000);
    });

    test('normalize and denormalize are inverses', () {
      const size = Size(400, 800);
      const offset = Offset(200, 400);

      final normalized = CanvasStroke.normalize(offset, size);
      expect(normalized[0], closeTo(0.5, 0.001));
      expect(normalized[1], closeTo(0.5, 0.001));

      final restored = CanvasStroke.denormalize(normalized, size);
      expect(restored.dx, closeTo(offset.dx, 0.1));
      expect(restored.dy, closeTo(offset.dy, 0.1));
    });

    test('normalize handles edge coordinates', () {
      const size = Size(100, 200);

      final topLeft = CanvasStroke.normalize(Offset.zero, size);
      expect(topLeft, [0.0, 0.0]);

      final bottomRight = CanvasStroke.normalize(const Offset(100, 200), size);
      expect(bottomRight[0], closeTo(1.0, 0.001));
      expect(bottomRight[1], closeTo(1.0, 0.001));
    });

    test('auto-generates id and createdAt', () {
      final stroke = CanvasStroke(colorValue: 0xFF000000, width: 3.0);
      expect(stroke.id, startsWith('stroke_'));
      expect(stroke.createdAt, greaterThan(0));
    });

    test('color getter returns correct Color', () {
      final stroke = CanvasStroke(colorValue: 0xFFFF0000, width: 3.0);
      expect(stroke.color, const Color(0xFFFF0000));
    });
  });

  group('CanvasText', () {
    test('JSON serialization round-trip', () {
      final text = CanvasText(
        id: 'text_xyz',
        authorId: 'dev456',
        text: 'Hello',
        colorValue: 0xFF0000FF,
        fontSize: 32,
        x: 0.25,
        y: 0.75,
        createdAt: 2000,
      );

      final json = text.toJson();
      final restored = CanvasText.fromJson(json);

      expect(restored.id, 'text_xyz');
      expect(restored.authorId, 'dev456');
      expect(restored.text, 'Hello');
      expect(restored.colorValue, 0xFF0000FF);
      expect(restored.fontSize, 32);
      expect(restored.x, 0.25);
      expect(restored.y, 0.75);
      expect(restored.createdAt, 2000);
    });

    test('auto-generates id', () {
      final text = CanvasText(
        text: 'Hi',
        colorValue: 0xFF000000,
        x: 0.5,
        y: 0.5,
      );
      expect(text.id, startsWith('text_'));
    });

    test('default fontSize is 24', () {
      final text = CanvasText(
        text: 'Hi',
        colorValue: 0xFF000000,
        x: 0.5,
        y: 0.5,
      );
      expect(text.fontSize, 24);
    });
  });
}
