import 'package:flutter/material.dart';
import '../theme/eink_theme.dart';

class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar({
    super.key,
    required this.emoji,
    this.size = EinkSizes.avatarLarge,
    this.borderColor = EinkColors.black,
  });

  final String emoji;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        color: EinkColors.offWhite,
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.6),
        ),
      ),
    );
  }
}
