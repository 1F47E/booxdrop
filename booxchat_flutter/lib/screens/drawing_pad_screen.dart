import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;

  _Stroke({required this.color, required this.width}) : points = [];
}

class DrawingPadScreen extends StatefulWidget {
  const DrawingPadScreen({super.key});

  @override
  State<DrawingPadScreen> createState() => _DrawingPadScreenState();
}

class _DrawingPadScreenState extends State<DrawingPadScreen> {
  final List<_Stroke> _strokes = [];
  final GlobalKey _canvasKey = GlobalKey();
  _Stroke? _current;
  Color _color = Colors.black;
  double _strokeWidth = 6.0;
  bool _saving = false;

  static const _colors = <Color>[
    Colors.black,
    Color(0xFF555555),
    Colors.white,
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFDD835), // yellow
    Color(0xFFFB8C00), // orange
    Color(0xFF8E24AA), // purple
    Color(0xFF6D4C41), // brown
  ];

  static const _widths = [3.0, 6.0, 12.0];

  bool get _hasStrokes => _strokes.isNotEmpty || _current != null;

  Future<bool> _onWillPop() async {
    if (!_hasStrokes) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved drawing'),
        content: const Text('What do you want to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child:
                const Text('Keep drawing', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard', style: TextStyle(color: Colors.black)),
          ),
          if (_hasStrokes)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Save', style: TextStyle(color: Colors.black)),
            ),
        ],
      ),
    );
    if (result == 'discard') return true;
    if (result == 'save') {
      final path = await _renderAndSave();
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drawing saved!')),
        );
      }
      return true;
    }
    return false;
  }

  Future<String?> _renderAndSave() async {
    if (!_hasStrokes) return null;
    setState(() => _saving = true);

    try {
      const size = Size(1024, 1024);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Offset.zero & size);

      // White background
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white,
      );

      // Scale strokes from screen coords to 1024x1024
      final renderBox =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      final canvasSize = renderBox?.size ?? MediaQuery.of(context).size;
      final scaleX = size.width / canvasSize.width;
      final scaleY = size.height / canvasSize.height;

      for (final stroke in _strokes) {
        if (stroke.points.isEmpty) continue;
        final scaledWidth = stroke.width * ((scaleX + scaleY) / 2);
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = scaledWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        if (stroke.points.length == 1) {
          // Single tap — draw a dot
          canvas.drawCircle(
            Offset(stroke.points.first.dx * scaleX,
                stroke.points.first.dy * scaleY),
            scaledWidth / 2,
            paint..style = PaintingStyle.fill,
          );
          continue;
        }

        final path = Path();
        path.moveTo(
            stroke.points.first.dx * scaleX, stroke.points.first.dy * scaleY);
        for (var i = 1; i < stroke.points.length; i++) {
          path.lineTo(
              stroke.points[i].dx * scaleX, stroke.points[i].dy * scaleY);
        }
        canvas.drawPath(path, paint);
      }

      final picture = recorder.endRecording();
      final image =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      final b64 = base64Encode(bytes);
      final msgId = 'draw_${DateTime.now().microsecondsSinceEpoch}';
      final path = await StorageService.saveImage(b64, msgId);
      return path;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onSend() async {
    final path = await _renderAndSave();
    if (path != null && mounted) {
      Navigator.pop(context, path);
    }
  }

  void _onSave() async {
    final path = await _renderAndSave();
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drawing saved to gallery!')),
      );
    }
  }

  void _onClear() async {
    if (!_hasStrokes) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear drawing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _strokes.clear();
        _current = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop()) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Draw something!',
              style: TextStyle(fontSize: 18, color: Colors.white)),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Canvas
            Expanded(
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _current = _Stroke(color: _color, width: _strokeWidth);
                    _current!.points.add(details.localPosition);
                  });
                },
                onPanUpdate: (details) {
                  if (_current != null) {
                    setState(() {
                      _current!.points.add(details.localPosition);
                    });
                  }
                },
                onPanEnd: (_) {
                  if (_current != null) {
                    setState(() {
                      _strokes.add(_current!);
                      _current = null;
                    });
                  }
                },
                child: CustomPaint(
                  key: _canvasKey,
                  painter: _DrawingPainter(
                    strokes: _strokes,
                    current: _current,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Colors.black),

            // Toolbar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Color picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _colors.map((c) {
                      final selected = _color == c;
                      return GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.black : const Color(0xFF666666),
                              width: selected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Stroke width + actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Stroke widths
                      ..._widths.map((w) {
                        final selected = _strokeWidth == w;
                        return GestureDetector(
                          onTap: () => setState(() => _strokeWidth = w),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    selected ? Colors.black : const Color(0xFF666666),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: w + 2,
                                height: w + 2,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Undo
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.black),
                        onPressed: _strokes.isEmpty
                            ? null
                            : () => setState(() => _strokes.removeLast()),
                        tooltip: 'Undo',
                      ),

                      // Clear
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.black),
                        onPressed: _hasStrokes ? _onClear : null,
                        tooltip: 'Clear',
                      ),

                      // Save
                      IconButton(
                        icon: const Icon(Icons.save_alt, color: Colors.black),
                        onPressed:
                            _hasStrokes && !_saving ? _onSave : null,
                        tooltip: 'Save',
                      ),

                      // Send
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Material(
                          color: _hasStrokes && !_saving
                              ? Colors.black
                              : const Color(0xFF444444),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap:
                                _hasStrokes && !_saving ? _onSend : null,
                            child: const Icon(Icons.send,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? current;

  _DrawingPainter({required this.strokes, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, if (current != null) current!]) {
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
  bool shouldRepaint(covariant _DrawingPainter old) => true;
}
