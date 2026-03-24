import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stroke.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../widgets/color_picker.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/stroke_picker.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<Stroke> _strokes = [];
  final GlobalKey _canvasKey = GlobalKey();
  Stroke? _current;
  Color _color = Colors.black;
  double _strokeWidth = 6.0;
  bool _saving = false;

  bool get _hasStrokes => _strokes.isNotEmpty || _current != null;

  Future<String?> _renderAndSave() async {
    if (!_hasStrokes) return null;
    setState(() => _saving = true);

    try {
      const size = Size(1024, 1024);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Offset.zero & size);

      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white,
      );

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
      final name = 'kazyka_${DateTime.now().microsecondsSinceEpoch}';
      return StorageService.saveDrawing(bytes, name);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onSave() async {
    final path = await _renderAndSave();
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drawing saved!'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _onNew() async {
    if (!_hasStrokes) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New drawing?'),
        content: const Text('Save the current drawing first?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child:
                const Text('Discard', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save & New',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (result == null || result == 'cancel') return;
    if (result == 'save') {
      final path = await _renderAndSave();
      if (path == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save drawing')),
        );
        return;
      }
    }
    setState(() {
      _strokes.clear();
      _current = null;
    });
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
    return Scaffold(
      appBar: AppBar(
        title: Consumer<SettingsService>(
          builder: (_, settings, _) {
            final name = settings.name;
            return Text(
              name.isEmpty ? 'Kazyka' : '$name\'s Kazyka',
              style: const TextStyle(fontSize: 20, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GalleryScreen()),
              );
            },
            tooltip: 'Gallery',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas
          Expanded(
            child: GestureDetector(
              key: _canvasKey,
              onPanStart: (details) {
                setState(() {
                  _current = Stroke(color: _color, width: _strokeWidth);
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
              child: DrawingCanvas(
                strokes: _strokes,
                current: _current,
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
                ColorPicker(
                  selected: _color,
                  onChanged: (c) => setState(() => _color = c),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StrokePicker(
                      selected: _strokeWidth,
                      onChanged: (w) => setState(() => _strokeWidth = w),
                    ),
                    IconButton(
                      icon: const Icon(Icons.undo, color: Colors.black),
                      onPressed: _strokes.isEmpty
                          ? null
                          : () => setState(() => _strokes.removeLast()),
                      tooltip: 'Undo',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.black),
                      onPressed: _hasStrokes ? _onClear : null,
                      tooltip: 'Clear',
                    ),
                    IconButton(
                      icon: const Icon(Icons.note_add, color: Colors.black),
                      onPressed: _hasStrokes ? _onNew : null,
                      tooltip: 'New',
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Material(
                        color: _hasStrokes && !_saving
                            ? Colors.black
                            : Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _hasStrokes && !_saving ? _onSave : null,
                          child: const Icon(Icons.save,
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
    );
  }
}
