import 'package:flutter/material.dart';
import '../theme/eink_theme.dart';
import '../services/progression_service.dart';

class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.currentXp,
    required this.level,
  });

  final int currentXp;
  final int level;

  @override
  Widget build(BuildContext context) {
    final needed = ProgressionService.xpToNextLevel(level);
    final fraction = needed > 0 ? (currentXp / needed).clamp(0.0, 1.0) : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'XP: $currentXp / $needed',
          style: const TextStyle(
            fontSize: EinkSizes.textSmall,
            color: EinkColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 16,
          decoration: BoxDecoration(
            border: Border.all(color: EinkColors.black, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(color: EinkColors.offWhite),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(color: EinkColors.xpBlue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
