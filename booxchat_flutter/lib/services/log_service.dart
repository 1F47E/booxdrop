import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  LogEntry({
    required this.level,
    required this.source,
    required this.message,
  }) : timestamp = DateTime.now();

  String toLine() {
    final t = timestamp.toIso8601String().substring(11, 19);
    final l = level.name.toUpperCase().padRight(5);
    return '$t $l [$source] $message';
  }
}

class LogService {
  LogService._();
  static final instance = LogService._();

  static const _maxEntries = 500;
  final _entries = <LogEntry>[];
  File? _logFile;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  Future<void> _ensureFile() async {
    if (_logFile != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/app.log');
  }

  void log(LogLevel level, String source, String message) {
    final entry = LogEntry(level: level, source: source, message: message);
    _entries.add(entry);
    if (_entries.length > _maxEntries) _entries.removeAt(0);
    // Persist to file (fire-and-forget)
    _appendToFile(entry);
  }

  Future<void> _appendToFile(LogEntry entry) async {
    try {
      await _ensureFile();
      await _logFile!.writeAsString(
        '${entry.toLine()}\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Don't crash on log write failure
    }
  }

  /// Returns the log file path for adb pull.
  Future<String> get logFilePath async {
    await _ensureFile();
    return _logFile!.path;
  }

  void debug(String source, String msg) => log(LogLevel.debug, source, msg);
  void info(String source, String msg) => log(LogLevel.info, source, msg);
  void warn(String source, String msg) => log(LogLevel.warn, source, msg);
  void error(String source, String msg) => log(LogLevel.error, source, msg);
}
