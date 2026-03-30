// test/services/bt_message_codec_test.dart
//
// Unit tests for NdjsonCodec — NDJSON framing used by Bluetooth transports.

import 'package:flutter_test/flutter_test.dart';

import 'package:battleships/services/ndjson_codec.dart';

void main() {
  group('NdjsonCodec.encode', () {
    test('produces JSON followed by a single newline', () {
      final line = NdjsonCodec.encode({'type': 'ping'});
      expect(line, equals('{"type":"ping"}\n'));
    });

    test('handles nested maps', () {
      final line = NdjsonCodec.encode({
        'type': 'fire_shot',
        'payload': {'x': 3, 'y': 5},
      });
      expect(line.endsWith('\n'), isTrue);
      expect(line.trimRight(), equals('{"type":"fire_shot","payload":{"x":3,"y":5}}'));
    });
  });

  group('NdjsonCodec.decode — single complete message', () {
    test('decodes one complete NDJSON line', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('{"type":"ping"}\n');
      expect(msgs.length, equals(1));
      expect(msgs[0]['type'], equals('ping'));
    });

    test('decodes message with nested payload', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('{"type":"fire_shot","payload":{"x":2,"y":4}}\n');
      expect(msgs.length, equals(1));
      expect(msgs[0]['payload']['x'], equals(2));
    });
  });

  group('NdjsonCodec.decode — partial message buffering', () {
    test('returns nothing for a fragment with no newline', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('{"type":"pin');
      expect(msgs, isEmpty);
    });

    test('buffers partial then completes on second chunk', () {
      final codec = NdjsonCodec();
      expect(codec.decode('{"type":"pin'), isEmpty);
      final msgs = codec.decode('g"}\n');
      expect(msgs.length, equals(1));
      expect(msgs[0]['type'], equals('ping'));
    });

    test('handles split mid-key', () {
      final codec = NdjsonCodec();
      codec.decode('{"ty');
      codec.decode('pe":"p');
      final msgs = codec.decode('ong"}\n');
      expect(msgs.length, equals(1));
      expect(msgs[0]['type'], equals('pong'));
    });
  });

  group('NdjsonCodec.decode — multiple messages in one chunk', () {
    test('returns two messages when two lines arrive at once', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('{"type":"ping"}\n{"type":"pong"}\n');
      expect(msgs.length, equals(2));
      expect(msgs[0]['type'], equals('ping'));
      expect(msgs[1]['type'], equals('pong'));
    });

    test('handles three messages in one chunk with trailing fragment', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode(
        '{"a":1}\n{"a":2}\n{"a":3}\n{"a":4',
      );
      expect(msgs.length, equals(3));
      expect(msgs.map((m) => m['a']).toList(), equals([1, 2, 3]));
      // Fragment should be held in buffer.
      final more = codec.decode('}\n');
      expect(more.length, equals(1));
      expect(more[0]['a'], equals(4));
    });
  });

  group('NdjsonCodec.decode — empty lines ignored', () {
    test('blank lines between messages are skipped', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('\n\n{"type":"hello"}\n\n');
      expect(msgs.length, equals(1));
      expect(msgs[0]['type'], equals('hello'));
    });

    test('pure whitespace line is ignored', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('   \n{"type":"hi"}\n');
      expect(msgs.length, equals(1));
    });
  });

  group('NdjsonCodec.decode — malformed JSON', () {
    test('malformed line is skipped, valid lines still decoded', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('not json at all\n{"type":"ok"}\n');
      expect(msgs.length, equals(1));
      expect(msgs[0]['type'], equals('ok'));
    });

    test('unclosed brace followed by valid line', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('{"bad":\n{"type":"good"}\n');
      expect(msgs.length, equals(1));
      expect(msgs[0]['type'], equals('good'));
    });
  });

  group('NdjsonCodec.decode — Unicode content', () {
    test('handles Unicode characters in values', () {
      final codec = NdjsonCodec();
      final msgs = codec.decode('{"name":"船长 🚢"}\n');
      expect(msgs.length, equals(1));
      expect(msgs[0]['name'], equals('船长 🚢'));
    });

    test('handles emoji in keys round-trip via encode/decode', () {
      final codec = NdjsonCodec();
      final original = <String, dynamic>{'msg': 'hello 🎉', 'n': 42};
      final line = NdjsonCodec.encode(original);
      final msgs = codec.decode(line);
      expect(msgs.length, equals(1));
      expect(msgs[0]['msg'], equals('hello 🎉'));
      expect(msgs[0]['n'], equals(42));
    });
  });

  group('NdjsonCodec.reset', () {
    test('discards buffered incomplete data', () {
      final codec = NdjsonCodec();
      codec.decode('{"type":"par'); // partial, buffered
      codec.reset();
      // After reset, completing that fragment must not yield anything.
      final msgs = codec.decode('tial"}\n');
      // The old buffer was discarded; we now only have 'tial"}\n' which is
      // not valid JSON on its own.
      expect(msgs, isEmpty);
    });
  });
}
