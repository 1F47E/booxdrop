enum MathOperation { addition, subtraction, multiplication, division, mixed }

class MathProblem {
  final String questionText;
  final int correctAnswer;
  final List<int> choices;
  final MathOperation operation;
  final int difficulty;

  const MathProblem({
    required this.questionText,
    required this.correctAnswer,
    required this.choices,
    required this.operation,
    required this.difficulty,
  });
}
