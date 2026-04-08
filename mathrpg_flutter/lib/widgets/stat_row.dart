import 'package:flutter/material.dart';
import '../theme/eink_theme.dart';

class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.label,
    required this.value,
    this.bonus,
  });

  final String label;
  final String value;
  final int? bonus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: EinkSizes.textBody,
              fontWeight: FontWeight.bold,
              color: EinkColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: EinkSizes.textBody,
              color: EinkColors.textPrimary,
            ),
          ),
          if (bonus != null && bonus! > 0) ...[
            const SizedBox(width: 6),
            Text(
              '(+$bonus)',
              style: const TextStyle(
                fontSize: EinkSizes.textSmall,
                color: EinkColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
