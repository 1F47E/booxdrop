import 'package:flutter/material.dart';
import '../theme/eink_theme.dart';

class MathChoiceButton extends StatelessWidget {
  const MathChoiceButton({
    super.key,
    required this.value,
    required this.onTap,
    this.isSelected = false,
    this.isCorrect,
    this.enabled = true,
  });

  final int value;
  final VoidCallback onTap;
  final bool isSelected;
  final bool? isCorrect; // null = not answered yet
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Color bgColor = EinkColors.white;
    Color borderColor = EinkColors.black;
    double borderWidth = 2;

    if (isSelected && isCorrect != null) {
      if (isCorrect!) {
        bgColor = EinkColors.green;
        borderColor = EinkColors.success;
        borderWidth = 3;
      } else {
        bgColor = EinkColors.red;
        borderColor = EinkColors.hpRed;
        borderWidth = 3;
      }
    } else if (!isSelected && isCorrect == true) {
      // Show correct answer when wrong was selected
      bgColor = const Color(0xFFDDFFDD);
      borderColor = EinkColors.success;
      borderWidth = 3;
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: EinkSizes.tapTarget + 12,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: borderWidth),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: EinkSizes.textTitle,
              fontWeight: FontWeight.bold,
              color: (isSelected && isCorrect != null)
                  ? EinkColors.white
                  : EinkColors.black,
            ),
          ),
        ),
      ),
    );
  }
}
