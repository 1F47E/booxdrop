import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/canvas_item.dart';
import '../providers/live_session_provider.dart';
import '../services/device_identity_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../widgets/color_picker.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/session_status_banner.dart';
import '../widgets/stroke_picker.dart';
import '../widgets/text_tool_dialog.dart';
import 'gallery_screen.dart';
import 'live_session_sheet.dart';
import 'settings_screen.dart';

enum _Tool { pen, text }

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<CanvasStroke> _strokes = [];
  final List<CanvasText> _texts = [];
  final GlobalKey _canvasKey = GlobalKey();
  ActiveStroke? _activeStroke;
  Color _color = Colors.black;
  double _strokeWidth = 6.0;
  _Tool _tool = _Tool.pen;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Wire up remote clear callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<LiveSessionProvider>();
      session.onRemoteClear = () {
        if (mounted) {
          setState(() {
            _strokes.clear();
            _texts.clear();
            _activeStroke = null;
          });
        }
      };
    });
  }

  bool get _hasContent =>
      _strokes.isNotEmpty || _texts.isNotEmpty || _activeStroke != null;

  Size? get _canvasSize {
    final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return rb?.size;
  }

  void _onPanStart(DragStartDetails details) {
    if (_tool != _Tool.pen) return;
    setState(() {
      _activeStroke = ActiveStroke(color: _color, width: _strokeWidth);
      _activeStroke!.points.add(details.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_activeStroke == null) return;
    setState(() => _activeStroke!.points.add(details.localPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    if (_activeStroke == null) return;
    final size = _canvasSize;
    if (size == null) return;

    // Convert active stroke to normalized CanvasStroke
    final normalized = _activeStroke!.points
        .map((p) => CanvasStroke.normalize(p, size))
        .toList();
    setState(() {
      _strokes.add(CanvasStroke(
        colorValue: _activeStroke!.color.toARGB32(),
        width: _activeStroke!.width,
        points: normalized,
      ));
      _activeStroke = null;
    });
  }

  void _onCanvasTap(TapUpDetails details) async {
    if (_tool != _Tool.text) return;

    final text = await showDialog<String>(
      context: context,
      builder: (_) => TextToolDialog(color: _color),
    );
    if (text == null || text.isEmpty) return;

    final size = _canvasSize;
    if (size == null) return;

    setState(() {
      _texts.add(CanvasText(
        text: text,
        colorValue: _color.toARGB32(),
        x: details.localPosition.dx / size.width,
        y: details.localPosition.dy / size.height,
      ));
    });
  }

  Future<String?> _renderAndSave() async {
    if (!_hasContent) return null;
    setState(() => _saving = true);

    try {
      const exportSize = Size(1024, 1024);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Offset.zero & exportSize);

      canvas.drawRect(
          Offset.zero & exportSize, Paint()..color = Colors.white);

      // Render strokes (already normalized)
      for (final stroke in _strokes) {
        if (stroke.points.isEmpty) continue;
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        if (stroke.points.length == 1) {
          final pt = CanvasStroke.denormalize(stroke.points.first, exportSize);
          canvas.drawCircle(
              pt, stroke.width / 2, paint..style = PaintingStyle.fill);
          continue;
        }

        final path = Path();
        final first =
            CanvasStroke.denormalize(stroke.points.first, exportSize);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < stroke.points.length; i++) {
          final pt = CanvasStroke.denormalize(stroke.points[i], exportSize);
          path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path, paint);
      }

      // Render text items
      for (final t in _texts) {
        final offset =
            Offset(t.x * exportSize.width, t.y * exportSize.height);
        final tp = TextPainter(
          text: TextSpan(
            text: t.text,
            style: TextStyle(color: t.color, fontSize: t.fontSize),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, offset);
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(
          exportSize.width.toInt(), exportSize.height.toInt());
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
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
            content: Text('Drawing saved!'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _onNew() async {
    if (!_hasContent) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New drawing?'),
        content: const Text('Save the current drawing first?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard',
                style: TextStyle(color: Colors.black)),
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
      _texts.clear();
      _activeStroke = null;
    });
  }

  void _onClear() async {
    if (!_hasContent) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear drawing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Clear', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _strokes.clear();
        _texts.clear();
        _activeStroke = null;
      });
    }
  }

  void _openLiveSheet() async {
    final identity = context.read<DeviceIdentityService>();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (_) => LiveSessionSheet(identity: identity),
    );
    if (result == null || !mounted) return;

    final session = context.read<LiveSessionProvider>();
    const serverUrl = 'ws://localhost:8080/ws/live'; // TODO: configure

    if (result['action'] == 'create') {
      session.createSession(
        deviceId: identity.deviceId,
        displayName: identity.displayName,
        serverUrl: serverUrl,
      );
    } else if (result['action'] == 'join') {
      session.joinSession(
        code: result['code'] as String,
        deviceId: identity.deviceId,
        displayName: identity.displayName,
        serverUrl: serverUrl,
      );
    }
  }

  void _onUndo() {
    setState(() {
      // Remove last item (stroke or text, whichever was added most recently)
      if (_strokes.isEmpty && _texts.isEmpty) return;
      if (_texts.isEmpty) {
        _strokes.removeLast();
        return;
      }
      if (_strokes.isEmpty) {
        _texts.removeLast();
        return;
      }
      // Remove whichever was created more recently
      if (_strokes.last.createdAt >= _texts.last.createdAt) {
        _strokes.removeLast();
      } else {
        _texts.removeLast();
      }
    });
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
          Consumer<LiveSessionProvider>(
            builder: (_, session, _) => TextButton(
              onPressed: session.isLive ? null : _openLiveSheet,
              child: Text(
                session.isLive ? 'LIVE' : 'Live',
                style: TextStyle(
                  color: session.isLive ? Colors.green : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GalleryScreen()));
            },
            tooltip: 'Gallery',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Live session banner
          const SessionStatusBanner(),

          // Canvas
          Expanded(
            child: GestureDetector(
              key: _canvasKey,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTapUp: _onCanvasTap,
              child: DrawingCanvas(
                strokes: _strokes,
                texts: _texts,
                activeStroke: _activeStroke,
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
                    // Tool toggle: pen / text
                    ToggleButtons(
                      isSelected: [
                        _tool == _Tool.pen,
                        _tool == _Tool.text
                      ],
                      onPressed: (i) => setState(
                          () => _tool = i == 0 ? _Tool.pen : _Tool.text),
                      borderColor: Colors.black26,
                      selectedBorderColor: Colors.black,
                      selectedColor: Colors.white,
                      fillColor: Colors.black,
                      color: Colors.black,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      children: const [
                        Icon(Icons.edit, size: 20),
                        Icon(Icons.text_fields, size: 20),
                      ],
                    ),

                    if (_tool == _Tool.pen)
                      StrokePicker(
                        selected: _strokeWidth,
                        onChanged: (w) =>
                            setState(() => _strokeWidth = w),
                      ),

                    Consumer<LiveSessionProvider>(
                      builder: (_, session, _) {
                        final live = session.isLive;
                        final canClear =
                            _hasContent && (!live || session.isHost);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.undo,
                                  color: Colors.black),
                              onPressed: live ||
                                      (_strokes.isEmpty && _texts.isEmpty)
                                  ? null
                                  : _onUndo,
                              tooltip: 'Undo',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.black),
                              onPressed: canClear
                                  ? () {
                                      _onClear();
                                      if (live) session.sendClear();
                                    }
                                  : null,
                              tooltip: 'Clear',
                            ),
                            if (!live)
                              IconButton(
                                icon: const Icon(Icons.note_add,
                                    color: Colors.black),
                                onPressed:
                                    _hasContent ? _onNew : null,
                                tooltip: 'New',
                              ),
                          ],
                        );
                      },
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Material(
                        color: _hasContent && !_saving
                            ? Colors.black
                            : Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap:
                              _hasContent && !_saving ? _onSave : null,
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
