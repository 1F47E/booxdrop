import 'dart:convert';
import 'canvas_item.dart';

/// Editable document format for saved drawings.
/// Stored as a `.kazyka.json` sidecar next to the preview PNG.
class DrawingDocument {
  final int version;
  final int canvasSize;
  final List<CanvasStroke> strokes;
  final List<CanvasText> texts;
  final List<CanvasFill> fills;
  final int createdAt;

  DrawingDocument({
    this.version = 2,
    required this.canvasSize,
    required this.strokes,
    required this.texts,
    this.fills = const [],
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'version': version,
        'canvas_size': canvasSize,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'texts': texts.map((t) => t.toJson()).toList(),
        'fills': fills.map((f) => f.toJson()).toList(),
        'created_at': createdAt,
      };

  factory DrawingDocument.fromJson(Map<String, dynamic> json) {
    return DrawingDocument(
      version: json['version'] as int? ?? 1,
      canvasSize: json['canvas_size'] as int? ?? 2048,
      strokes: (json['strokes'] as List? ?? [])
          .map((s) => CanvasStroke.fromJson(s as Map<String, dynamic>))
          .toList(),
      texts: (json['texts'] as List? ?? [])
          .map((t) => CanvasText.fromJson(t as Map<String, dynamic>))
          .toList(),
      fills: (json['fills'] as List? ?? [])
          .map((f) => CanvasFill.fromJson(f as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as int? ?? 0,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory DrawingDocument.fromJsonString(String json) =>
      DrawingDocument.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
