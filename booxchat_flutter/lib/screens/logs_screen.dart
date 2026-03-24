import 'package:flutter/material.dart';
import '../services/log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel? _filter;

  List<LogEntry> get _filtered {
    final all = LogService.instance.entries.reversed.toList();
    if (_filter == null) return all;
    return all.where((e) => e.level == _filter).toList();
  }

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.debug => Colors.grey,
        LogLevel.info => Colors.black,
        LogLevel.warn => Colors.amber.shade800,
        LogLevel.error => Colors.red,
      };

  String _levelLabel(LogLevel level) => switch (level) {
        LogLevel.debug => 'DBG',
        LogLevel.info => 'INF',
        LogLevel.warn => 'WRN',
        LogLevel.error => 'ERR',
      };

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('Logs (${entries.length})',
            style: const TextStyle(fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                _chip('All', null),
                _chip('Debug', LogLevel.debug),
                _chip('Info', LogLevel.info),
                _chip('Warn', LogLevel.warn),
                _chip('Error', LogLevel.error),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black26),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('No logs yet',
                        style: TextStyle(fontSize: 16, color: Colors.black54)))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      final time =
                          '${e.timestamp.hour.toString().padLeft(2, '0')}:'
                          '${e.timestamp.minute.toString().padLeft(2, '0')}:'
                          '${e.timestamp.second.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(time,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    fontFamily: 'monospace')),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: _levelColor(e.level).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(_levelLabel(e.level),
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _levelColor(e.level))),
                            ),
                            const SizedBox(width: 6),
                            Text('${e.source} ',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                            Expanded(
                              child: Text(e.message,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black87)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, LogLevel? level) {
    final selected = _filter == level;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _filter = level),
        selectedColor: Colors.black12,
        checkmarkColor: Colors.black,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: selected ? Colors.black : Colors.black26),
      ),
    );
  }
}
