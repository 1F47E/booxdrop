import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static Directory? _imageDir;
  static Directory? _chatsDir;
  static Directory? _audioDir;

  static Future<Directory> get imageDirectory async {
    if (_imageDir != null && await _imageDir!.exists()) return _imageDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _imageDir = Directory('${appDir.path}/images');
    if (!await _imageDir!.exists()) {
      await _imageDir!.create(recursive: true);
    }
    return _imageDir!;
  }

  static Future<Directory> get chatsDirectory async {
    if (_chatsDir != null && await _chatsDir!.exists()) return _chatsDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _chatsDir = Directory('${appDir.path}/chats');
    if (!await _chatsDir!.exists()) {
      await _chatsDir!.create(recursive: true);
    }
    return _chatsDir!;
  }

  static Future<void> saveSessionIndex(String jsonString) async {
    final dir = await chatsDirectory;
    final file = File('${dir.path}/sessions.json');
    await file.writeAsString(jsonString);
  }

  static Future<String?> loadSessionIndex() async {
    final dir = await chatsDirectory;
    final file = File('${dir.path}/sessions.json');
    if (await file.exists()) return file.readAsString();
    return null;
  }

  static Future<void> saveSessionMessages(
      String sessionId, String jsonString) async {
    final dir = await chatsDirectory;
    final file = File('${dir.path}/$sessionId.json');
    await file.writeAsString(jsonString);
  }

  static Future<String?> loadSessionMessages(String sessionId) async {
    final dir = await chatsDirectory;
    final file = File('${dir.path}/$sessionId.json');
    if (await file.exists()) return file.readAsString();
    return null;
  }

  static Future<void> deleteSessionData(String sessionId) async {
    final dir = await chatsDirectory;
    final file = File('${dir.path}/$sessionId.json');
    if (await file.exists()) await file.delete();
  }

  static Future<Directory> get audioDirectory async {
    if (_audioDir != null && await _audioDir!.exists()) return _audioDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _audioDir = Directory('${appDir.path}/audio');
    if (!await _audioDir!.exists()) {
      await _audioDir!.create(recursive: true);
    }
    return _audioDir!;
  }

  /// Saves raw audio bytes to disk, returns the file path.
  static Future<String> saveAudio(List<int> bytes, String messageId) async {
    final dir = await audioDirectory;
    final file = File('${dir.path}/$messageId.mp3');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Returns all audio files sorted newest-first.
  static Future<List<File>> listAudio() async {
    final dir = await audioDirectory;
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.mp3')) {
        files.add(entity);
      }
    }
    files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Deletes an audio file if it exists.
  static Future<void> deleteAudio(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Saves base64 image data to disk, returns the file path.
  static Future<String> saveImage(String base64Data, String messageId) async {
    final dir = await imageDirectory;
    final file = File('${dir.path}/$messageId.png');
    await file.writeAsBytes(base64Decode(base64Data));
    return file.path;
  }

  /// Returns all image files sorted newest-first.
  static Future<List<File>> listImages() async {
    final dir = await imageDirectory;
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Deletes an image file if it exists.
  static Future<void> deleteImage(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
