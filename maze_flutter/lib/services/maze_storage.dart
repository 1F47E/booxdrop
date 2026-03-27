import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import '../models/maze.dart';

class MazeStorage {
  static Future<Directory> _dir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/mazes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<SavedMaze> save(String name, List<List<int>> cells) async {
    final dir = await _dir();
    final r = Random.secure();
    final suffix = List.generate(4, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final id = '${DateTime.now().millisecondsSinceEpoch}_$suffix';
    final maze = SavedMaze(
      id: id,
      name: name,
      cells: cells,
      createdAt: DateTime.now(),
    );
    final file = File('${dir.path}/$id.json');
    await file.writeAsString(jsonEncode(maze.toJson()));
    return maze;
  }

  static Future<List<SavedMaze>> loadAll() async {
    final dir = await _dir();
    final files = await dir.list().where((f) => f.path.endsWith('.json')).toList();

    final mazes = <SavedMaze>[];
    for (final f in files) {
      try {
        final content = await File(f.path).readAsString();
        mazes.add(SavedMaze.fromJson(jsonDecode(content) as Map<String, dynamic>));
      } catch (_) {
        // skip corrupt files
      }
    }

    // Sort newest first
    mazes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mazes;
  }

  static Future<void> delete(String id) async {
    final dir = await _dir();
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) await file.delete();
  }
}
