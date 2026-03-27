import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef MsgHandler = void Function(Map<String, dynamic> msg);

class GameService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  MsgHandler? onMessage;
  void Function()? onDisconnect;
  String? deviceId;
  String? displayName;

  bool get isConnected => _channel != null;

  void connect(String url) {
    disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _sub = _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        onMessage?.call(msg);
      },
      onDone: () {
        _channel = null;
        onDisconnect?.call();
      },
      onError: (_) {
        _channel = null;
        onDisconnect?.call();
      },
    );
  }

  void send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  void sendHello(String deviceId, String name, String version) {
    this.deviceId = deviceId;
    displayName = name;
    send({
      'type': 'hello',
      'payload': {
        'device_id': deviceId,
        'display_name': name,
        'platform': 'android',
        'app_version': version,
      },
    });
  }

  void createSession(String name, String version) {
    send({
      'type': 'create_session',
      'payload': {
        'display_name': name,
        'app_version': version,
      },
    });
  }

  void joinSession(String code, String name, String version) {
    send({
      'type': 'join_session',
      'payload': {
        'join_code': code,
        'display_name': name,
        'app_version': version,
      },
    });
  }

  void submitMaze(String sessionId, List<List<int>> cells) {
    send({
      'type': 'submit_maze',
      'session_id': sessionId,
      'payload': {
        'width': 7,
        'height': 7,
        'cells': cells,
      },
    });
  }

  void setDone(String sessionId, bool done) {
    send({
      'type': 'set_done',
      'session_id': sessionId,
      'payload': {'done': done},
    });
  }

  void sendMove(String sessionId, String direction) {
    send({
      'type': 'move_attempt',
      'session_id': sessionId,
      'payload': {'direction': direction},
    });
  }

  void requestRematch(String sessionId) {
    send({
      'type': 'request_rematch',
      'session_id': sessionId,
    });
  }

  void leaveSession(String sessionId) {
    send({
      'type': 'leave_session',
      'session_id': sessionId,
    });
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}

