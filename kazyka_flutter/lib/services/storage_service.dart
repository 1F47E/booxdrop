import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

  static Future<String> saveDrawing(List<int> pngBytes, String name) async {
    final dir = await drawingsDirectory;
    final file = File('${dir.path}/$name.png');
    await file.writeAsBytes(pngBytes);
    return file.path;
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

  static Future<void> deleteDrawing(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
