import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_rpg/services/math_engine.dart';
import 'package:math_rpg/models/math_problem.dart';

void main() {
  late MathEngine engine;

  setUp(() {
    engine = MathEngine(Random(42)); // Fixed seed for reproducibility
  });

  group('MathEngine', () {
    test('generates addition problems for level 1-3', () {
      for (var i = 0; i < 20; i++) {
        final problem = engine.generateProblem(1);
        expect(problem.choices.length, 4);
        expect(problem.choices.contains(problem.correctAnswer), isTrue);
        expect(problem.correctAnswer, greaterThanOrEqualTo(0));
        expect(problem.operation, MathOperation.addition);
      }
    });

    test('generates add/subtract for level 4-5', () {
      final ops = <MathOperation>{};
      for (var i = 0; i < 50; i++) {
        final problem = engine.generateProblem(5);
        ops.add(problem.operation);
        expect(problem.correctAnswer, greaterThanOrEqualTo(0));
        expect(problem.choices.length, 4);
      }
      // Should have both add and subtract
      expect(ops, contains(MathOperation.addition));
      expect(ops, contains(MathOperation.subtraction));
    });

    test('introduces multiplication at level 6-8', () {
      final ops = <MathOperation>{};
      for (var i = 0; i < 100; i++) {
        final problem = engine.generateProblem(7);
        ops.add(problem.operation);
      }
      expect(ops, contains(MathOperation.multiplication));
    });

    test('introduces division at level 11-13', () {
      final ops = <MathOperation>{};
      for (var i = 0; i < 100; i++) {
        final problem = engine.generateProblem(12);
        ops.add(problem.operation);
      }
      expect(ops, contains(MathOperation.division));
    });

    test('division always produces integer results', () {
      for (var i = 0; i < 50; i++) {
        final problem = engine.generateProblem(12);
        if (problem.operation == MathOperation.division) {
          // The question text format is "a ÷ b = ?"
          // Correct answer should be an integer
          expect(problem.correctAnswer, isA<int>());
          expect(problem.correctAnswer, greaterThan(0));
        }
      }
    });

    test('choices are unique', () {
      for (var level = 1; level <= 50; level += 5) {
        for (var i = 0; i < 10; i++) {
          final problem = engine.generateProblem(level);
          final uniqueChoices = problem.choices.toSet();
          expect(uniqueChoices.length, 4,
              reason: 'Level $level: choices should be unique, got ${problem.choices}');
        }
      }
    });

    test('no negative choices', () {
      for (var level = 1; level <= 50; level += 5) {
        for (var i = 0; i < 10; i++) {
          final problem = engine.generateProblem(level);
          for (final choice in problem.choices) {
            expect(choice, greaterThanOrEqualTo(0),
                reason: 'Level $level: choice $choice should not be negative');
          }
        }
      }
    });

    test('word problems at level 21+', () {
      var foundWordProblem = false;
      for (var i = 0; i < 100; i++) {
        final problem = engine.generateProblem(25);
        if (problem.questionText.contains('\n')) {
          foundWordProblem = true;
          break;
        }
      }
      expect(foundWordProblem, isTrue,
          reason: 'Should generate word problems at level 25');
    });

    test('correct answer is always in choices', () {
      for (var level = 1; level <= 50; level++) {
        final problem = engine.generateProblem(level);
        expect(problem.choices.contains(problem.correctAnswer), isTrue,
            reason: 'Level $level: correct answer ${problem.correctAnswer} not in ${problem.choices}');
      }
    });
  });
}
