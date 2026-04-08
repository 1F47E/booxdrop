import 'character.dart';

class GameSave {
  final Character character;
  final DateTime lastPlayed;
  final String saveVersion;

  const GameSave({
    required this.character,
    required this.lastPlayed,
    this.saveVersion = '1',
  });

  Map<String, dynamic> toJson() => {
        'character': character.toJson(),
        'lastPlayed': lastPlayed.toIso8601String(),
        'saveVersion': saveVersion,
      };

  factory GameSave.fromJson(Map<String, dynamic> j) => GameSave(
        character:
            Character.fromJson(j['character'] as Map<String, dynamic>),
        lastPlayed: DateTime.parse(j['lastPlayed'] as String),
        saveVersion: j['saveVersion'] as String? ?? '1',
      );
}

class ZoneDefinition {
  final String name;
  final String emoji;
  final String description;
  final int zoneIndex;
  final int nodeCount;

  const ZoneDefinition({
    required this.name,
    required this.emoji,
    required this.description,
    required this.zoneIndex,
    required this.nodeCount,
  });
}

class AdventureNode {
  final int zoneIndex;
  final int nodeIndex;
  final int globalIndex;
  final bool isBoss;

  const AdventureNode({
    required this.zoneIndex,
    required this.nodeIndex,
    required this.globalIndex,
    required this.isBoss,
  });
}
