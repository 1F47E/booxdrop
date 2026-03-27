class MatchRecord {
  final String id;
  final DateTime playedAt;
  final int raceDurationSec;
  final String winnerName;
  final String winnerDeviceId;
  final int winnerMoves;
  final String loserName;
  final String loserDeviceId;
  final int loserMoves;
  final List<List<int>> hostMaze;
  final List<List<int>> guestMaze;
  final String hostName;
  final String guestName;
  final String hostDeviceId;
  final String guestDeviceId;
  final String reason;

  MatchRecord({
    required this.id,
    required this.playedAt,
    required this.raceDurationSec,
    required this.winnerName,
    required this.winnerDeviceId,
    required this.winnerMoves,
    required this.loserName,
    required this.loserDeviceId,
    required this.loserMoves,
    required this.hostMaze,
    required this.guestMaze,
    required this.hostName,
    required this.guestName,
    required this.hostDeviceId,
    required this.guestDeviceId,
    required this.reason,
  });

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      id: json['id'] as String? ?? '',
      playedAt: DateTime.tryParse(json['played_at'] as String? ?? '') ?? DateTime.now(),
      raceDurationSec: json['race_duration_s'] as int? ?? 0,
      winnerName: json['winner_name'] as String? ?? '',
      winnerDeviceId: json['winner_device_id'] as String? ?? '',
      winnerMoves: json['winner_moves'] as int? ?? 0,
      loserName: json['loser_name'] as String? ?? '',
      loserDeviceId: json['loser_device_id'] as String? ?? '',
      loserMoves: json['loser_moves'] as int? ?? 0,
      hostMaze: _parseGrid(json['host_maze']),
      guestMaze: _parseGrid(json['guest_maze']),
      hostName: json['host_name'] as String? ?? '',
      guestName: json['guest_name'] as String? ?? '',
      hostDeviceId: json['host_device_id'] as String? ?? '',
      guestDeviceId: json['guest_device_id'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  static List<List<int>> _parseGrid(dynamic data) {
    if (data == null) return [];
    return (data as List).map((row) {
      return (row as List).map((cell) => cell as int).toList();
    }).toList();
  }

  bool didWin(String? deviceId) => winnerDeviceId == deviceId;

  String get durationText {
    final m = raceDurationSec ~/ 60;
    final s = raceDurationSec % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
