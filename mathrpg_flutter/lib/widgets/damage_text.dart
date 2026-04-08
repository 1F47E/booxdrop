import 'package:flutter/material.dart';
import '../theme/eink_theme.dart';

class DamageText extends StatelessWidget {
  const DamageText({
    super.key,
    required this.text,
    this.color = EinkColors.textPrimary,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: EinkColors.offWhite,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: EinkSizes.textLarge,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
