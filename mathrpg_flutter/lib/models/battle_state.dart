import 'monster.dart';

enum BattlePhase {
  showingProblem,
  playerAttacking,
  monsterAttacking,
  victory,
  defeat,
}

class BattleState {
  final Monster monster;
  int monsterCurrentHp;
  int playerCurrentHp;
  int playerMaxHp;
  BattlePhase phase;
  int turnCount;
  int correctAnswers;
  int wrongAnswers;
  int totalDamageDealt;
  int totalDamageTaken;
  String? lastActionText;

  BattleState({
    required this.monster,
    required this.monsterCurrentHp,
    required this.playerCurrentHp,
    required this.playerMaxHp,
    this.phase = BattlePhase.showingProblem,
    this.turnCount = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.totalDamageDealt = 0,
    this.totalDamageTaken = 0,
    this.lastActionText,
  });
}
