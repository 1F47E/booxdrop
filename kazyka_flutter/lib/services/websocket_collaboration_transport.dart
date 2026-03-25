import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'collaboration_transport.dart';

/// Real WebSocket transport for live drawing sessions.
class WebSocketCollaborationTransport implements CollaborationTransport {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription? _channelSub;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  @override
  Future<void> connect(String url) async {
    // Reset controller if previously closed
    if (_controller.isClosed) {
      _controller = StreamController<Map<String, dynamic>>.broadcast();
    }

    _channel = WebSocketChannel.connect(Uri.parse(url));
    await _channel!.ready;
    _connected = true;

    _channelSub = _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (!_controller.isClosed) _controller.add(json);
        } catch (e) {
          if (!_controller.isClosed) {
            _controller.add({
              'type': 'error',
              'payload': {'message': 'Parse error: $e'},
            });
          }
        }
      },
      onDone: () {
        _connected = false;
        if (!_controller.isClosed) {
          _controller.add({
            'type': 'error',
            'payload': {'message': 'Connection closed'},
          });
        }
      },
      onError: (e) {
        _connected = false;
        if (!_controller.isClosed) {
          _controller.add({
            'type': 'error',
            'payload': {'message': 'Connection error: $e'},
          });
        }
      },
    );
  }

  @override
  void send(Map<String, dynamic> message) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (_) {
      _connected = false;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel?.sink.close();
    _channel = null;
    // Don't close the controller — keep it alive for reuse
  }
}
