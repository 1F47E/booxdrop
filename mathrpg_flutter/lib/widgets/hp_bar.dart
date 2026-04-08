import 'package:flutter/material.dart';
import '../theme/eink_theme.dart';

class HpBar extends StatelessWidget {
  const HpBar({
    super.key,
    required this.current,
    required this.max,
    this.color = EinkColors.hpGreen,
    this.label = 'HP',
  });

  final int current;
  final int max;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fraction = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    final barColor = fraction < 0.25 ? EinkColors.hpRed : color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: EinkSizes.hpBarHeight,
          decoration: BoxDecoration(
            border: Border.all(color: EinkColors.black, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                // Background
                Container(color: EinkColors.offWhite),
                // Fill
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(color: barColor),
                ),
                // Text overlay
                Center(
                  child: Text(
                    '$label: $current/$max',
                    style: const TextStyle(
                      fontSize: EinkSizes.textSmall,
                      fontWeight: FontWeight.bold,
                      color: EinkColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
