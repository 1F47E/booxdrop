// lib/services/ndjson_codec.dart
//
// NDJSON (newline-delimited JSON) framing helper.
// Used by Bluetooth transports to frame messages over an RFCOMM stream.

import 'dart:convert';

/// Stateful NDJSON codec.
///
/// Call [encode] to produce a single wire line from a map.
/// Feed raw string chunks into [decode] — it accumulates partial lines and
/// returns every complete JSON object once it sees the terminating `\n`.
class NdjsonCodec {
  final _buffer = StringBuffer();

  /// Encode a map to an NDJSON line (JSON + newline).
  static String encode(Map<String, dynamic> msg) => '${jsonEncode(msg)}\n';

  /// Feed [chunk] (decoded from raw bytes) and return every complete message
  /// that has been accumulated so far.
  ///
  /// Empty lines are silently skipped. Malformed JSON lines are skipped with
  /// no exception thrown — callers can add logging if desired.
  List<Map<String, dynamic>> decode(String chunk) {
    _buffer.write(chunk);

    final raw = _buffer.toString();
    final lines = raw.split('\n');

    // The last element is either empty (if chunk ended with \n) or an
    // incomplete fragment that we must keep in the buffer.
    final incomplete = lines.last;
    _buffer.clear();
    if (incomplete.isNotEmpty) {
      _buffer.write(incomplete);
    }

    final messages = <Map<String, dynamic>>[];
    // Process all complete lines (everything except the last fragment).
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          messages.add(decoded);
        }
      } catch (_) {
        // Malformed JSON — skip silently.
      }
    }
    return messages;
  }

  /// Discard any incomplete buffered data.
  void reset() => _buffer.clear();
}
