import 'package:flutter/material.dart';
import '../models/monster.dart';
import '../theme/eink_theme.dart';

class ZoneNode extends StatelessWidget {
  const ZoneNode({
    super.key,
    required this.monsterName,
    required this.monsterEmoji,
    required this.nodeIndex,
    required this.isBoss,
    required this.isCurrent,
    required this.isCompleted,
    required this.isLocked,
    this.onTap,
    this.element,
  });

  final String monsterName;
  final String monsterEmoji;
  final int nodeIndex;
  final bool isBoss;
  final bool isCurrent;
  final bool isCompleted;
  final bool isLocked;
  final VoidCallback? onTap;
  final ElementType? element;

  @override
  Widget build(BuildContext context) {
    Color borderColor = EinkColors.disabled;
    double borderWidth = 1;
    Color bgColor = EinkColors.white;

    if (isCurrent) {
      borderColor = EinkColors.accent;
      borderWidth = 3;
      bgColor = const Color(0xFFFFF8F0);
    } else if (isCompleted) {
      borderColor = EinkColors.success;
      borderWidth = 2;
    } else if (isLocked) {
      bgColor = EinkColors.offWhite;
    }

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: borderWidth),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Status icon
            SizedBox(
              width: 32,
              child: Text(
                isCompleted
                    ? '\u2705'
                    : isLocked
                        ? '\u{1F512}'
                        : isBoss
                            ? '\u{1F451}'
                            : '\u2694\uFE0F',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            // Monster emoji
            Text(
              monsterEmoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            // Monster name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isBoss ? "BOSS: " : ""}$monsterName',
                    style: TextStyle(
                      fontSize: EinkSizes.textBody,
                      fontWeight: isBoss ? FontWeight.bold : FontWeight.normal,
                      color: isLocked
                          ? EinkColors.textMuted
                          : EinkColors.textPrimary,
                    ),
                  ),
                  if (isBoss)
                    const Text(
                      'Defeat to advance!',
                      style: TextStyle(
                        fontSize: EinkSizes.textSmall,
                        color: EinkColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            // Arrow
            if (!isLocked && !isCompleted)
              const Icon(
                Icons.chevron_right,
                color: EinkColors.textMuted,
                size: EinkSizes.iconSmall,
              ),
          ],
        ),
      ),
    );
  }
}
