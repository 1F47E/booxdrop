import 'dart:math';
import '../models/math_problem.dart';

/// Algorithmic math problem generator. Difficulty scales with player level.
class MathEngine {
  final Random _rng;

  MathEngine([Random? rng]) : _rng = rng ?? Random();

  /// Generate a problem appropriate for the given player level (1-50).
  MathProblem generateProblem(int playerLevel) {
    final level = playerLevel.clamp(1, 50);

    if (level <= 3) return _addition(1, 10, level);
    if (level <= 5) return _addOrSubtract(1, 20, level);
    if (level <= 8) return _withMultiplication(1, 50, 2, 5, level);
    if (level <= 10) return _withMultiplication(1, 50, 2, 10, level);
    if (level <= 13) return _withDivision(1, 50, level);
    if (level <= 15) return _withDivision(1, 100, level);
    if (level <= 20) return _mixedOperations(1, 100, level);
    if (level <= 30) return _mixedOrWordProblem(1, 200, level);
    if (level <= 40) return _mixedOperations(1, 300, level);
    return _mixedOperations(1, 500, level);
  }

  MathProblem _addition(int minVal, int maxVal, int difficulty) {
    final a = _rng.nextInt(maxVal - minVal + 1) + minVal;
    final b = _rng.nextInt(maxVal - minVal + 1) + minVal;
    final answer = a + b;
    return MathProblem(
      questionText: '$a + $b = ?',
      correctAnswer: answer,
      choices: _generateChoices(answer),
      operation: MathOperation.addition,
      difficulty: difficulty,
    );
  }

  MathProblem _subtraction(int minVal, int maxVal, int difficulty) {
    var a = _rng.nextInt(maxVal - minVal + 1) + minVal;
    var b = _rng.nextInt(maxVal - minVal + 1) + minVal;
    if (b > a) {
      final tmp = a;
      a = b;
      b = tmp;
    }
    final answer = a - b;
    return MathProblem(
      questionText: '$a - $b = ?',
      correctAnswer: answer,
      choices: _generateChoices(answer),
      operation: MathOperation.subtraction,
      difficulty: difficulty,
    );
  }

  MathProblem _addOrSubtract(int minVal, int maxVal, int difficulty) {
    return _rng.nextBool()
        ? _addition(minVal, maxVal, difficulty)
        : _subtraction(minVal, maxVal, difficulty);
  }

  MathProblem _multiplication(int minTable, int maxTable, int difficulty) {
    final a = _rng.nextInt(maxTable - minTable + 1) + minTable;
    final b = _rng.nextInt(10) + 1;
    final answer = a * b;
    return MathProblem(
      questionText: '$a \u00D7 $b = ?',
      correctAnswer: answer,
      choices: _generateChoices(answer),
      operation: MathOperation.multiplication,
      difficulty: difficulty,
    );
  }

  MathProblem _division(int maxDividend, int difficulty) {
    final divisor = _rng.nextInt(9) + 2; // 2-10
    final quotient = _rng.nextInt(maxDividend ~/ divisor) + 1;
    final dividend = divisor * quotient;
    return MathProblem(
      questionText: '$dividend \u00F7 $divisor = ?',
      correctAnswer: quotient,
      choices: _generateChoices(quotient),
      operation: MathOperation.division,
      difficulty: difficulty,
    );
  }

  MathProblem _withMultiplication(
      int minVal, int maxVal, int minTable, int maxTable, int difficulty) {
    final roll = _rng.nextInt(3);
    if (roll == 0) return _multiplication(minTable, maxTable, difficulty);
    return _addOrSubtract(minVal, maxVal, difficulty);
  }

  MathProblem _withDivision(int minVal, int maxVal, int difficulty) {
    final roll = _rng.nextInt(4);
    if (roll == 0) return _division(maxVal, difficulty);
    if (roll == 1) return _multiplication(2, 10, difficulty);
    return _addOrSubtract(minVal, maxVal, difficulty);
  }

  MathProblem _mixedOperations(int minVal, int maxVal, int difficulty) {
    final roll = _rng.nextInt(4);
    return switch (roll) {
      0 => _addition(minVal, maxVal, difficulty),
      1 => _subtraction(minVal, maxVal, difficulty),
      2 => _multiplication(2, 12, difficulty),
      _ => _division(maxVal, difficulty),
    };
  }

  MathProblem _mixedOrWordProblem(int minVal, int maxVal, int difficulty) {
    if (_rng.nextInt(3) == 0) return _wordProblem(minVal, maxVal, difficulty);
    return _mixedOperations(minVal, maxVal, difficulty);
  }

  MathProblem _wordProblem(int minVal, int maxVal, int difficulty) {
    final roll = _rng.nextInt(4);
    switch (roll) {
      case 0:
        final a = _rng.nextInt(maxVal ~/ 2) + minVal;
        final b = _rng.nextInt(maxVal ~/ 2) + minVal;
        return MathProblem(
          questionText: 'You have $a gold coins.\nYou find $b more.\nHow many total?',
          correctAnswer: a + b,
          choices: _generateChoices(a + b),
          operation: MathOperation.addition,
          difficulty: difficulty,
        );
      case 1:
        var a = _rng.nextInt(maxVal) + minVal;
        var b = _rng.nextInt(a) + 1;
        return MathProblem(
          questionText: 'A dragon has $a gold.\nIt spends $b.\nHow many left?',
          correctAnswer: a - b,
          choices: _generateChoices(a - b),
          operation: MathOperation.subtraction,
          difficulty: difficulty,
        );
      case 2:
        final a = _rng.nextInt(10) + 2;
        final b = _rng.nextInt(10) + 2;
        return MathProblem(
          questionText: '$a knights each carry\n$b swords.\nHow many swords total?',
          correctAnswer: a * b,
          choices: _generateChoices(a * b),
          operation: MathOperation.multiplication,
          difficulty: difficulty,
        );
      default:
        final divisor = _rng.nextInt(9) + 2;
        final quotient = _rng.nextInt(15) + 2;
        final dividend = divisor * quotient;
        return MathProblem(
          questionText: '$dividend potions split among\n$divisor heroes.\nHow many each?',
          correctAnswer: quotient,
          choices: _generateChoices(quotient),
          operation: MathOperation.division,
          difficulty: difficulty,
        );
    }
  }

  /// Generate 4 choices including the correct answer.
  List<int> _generateChoices(int correct) {
    final choices = <int>{correct};
    var attempts = 0;

    while (choices.length < 4 && attempts < 100) {
      attempts++;
      final spread = max(3, (correct.abs() * 0.3).ceil());
      final offset = _rng.nextInt(spread * 2 + 1) - spread;
      if (offset == 0) continue;
      final distractor = correct + offset;
      if (distractor < 0) continue;
      choices.add(distractor);
    }

    // Fallback if we couldn't generate enough unique distractors
    var fallback = correct + 1;
    while (choices.length < 4) {
      if (!choices.contains(fallback) && fallback >= 0) {
        choices.add(fallback);
      }
      fallback++;
    }

    final list = choices.toList();
    list.shuffle(_rng);
    return list;
  }
}
