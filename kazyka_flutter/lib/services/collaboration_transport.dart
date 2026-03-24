/// Abstract transport interface for collaboration sessions.
/// Implementations: WebSocketCollaborationTransport, FakeCollaborationTransport.
abstract class CollaborationTransport {
  /// Connect to the collaboration server.
  Future<void> connect(String url);

  /// Send a JSON message.
  void send(Map<String, dynamic> message);

  /// Stream of incoming JSON messages.
  Stream<Map<String, dynamic>> get events;

  /// Disconnect and clean up.
  Future<void> disconnect();

  /// Whether currently connected.
  bool get isConnected;
}
