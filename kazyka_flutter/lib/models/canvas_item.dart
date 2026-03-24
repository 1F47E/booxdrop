import 'dart:ui';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A stroke drawn on the canvas, with normalized coordinates (0..1).
class CanvasStroke {
  final String id;
  final String authorId;
  final int colorValue;
  final double width;
  final List<List<double>> points; // [[x, y], ...] normalized 0..1
  final int createdAt;

  CanvasStroke({
    String? id,
    this.authorId = '',
    required this.colorValue,
    required this.width,
    List<List<double>>? points,
    int? createdAt,
  })  : id = id ?? 'stroke_${_uuid.v4().substring(0, 8)}',
        points = points ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'color_value': colorValue,
        'width': width,
        'points': points,
        'created_at': createdAt,
      };

  factory CanvasStroke.fromJson(Map<String, dynamic> json) => CanvasStroke(
        id: json['id'] as String,
        authorId: (json['author_id'] as String?) ?? '',
        colorValue: json['color_value'] as int,
        width: (json['width'] as num).toDouble(),
        points: (json['points'] as List)
            .map((p) =>
                (p as List).map((v) => (v as num).toDouble()).toList())
            .toList(),
        createdAt: (json['created_at'] as int?) ?? 0,
      );

  /// Convert screen pixel offsets to normalized points.
  static List<double> normalize(Offset offset, Size canvasSize) => [
        offset.dx / canvasSize.width,
        offset.dy / canvasSize.height,
      ];

  /// Convert normalized point to screen pixel offset.
  static Offset denormalize(List<double> point, Size canvasSize) =>
      Offset(point[0] * canvasSize.width, point[1] * canvasSize.height);
}

/// A text item placed on the canvas, with normalized position (0..1).
class CanvasText {
  final String id;
  final String authorId;
  final String text;
  final int colorValue;
  final double fontSize;
  final double x; // normalized 0..1
  final double y; // normalized 0..1
  final int createdAt;

  CanvasText({
    String? id,
    this.authorId = '',
    required this.text,
    required this.colorValue,
    this.fontSize = 24,
    required this.x,
    required this.y,
    int? createdAt,
  })  : id = id ?? 'text_${_uuid.v4().substring(0, 8)}',
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'text': text,
        'color_value': colorValue,
        'font_size': fontSize,
        'x': x,
        'y': y,
        'created_at': createdAt,
      };

  factory CanvasText.fromJson(Map<String, dynamic> json) => CanvasText(
        id: json['id'] as String,
        authorId: (json['author_id'] as String?) ?? '',
        text: json['text'] as String,
        colorValue: json['color_value'] as int,
        fontSize: (json['font_size'] as num?)?.toDouble() ?? 24,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        createdAt: (json['created_at'] as int?) ?? 0,
      );
}
