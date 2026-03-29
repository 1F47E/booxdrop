import 'canvas_item.dart';

class CanvasSessionSnapshot {
  final String sessionId;
  final List<CanvasStroke> strokes;
  final List<CanvasText> texts;
  final int version;
  final int canvasSize;

  CanvasSessionSnapshot({
    this.sessionId = '',
    List<CanvasStroke>? strokes,
    List<CanvasText>? texts,
    this.version = 0,
    this.canvasSize = 2048,
  })  : strokes = strokes ?? [],
        texts = texts ?? [];

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'texts': texts.map((t) => t.toJson()).toList(),
        'version': version,
        'canvas_size': canvasSize,
      };

  factory CanvasSessionSnapshot.fromJson(Map<String, dynamic> json) =>
      CanvasSessionSnapshot(
        sessionId: (json['session_id'] as String?) ?? '',
        strokes: (json['strokes'] as List?)
                ?.map(
                    (s) => CanvasStroke.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        texts: (json['texts'] as List?)
                ?.map(
                    (t) => CanvasText.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        version: (json['version'] as int?) ?? 0,
        canvasSize: (json['canvas_size'] as int?) ?? 2048,
      );

  CanvasSessionSnapshot copyWith({
    String? sessionId,
    List<CanvasStroke>? strokes,
    List<CanvasText>? texts,
    int? version,
    int? canvasSize,
  }) =>
      CanvasSessionSnapshot(
        sessionId: sessionId ?? this.sessionId,
        strokes: strokes ?? this.strokes,
        texts: texts ?? this.texts,
        version: version ?? this.version,
        canvasSize: canvasSize ?? this.canvasSize,
      );
}
