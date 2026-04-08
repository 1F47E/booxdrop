import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/battle_state.dart';
import '../models/character.dart';
import '../models/item.dart';
import '../models/math_problem.dart';
import '../models/monster.dart';
import '../services/loot_table.dart';
import '../services/math_engine.dart';
import '../services/progression_service.dart';
import '../services/sound_service.dart';

class BattleProvider extends ChangeNotifier {
  final MathEngine _mathEngine = MathEngine();
  final Random _rng = Random();

  BattleState? _state;
  BattleState? get state => _state;

  MathProblem? _currentProblem;
  MathProblem? get currentProblem => _currentProblem;

  // Answer feedback (which choice was selected, was it correct)
  int? _selectedAnswer;
  int? get selectedAnswer => _selectedAnswer;
  bool? _answerCorrect;
  bool? get answerCorrect => _answerCorrect;

  // Post-battle results
  int _xpGained = 0;
  int get xpGained => _xpGained;
  int _goldGained = 0;
  int get goldGained => _goldGained;
  Item? _lootDrop;
  Item? get lootDrop => _lootDrop;
  int _levelsGained = 0;
  int get levelsGained => _levelsGained;

  Character? _character;

  void startBattle(Monster monster, Character character) {
    _character = character;
    _state = BattleState(
      monster: monster,
      monsterCurrentHp: monster.baseHp,
      playerCurrentHp: character.currentHp,
      playerMaxHp: character.maxHp,
    );
    _selectedAnswer = null;
    _answerCorrect = null;
    _xpGained = 0;
    _goldGained = 0;
    _lootDrop = null;
    _levelsGained = 0;
    _generateNextProblem();
    notifyListeners();
  }

  void submitAnswer(int chosenAnswer) {
    if (_state == null || _currentProblem == null) return;
    if (_state!.phase != BattlePhase.showingProblem) return;

    _selectedAnswer = chosenAnswer;
    _state!.turnCount++;

    if (chosenAnswer == _currentProblem!.correctAnswer) {
      _answerCorrect = true;
      _handleCorrectAnswer();
    } else {
      _answerCorrect = false;
      _handleWrongAnswer();
    }

    notifyListeners();
  }

  void _handleCorrectAnswer() {
    final character = _character!;
    _state!.correctAnswers++;
    character.problemsSolved++;

    // Player attacks monster
    final damage = max(1, character.atk + _rng.nextInt(5) - 2);
    _state!.monsterCurrentHp -= damage;
    _state!.totalDamageDealt += damage;
    _state!.lastActionText = 'You dealt $damage damage!';
    SoundService.playAttack();

    if (_state!.monsterCurrentHp <= 0) {
      _state!.monsterCurrentHp = 0;
      _state!.phase = BattlePhase.victory;
      _processVictory();
      SoundService.playVictory();
    } else {
      _state!.phase = BattlePhase.playerAttacking;
    }
  }

  void _handleWrongAnswer() {
    final character = _character!;
    _state!.wrongAnswers++;

    // Monster attacks player
    final monsterDmg = max(1, _state!.monster.baseAtk - character.def + _rng.nextInt(3) - 1);
    _state!.playerCurrentHp -= monsterDmg;
    _state!.totalDamageTaken += monsterDmg;
    character.currentHp = _state!.playerCurrentHp;
    _state!.lastActionText = '${_state!.monster.name} attacks for $monsterDmg!';
    SoundService.playHit();

    if (_state!.playerCurrentHp <= 0) {
      _state!.playerCurrentHp = 0;
      _state!.phase = BattlePhase.defeat;
      SoundService.playDefeat();
    } else {
      _state!.phase = BattlePhase.monsterAttacking;
    }
  }

  void _processVictory() {
    final character = _character!;
    final monster = _state!.monster;

    _xpGained = monster.xpReward;
    _goldGained = monster.goldReward;

    character.xp += _xpGained;
    character.gold += _goldGained;
    character.monstersDefeated++;
    character.currentHp = _state!.playerCurrentHp;

    // Level up
    _levelsGained = ProgressionService.processLevelUp(character);
    if (_levelsGained > 0) {
      _state!.playerCurrentHp = character.currentHp;
      SoundService.playLevelUp();
    }

    // Loot
    _lootDrop = LootTable.rollDrop(monster.lootTableId, character.level);
    if (_lootDrop != null) {
      SoundService.playLoot();
    }
  }

  /// Advance past the attack/damage display to the next problem.
  void nextTurn() {
    if (_state == null) return;
    if (_state!.phase == BattlePhase.victory ||
        _state!.phase == BattlePhase.defeat) {
      return;
    }
    _selectedAnswer = null;
    _answerCorrect = null;
    _state!.phase = BattlePhase.showingProblem;
    _generateNextProblem();
    notifyListeners();
  }

  void _generateNextProblem() {
    final level = _character?.level ?? 1;
    _currentProblem = _mathEngine.generateProblem(level);
  }
}
