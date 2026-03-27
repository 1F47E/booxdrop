import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/canvas_item.dart';
import '../providers/live_session_provider.dart';
import '../services/device_identity_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../controllers/ota_controller.dart';
import '../widgets/color_picker.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/ota_menu_footer.dart';
import '../widgets/session_status_banner.dart';
import '../widgets/stroke_picker.dart';
import '../widgets/text_tool_dialog.dart';
import 'gallery_screen.dart';
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
    final authorId = context.read<DeviceIdentityService>().deviceId;
    final stroke = CanvasStroke(
      authorId: authorId,
      colorValue: _activeStroke!.color.toARGB32(),
      width: _activeStroke!.width,
      points: normalized,
    );
    setState(() {
      _strokes.add(stroke);
      _activeStroke = null;
    });

    // Send to peer in live mode
    final session = context.read<LiveSessionProvider>();
    if (session.isLive) {
      session.sendStrokeStart(stroke);
      session.sendStrokePoints(stroke.id, stroke.points);
      session.sendStrokeEnd(stroke.id);
    }
  }

  void _onCanvasTap(TapUpDetails details) async {
    if (_tool != _Tool.text) return;

    final authorId = context.read<DeviceIdentityService>().deviceId;
    final size = _canvasSize;

    final text = await showDialog<String>(
      context: context,
      builder: (_) => TextToolDialog(color: _color),
    );
    if (text == null || text.isEmpty || !mounted) return;
    if (size == null) return;

    final canvasText = CanvasText(
      authorId: authorId,
      text: text,
      colorValue: _color.toARGB32(),
      x: details.localPosition.dx / size.width,
      y: details.localPosition.dy / size.height,
    );
    setState(() => _texts.add(canvasText));

    // Send to peer in live mode
    final session = context.read<LiveSessionProvider>();
    if (session.isLive) {
      session.sendTextAdd(canvasText);
    }
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

  void _onLivePressed() {
    final identity = context.read<DeviceIdentityService>();
    final session = context.read<LiveSessionProvider>();
    session.connectAuto(
      deviceId: identity.deviceId,
      displayName: identity.displayName,
      serverUrl: 'wss://booxchat.mos6581.cc/ws/live',
    );
  }

  void _onUndo() {
    final session = context.read<LiveSessionProvider>();
    final live = session.isLive;
    final localId = live
        ? context.read<DeviceIdentityService>().deviceId
        : null;

    setState(() {
      // In live mode, only undo items authored by this device
      final myStrokes = live
          ? _strokes.where((s) => s.authorId == localId).toList()
          : _strokes;
      final myTexts = live
          ? _texts.where((t) => t.authorId == localId).toList()
          : _texts;

      if (myStrokes.isEmpty && myTexts.isEmpty) return;
      if (myTexts.isEmpty) {
        _strokes.remove(myStrokes.last);
        return;
      }
      if (myStrokes.isEmpty) {
        _texts.remove(myTexts.last);
        return;
      }
      if (myStrokes.last.createdAt >= myTexts.last.createdAt) {
        _strokes.remove(myStrokes.last);
      } else {
        _texts.remove(myTexts.last);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final otaController = context.read<OtaController>();
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Consumer<SettingsService>(
          builder: (_, settings, _) {
            final name = settings.name;
            return Text(
              name.isEmpty ? 'Kazyka' : '$name\'s Kazyka',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: Colors.white,
        actions: [
          Consumer<LiveSessionProvider>(
            builder: (_, session, _) => TextButton(
              onPressed: session.isLive ? null : _onLivePressed,
              child: Text(
                session.isLive ? 'LIVE' : 'Live',
                style: TextStyle(
                  color: session.isLive ? Colors.green : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _KazykaDrawer(otaController: otaController),
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
              child: Consumer<LiveSessionProvider>(
                builder: (_, session, _) => DrawingCanvas(
                  strokes: [..._strokes, ...session.remoteStrokes],
                  texts: [..._texts, ...session.remoteTexts],
                  activeStroke: _activeStroke,
                ),
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
                      borderColor: const Color(0xFF666666),
                      selectedBorderColor: Colors.black,
                      selectedColor: Colors.white,
                      fillColor: Colors.black,
                      color: Colors.black,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      children: const [
                        Icon(Icons.edit, size: 28),
                        Icon(Icons.text_fields, size: 28),
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
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.undo,
                                  color: Colors.black),
                              onPressed:
                                  (_strokes.isEmpty && _texts.isEmpty)
                                      ? null
                                      : _onUndo,
                              tooltip: 'Undo',
                            ),
                            if (!live)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.black),
                                onPressed:
                                    _hasContent ? _onClear : null,
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
                            : const Color(0xFF444444),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap:
                              _hasContent && !_saving ? _onSave : null,
                          child: const Icon(Icons.save,
                              color: Colors.white, size: 28),
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

class _KazykaDrawer extends StatefulWidget {
  final OtaController otaController;
  const _KazykaDrawer({required this.otaController});

  @override
  State<_KazykaDrawer> createState() => _KazykaDrawerState();
}

class _KazykaDrawerState extends State<_KazykaDrawer> {
  @override
  void initState() {
    super.initState();
    widget.otaController.onMenuOpened();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kazyka',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.black),
              title: const Text('Gallery',
                  style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GalleryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.black),
              title: const Text('Settings',
                  style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),

            const Spacer(),

            // OTA update footer
            OtaMenuFooter(controller: widget.otaController),
          ],
        ),
      ),
    );
  }
}
