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
}

class LogService {
  LogService._();
  static final instance = LogService._();

  static const _maxEntries = 500;
  final _entries = <LogEntry>[];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(LogLevel level, String source, String message) {
    _entries.add(LogEntry(level: level, source: source, message: message));
    if (_entries.length > _maxEntries) _entries.removeAt(0);
  }

  void debug(String source, String msg) => log(LogLevel.debug, source, msg);
  void info(String source, String msg) => log(LogLevel.info, source, msg);
  void warn(String source, String msg) => log(LogLevel.warn, source, msg);
  void error(String source, String msg) => log(LogLevel.error, source, msg);
}
