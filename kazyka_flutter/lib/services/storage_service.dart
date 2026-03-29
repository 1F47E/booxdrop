import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/drawing_document.dart';

class StorageService {
  static Directory? _drawingsDir;

  static Future<Directory> get drawingsDirectory async {
    if (_drawingsDir != null && await _drawingsDir!.exists()) {
      return _drawingsDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    _drawingsDir = Directory('${appDir.path}/drawings');
    if (!await _drawingsDir!.exists()) {
      await _drawingsDir!.create(recursive: true);
    }
    return _drawingsDir!;
  }

  /// Save a PNG preview only (legacy).
  static Future<String> saveDrawing(List<int> pngBytes, String name) async {
    final dir = await drawingsDirectory;
    final file = File('${dir.path}/$name.png');
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  /// Save a drawing bundle: PNG preview + editable JSON sidecar.
  static Future<String> saveDrawingBundle({
    required List<int> pngBytes,
    required String name,
    required DrawingDocument document,
  }) async {
    final dir = await drawingsDirectory;
    final pngFile = File('${dir.path}/$name.png');
    final jsonFile = File('${dir.path}/$name.kazyka.json');
    await pngFile.writeAsBytes(pngBytes);
    await jsonFile.writeAsString(document.toJsonString());
    return pngFile.path;
  }

  /// Check if an editable sidecar exists for a PNG preview path.
  static Future<bool> hasEditableDocument(String pngPath) async {
    final sidecarPath = _sidecarPath(pngPath);
    return File(sidecarPath).exists();
  }

  /// Load the editable document for a PNG preview path.
  static Future<DrawingDocument?> loadDocument(String pngPath) async {
    final sidecarPath = _sidecarPath(pngPath);
    final file = File(sidecarPath);
    if (!await file.exists()) return null;
    final json = await file.readAsString();
    return DrawingDocument.fromJsonString(json);
  }

  static Future<List<File>> listDrawings() async {
    final dir = await drawingsDirectory;
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        files.add(entity);
      }
    }
    files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Delete a drawing and its sidecar if present.
  static Future<void> deleteDrawing(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
    // Also delete sidecar
    final sidecar = File(_sidecarPath(path));
    if (await sidecar.exists()) await sidecar.delete();
  }

  /// Convert a PNG path to its sidecar JSON path.
  /// e.g. `drawings/foo.png` → `drawings/foo.kazyka.json`
  static String _sidecarPath(String pngPath) {
    if (pngPath.endsWith('.png')) {
      return '${pngPath.substring(0, pngPath.length - 4)}.kazyka.json';
    }
    return '$pngPath.kazyka.json';
  }
}
