import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/canvas_item.dart';
import '../models/drawing_document.dart';
import '../utils/flood_fill.dart';
import '../providers/live_session_provider.dart';
import '../services/device_identity_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../controllers/ota_controller.dart';
import '../widgets/brush_picker.dart';
import '../widgets/color_picker.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/ota_menu_footer.dart';
import '../widgets/session_status_banner.dart';
import '../widgets/stroke_picker.dart';
import '../widgets/text_tool_dialog.dart';
import 'custom_color_screen.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

enum _Tool { pen, text, fill, hand }

class DrawingScreen extends StatefulWidget {
  /// Optional document to load for editing (from gallery reopen).
  final DrawingDocument? initialDocument;

  /// Optional background image path (for legacy PNG-only gallery files).
  final String? backgroundImagePath;

  const DrawingScreen({
    super.key,
    this.initialDocument,
    this.backgroundImagePath,
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<CanvasStroke> _strokes = [];
  final List<CanvasText> _texts = [];
  final List<CanvasFill> _fills = [];
  ActiveStroke? _activeStroke;
  ui.Image? _fillBitmap; // cached fill result
  int _strokeCountAtLastFill = 0;
  bool _filling = false;

  // Undo/redo stack — stores removed items for redo
  final List<Object> _redoStack = []; // CanvasStroke | CanvasText | CanvasFill
  Color _color = Colors.black;
  Color? _customColor;
  double _strokeWidth = 4.0;
  BrushType _brushType = BrushType.round;
  _Tool _tool = _Tool.pen;
  bool _saving = false;

  // Virtual canvas
  int _canvasSize = 2048;
  Size get _virtualSize => Size(_canvasSize.toDouble(), _canvasSize.toDouble());

  // Background reference image (for legacy PNG-only files opened from gallery)
  ui.Image? _backgroundImage;
  bool get _isLegacyEdit => widget.backgroundImagePath != null;
  bool get _isDocumentEdit => widget.initialDocument != null;

  // Viewport transform
  Offset _canvasOffset = Offset.zero;
  double _scale = 1.0;
  static const _minScale = 0.25;
  static const _maxScale = 4.0;

  // Gesture tracking
  Offset? _panStartOffset;
  double? _scaleStart;
  bool _isDrawing = false;

  @override
  void initState() {
    super.initState();

    // Load initial document if editing from gallery
    if (widget.initialDocument != null) {
      final doc = widget.initialDocument!;
      _canvasSize = doc.canvasSize;
      _strokes.addAll(doc.strokes);
      _texts.addAll(doc.texts);
      _fills.addAll(doc.fills);
      if (doc.fills.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildFillBitmap());
      }
    }

    // Load background image for legacy PNG edit
    if (widget.backgroundImagePath != null) {
      _loadBackgroundImage(widget.backgroundImagePath!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Init canvas size from settings (only for new drawings)
      if (!_isDocumentEdit && !_isLegacyEdit) {
        final settings = context.read<SettingsService>();
        setState(() => _canvasSize = settings.defaultCanvasSize);
      }

      // Wire up remote clear callback
      final session = context.read<LiveSessionProvider>();
      session.onRemoteClear = () {
        if (mounted) {
          setState(() {
            _strokes.clear();
            _texts.clear();
            _fills.clear();
            _activeStroke = null;
            _fillBitmap = null;
            _strokeCountAtLastFill = 0;
          });
        }
      };

      // Adopt session canvas size if in live mode
      if (session.sessionCanvasSize != null) {
        setState(() => _canvasSize = session.sessionCanvasSize!);
      }
    });
  }

  Future<void> _loadBackgroundImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _backgroundImage = frame.image);
    }
  }

  bool get _hasContent =>
      _strokes.isNotEmpty || _texts.isNotEmpty || _fills.isNotEmpty || _activeStroke != null;

  /// Convert screen point to virtual-canvas coordinates.
  Offset _screenToCanvas(Offset screen) =>
      (screen - _canvasOffset) / _scale;

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    _panStartOffset = _canvasOffset;
    _scaleStart = _scale;

    if (_tool == _Tool.pen && details.pointerCount == 1) {
      // Start drawing
      _isDrawing = true;
      final canvasPoint = _screenToCanvas(details.localFocalPoint);
      setState(() {
        _activeStroke = ActiveStroke(color: _color, width: _strokeWidth, brushType: _brushType);
        _activeStroke!.points.add(canvasPoint);
      });
    } else {
      _isDrawing = false;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isDrawing && _tool == _Tool.pen && details.pointerCount == 1) {
      // Continue drawing
      final canvasPoint = _screenToCanvas(details.localFocalPoint);
      setState(() => _activeStroke?.points.add(canvasPoint));
      return;
    }

    if (_isDrawing && details.pointerCount > 1) {
      // User added a second finger — abort drawing, switch to zoom
      _isDrawing = false;
      setState(() => _activeStroke = null);
    }

    // Pan + zoom
    setState(() {
      if (details.scale != 1.0 && _scaleStart != null) {
        final newScale =
            (_scaleStart! * details.scale).clamp(_minScale, _maxScale);
        final focal = details.localFocalPoint;
        _canvasOffset =
            focal - (focal - _panStartOffset!) * (newScale / _scaleStart!);
        _scale = newScale;
      } else if (_tool == _Tool.hand || details.pointerCount > 1) {
        _canvasOffset += details.focalPointDelta;
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails _) {
    if (_isDrawing && _activeStroke != null) {
      _commitActiveStroke();
    }
    _isDrawing = false;
    _panStartOffset = null;
    _scaleStart = null;
  }

  void _onTapUp(TapUpDetails details) {
    if (_tool == _Tool.text) {
      _placeText(details.localPosition);
    } else if (_tool == _Tool.fill) {
      _performFill(details.localPosition);
    }
    // Pen dots are handled by _onScaleStart → _onScaleEnd (single-point ActiveStroke)
  }

  void _commitActiveStroke() {
    if (_activeStroke == null || _activeStroke!.points.isEmpty) return;

    final normalized = _activeStroke!.points
        .map((p) => CanvasStroke.normalize(p, _virtualSize))
        .toList();
    final authorId = context.read<DeviceIdentityService>().deviceId;
    final stroke = CanvasStroke(
      authorId: authorId,
      colorValue: _activeStroke!.color.toARGB32(),
      width: _activeStroke!.width,
      brushType: _activeStroke!.brushType,
      points: normalized,
    );
    setState(() {
      _strokes.add(stroke);
      _activeStroke = null;
      _redoStack.clear();
    });

    final session = context.read<LiveSessionProvider>();
    if (session.isLive) {
      session.sendStrokeStart(stroke);
      session.sendStrokePoints(stroke.id, stroke.points);
      session.sendStrokeEnd(stroke.id);
    }
  }

  void _placeText(Offset screenPos) async {
    final authorId = context.read<DeviceIdentityService>().deviceId;
    final canvasPoint = _screenToCanvas(screenPos);

    final text = await showDialog<String>(
      context: context,
      builder: (_) => TextToolDialog(color: _color),
    );
    if (text == null || text.isEmpty || !mounted) return;

    final canvasText = CanvasText(
      authorId: authorId,
      text: text,
      colorValue: _color.toARGB32(),
      x: canvasPoint.dx / _virtualSize.width,
      y: canvasPoint.dy / _virtualSize.height,
    );
    setState(() {
      _texts.add(canvasText);
      _redoStack.clear();
    });

    final session = context.read<LiveSessionProvider>();
    if (session.isLive) {
      session.sendTextAdd(canvasText);
    }
  }

  // ---------------------------------------------------------------------------
  // Fill tool
  // ---------------------------------------------------------------------------

  Future<void> _performFill(Offset screenPos) async {
    if (_filling) return;
    setState(() => _filling = true);

    try {
      final canvasPoint = _screenToCanvas(screenPos);
      final authorId = context.read<DeviceIdentityService>().deviceId;
      final fill = CanvasFill(
        authorId: authorId,
        colorValue: _color.toARGB32(),
        x: canvasPoint.dx / _virtualSize.width,
        y: canvasPoint.dy / _virtualSize.height,
      );

      setState(() {
        _fills.add(fill);
        _redoStack.clear();
      });
      await _rebuildFillBitmap();

      // Send to peer in live mode
      if (mounted) {
        final session = context.read<LiveSessionProvider>();
        if (session.isLive) {
          session.sendFill(fill);
        }
      }
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  /// Rebuild the cached fill bitmap by replaying all fills on the current canvas.
  Future<void> _rebuildFillBitmap() async {
    if (_fills.isEmpty) {
      setState(() {
        _fillBitmap = null;
        _strokeCountAtLastFill = 0;
      });
      return;
    }

    // Render current strokes to a bitmap (without fills)
    final sz = _virtualSize;
    final w = sz.width.toInt();
    final h = sz.height.toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & sz);
    canvas.drawRect(Offset.zero & sz, Paint()..color = Colors.white);

    // Draw background image if present
    if (_backgroundImage != null) {
      final src = Rect.fromLTWH(0, 0, _backgroundImage!.width.toDouble(),
          _backgroundImage!.height.toDouble());
      canvas.drawImageRect(_backgroundImage!, src, Offset.zero & sz, Paint());
    }

    // Render strokes without anti-aliasing for crisp fill boundaries
    for (final stroke in _strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = _brushPaint(stroke.color, stroke.width, stroke.brushType)
        ..isAntiAlias = false;
      final pts = stroke.points
          .map((p) => CanvasStroke.denormalize(p, sz))
          .toList();
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, stroke.width / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path();
        path.moveTo(pts.first.dx, pts.first.dy);
        for (var i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        paint.style = PaintingStyle.stroke;
        canvas.drawPath(path, paint);
      }
    }

    _strokeCountAtLastFill = _strokes.length;

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    // Convert RGBA to ARGB pixel buffer
    final rgba = byteData.buffer.asUint8List();
    final argb = Uint32List(w * h);
    for (var i = 0; i < w * h; i++) {
      final r = rgba[i * 4];
      final g = rgba[i * 4 + 1];
      final b = rgba[i * 4 + 2];
      final a = rgba[i * 4 + 3];
      argb[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }

    // Replay all fills
    var pixels = argb;
    for (final fill in _fills) {
      final fx = (fill.x * w).round().clamp(0, w - 1);
      final fy = (fill.y * h).round().clamp(0, h - 1);
      pixels = await compute(floodFill, FloodFillParams(
        pixels: pixels,
        width: w,
        height: h,
        startX: fx,
        startY: fy,
        fillColor: fill.colorValue,
        tolerance: fill.tolerance,
      ));
    }

    // Convert ARGB back to RGBA for ui.Image
    final outRgba = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      outRgba[i * 4] = (pixels[i] >> 16) & 0xFF; // R
      outRgba[i * 4 + 1] = (pixels[i] >> 8) & 0xFF; // G
      outRgba[i * 4 + 2] = pixels[i] & 0xFF; // B
      outRgba[i * 4 + 3] = (pixels[i] >> 24) & 0xFF; // A
    }

    final codec = await ui.ImageDescriptor.raw(
      await ui.ImmutableBuffer.fromUint8List(outRgba),
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    ).instantiateCodec();
    final frame = await codec.getNextFrame();

    if (mounted) {
      setState(() => _fillBitmap = frame.image);
    }
  }

  // ---------------------------------------------------------------------------
  // Zoom controls
  // ---------------------------------------------------------------------------

  void _zoomIn() {
    setState(() => _scale = (_scale * 1.5).clamp(_minScale, _maxScale));
  }

  void _zoomOut() {
    setState(() => _scale = (_scale / 1.5).clamp(_minScale, _maxScale));
  }

  void _zoomReset() {
    setState(() {
      _scale = 1.0;
      _canvasOffset = Offset.zero;
    });
  }

  // ---------------------------------------------------------------------------
  // Custom color picker
  // ---------------------------------------------------------------------------

  void _openCustomColorPicker() async {
    final result = await Navigator.push<Color>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomColorScreen(initialColor: _customColor ?? _color),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _customColor = result;
        _color = result;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Save / New / Clear / Undo
  // ---------------------------------------------------------------------------

  Future<String?> _renderAndSave() async {
    if (!_hasContent) return null;
    setState(() => _saving = true);

    try {
      final exportSize = _virtualSize;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Offset.zero & exportSize);

      // Include remote strokes/texts in live mode
      final session = context.read<LiveSessionProvider>();
      final allStrokes = [..._strokes, ...session.remoteStrokes];
      final allTexts = [..._texts, ...session.remoteTexts];

      if (_fillBitmap != null) {
        // Fill bitmap contains pre-fill strokes + fills
        final src = Rect.fromLTWH(0, 0, _fillBitmap!.width.toDouble(),
            _fillBitmap!.height.toDouble());
        canvas.drawImageRect(_fillBitmap!, src, Offset.zero & exportSize, Paint());

        // Render post-fill strokes
        for (var si = _strokeCountAtLastFill; si < allStrokes.length; si++) {
          final stroke = allStrokes[si];
          if (stroke.points.isEmpty) continue;
          final paint = _brushPaint(stroke.color, stroke.width, stroke.brushType);
          final pts = stroke.points
              .map((p) => CanvasStroke.denormalize(p, exportSize))
              .toList();
          if (pts.length == 1) {
            canvas.drawCircle(
                pts.first, stroke.width / 2, paint..style = PaintingStyle.fill);
            continue;
          }
          final path = Path();
          path.moveTo(pts.first.dx, pts.first.dy);
          for (var j = 1; j < pts.length; j++) {
            path.lineTo(pts[j].dx, pts[j].dy);
          }
          paint.style = PaintingStyle.stroke;
          canvas.drawPath(path, paint);
        }
      } else {
        canvas.drawRect(
            Offset.zero & exportSize, Paint()..color = Colors.white);

        for (final stroke in allStrokes) {
          if (stroke.points.isEmpty) continue;
          final paint = _brushPaint(stroke.color, stroke.width, stroke.brushType);
          final pts = stroke.points
              .map((p) => CanvasStroke.denormalize(p, exportSize))
              .toList();
          if (pts.length == 1) {
            canvas.drawCircle(
                pts.first, stroke.width / 2, paint..style = PaintingStyle.fill);
            continue;
          }
          final path = Path();
          path.moveTo(pts.first.dx, pts.first.dy);
          for (var i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].dx, pts[i].dy);
          }
          paint.style = PaintingStyle.stroke;
          canvas.drawPath(path, paint);
        }
      }

      for (final t in allTexts) {
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
      final doc = DrawingDocument(
        canvasSize: _canvasSize,
        strokes: allStrokes,
        texts: allTexts,
        fills: _fills,
      );
      return StorageService.saveDrawingBundle(
        pngBytes: bytes,
        name: name,
        document: doc,
      );
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
      _fills.clear();
      _activeStroke = null;
      _fillBitmap = null;
      _strokeCountAtLastFill = 0;
      _canvasOffset = Offset.zero;
      _scale = 1.0;
      // Re-read default canvas size for new drawing
      _canvasSize = context.read<SettingsService>().defaultCanvasSize;
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
        _fills.clear();
        _activeStroke = null;
        _fillBitmap = null;
        _strokeCountAtLastFill = 0;
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
      final myStrokes = live
          ? _strokes.where((s) => s.authorId == localId).toList()
          : _strokes;
      final myTexts = live
          ? _texts.where((t) => t.authorId == localId).toList()
          : _texts;
      final myFills = live
          ? _fills.where((f) => f.authorId == localId).toList()
          : _fills;

      final candidates = <int, Object Function()>{};
      if (myStrokes.isNotEmpty) {
        candidates[myStrokes.last.createdAt] = () {
          final item = myStrokes.last;
          _strokes.remove(item);
          return item;
        };
      }
      if (myTexts.isNotEmpty) {
        candidates[myTexts.last.createdAt] = () {
          final item = myTexts.last;
          _texts.remove(item);
          return item;
        };
      }
      if (myFills.isNotEmpty) {
        candidates[myFills.last.createdAt] = () {
          final item = myFills.last;
          _fills.remove(item);
          return item;
        };
      }

      if (candidates.isEmpty) return;
      final newest = candidates.keys.reduce((a, b) => a > b ? a : b);
      final removed = candidates[newest]!();
      _redoStack.add(removed);
    });

    if (_fills.isNotEmpty || _fillBitmap != null) {
      _rebuildFillBitmap();
    }
  }

  void _onRedo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      final item = _redoStack.removeLast();
      if (item is CanvasStroke) {
        _strokes.add(item);
      } else if (item is CanvasText) {
        _texts.add(item);
      } else if (item is CanvasFill) {
        _fills.add(item);
      }
    });

    if (_fills.isNotEmpty || _fillBitmap != null) {
      _rebuildFillBitmap();
    }
  }

  static Paint _brushPaint(Color color, double width, BrushType brush) {
    final paint = Paint()..strokeWidth = width..style = PaintingStyle.stroke;
    switch (brush) {
      case BrushType.round:
        paint..color = color..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      case BrushType.flat:
        paint..color = color..strokeCap = StrokeCap.square..strokeJoin = StrokeJoin.bevel;
      case BrushType.marker:
        paint..color = color.withAlpha(100)..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      case BrushType.crayon:
        paint..color = color..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    }
    return paint;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: Colors.white,
        actions: [
          // Undo + Redo
          IconButton(
            icon: Icon(Icons.undo,
                color: (_strokes.isEmpty && _texts.isEmpty && _fills.isEmpty)
                    ? const Color(0xFF999999)
                    : Colors.black),
            onPressed: (_strokes.isEmpty && _texts.isEmpty && _fills.isEmpty) ? null : _onUndo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: Icon(Icons.redo,
                color: _redoStack.isEmpty
                    ? const Color(0xFF999999)
                    : Colors.black),
            onPressed: _redoStack.isEmpty ? null : _onRedo,
            tooltip: 'Redo',
          ),
          // Clear + New (hidden in live mode)
          Consumer<LiveSessionProvider>(
            builder: (_, session, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!session.isLive)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.black),
                    onPressed: _hasContent ? _onClear : null,
                    tooltip: 'Clear',
                  ),
                if (!session.isLive)
                  IconButton(
                    icon: const Icon(Icons.note_add, color: Colors.black),
                    onPressed: _hasContent ? _onNew : null,
                    tooltip: 'New',
                  ),
              ],
            ),
          ),
          // Live
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
          // Save
          IconButton(
            icon: Icon(
              Icons.save,
              color: _hasContent && !_saving ? Colors.black : const Color(0xFF999999),
            ),
            onPressed: _hasContent && !_saving ? _onSave : null,
            tooltip: 'Save',
          ),
        ],
      ),
      drawer: _KazykaDrawer(otaController: otaController),
      body: Column(
        children: [
          const SessionStatusBanner(),

          // Canvas with gesture handling
          Expanded(
            child: ClipRect(
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                onTapUp: _onTapUp,
                child: Consumer<LiveSessionProvider>(
                  builder: (_, session, _) => DrawingCanvas(
                    strokes: [..._strokes, ...session.remoteStrokes],
                    texts: [..._texts, ...session.remoteTexts],
                    activeStroke: _activeStroke,
                    virtualSize: _virtualSize,
                    offset: _canvasOffset,
                    scale: _scale,
                    backgroundImage: _backgroundImage,
                    fillBitmap: _fillBitmap,
                    bakedStrokeCount: _strokeCountAtLastFill,
                  ),
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
                  customColor: _customColor,
                  onCustomColorTap: _openCustomColorPicker,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Tool toggle: pen / text / hand
                    ToggleButtons(
                      isSelected: [
                        _tool == _Tool.pen,
                        _tool == _Tool.text,
                        _tool == _Tool.fill,
                        _tool == _Tool.hand,
                      ],
                      onPressed: (i) => setState(() =>
                          _tool = _Tool.values[i]),
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
                        Icon(Icons.format_color_fill, size: 28),
                        Icon(Icons.open_with, size: 28),
                      ],
                    ),

                    if (_tool == _Tool.pen) ...[
                      StrokePicker(
                        selected: _strokeWidth,
                        onChanged: (w) =>
                            setState(() => _strokeWidth = w),
                      ),
                      const SizedBox(width: 4),
                      BrushPicker(
                        selected: _brushType,
                        onChanged: (b) =>
                            setState(() => _brushType = b),
                      ),
                    ],

                    // Zoom controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.remove, size: 22),
                            onPressed: _zoomOut,
                            tooltip: 'Zoom out',
                          ),
                        ),
                        GestureDetector(
                          onTap: _zoomReset,
                          child: SizedBox(
                            width: 44,
                            child: Text(
                              '${(_scale * 100).round()}%',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.add, size: 22),
                            onPressed: _zoomIn,
                            tooltip: 'Zoom in',
                          ),
                        ),
                      ],
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
            OtaMenuFooter(controller: widget.otaController),
          ],
        ),
      ),
    );
  }
}
