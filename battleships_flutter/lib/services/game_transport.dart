/// Abstract transport interface for Battleships.
/// Both WebSocket (online) and Bluetooth (P2P) implement this.
abstract class GameTransport {
  /// Called for every inbound JSON message envelope.
  void Function(Map<String, dynamic> msg)? onMessage;

  /// Called when the connection drops (voluntarily or not).
  void Function(String reason)? onDisconnect;

  /// Whether the transport is currently connected.
  bool get isConnected;

  /// Open the connection. For WS this dials the server.
  /// For BT host this starts listening; for BT guest this connects to the host.
  Future<void> connect();

  /// Tear down the connection cleanly.
  Future<void> disconnect();

  /// Send a JSON message envelope.
  void send(Map<String, dynamic> msg);
}
