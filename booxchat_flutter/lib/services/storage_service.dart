import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static Directory? _imageDir;

  static Future<Directory> get imageDirectory async {
    if (_imageDir != null) return _imageDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _imageDir = Directory('${appDir.path}/images');
    if (!await _imageDir!.exists()) {
      await _imageDir!.create(recursive: true);
    }
    return _imageDir!;
  }

  /// Saves base64 image data to disk, returns the file path.
  static Future<String> saveImage(String base64Data, String messageId) async {
    final dir = await imageDirectory;
    final file = File('${dir.path}/$messageId.png');
    await file.writeAsBytes(base64Decode(base64Data));
    return file.path;
  }

  /// Deletes an image file if it exists.
  static Future<void> deleteImage(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
