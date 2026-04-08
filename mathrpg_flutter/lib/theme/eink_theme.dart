import 'package:flutter/material.dart';

/// E-ink safe color palette for Boox Kaleido 3.
/// Kaleido 3 has 4096 colors at 150 PPI. Use high-saturation primaries,
/// pure black/white for text, avoid pastels/gradients.
class EinkColors {
  // Core
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const offWhite = Color(0xFFF5F5F5);

  // High-saturation primaries (pop on Kaleido 3)
  static const red = Color(0xFFFF0000);
  static const green = Color(0xFF00CC00);
  static const blue = Color(0xFF0000FF);
  static const yellow = Color(0xFFFFDD00);
  static const orange = Color(0xFFFF8800);
  static const purple = Color(0xFF7700CC);

  // UI colors
  static const primary = purple;
  static const accent = orange;
  static const success = Color(0xFF008800);
  static const error = red;
  static const warning = orange;

  // Text
  static const textPrimary = black;
  static const textSecondary = Color(0xFF444444);
  static const textMuted = Color(0xFF666666);
  static const textOnDark = white;

  // RPG-specific colors
  static const hpRed = Color(0xFFCC0000);
  static const hpGreen = Color(0xFF008800);
  static const xpBlue = Color(0xFF0000FF);
  static const goldYellow = Color(0xFFFFDD00);
  static const manaBlue = Color(0xFF0066FF);

  // Item rarity colors
  static const rarityCommon = Color(0xFF666666);
  static const rarityUncommon = Color(0xFF00CC00);
  static const rarityRare = Color(0xFF0000FF);
  static const rarityEpic = Color(0xFF7700CC);

  // Element colors
  static const elementFire = Color(0xFFFF0000);
  static const elementIce = Color(0xFF0066FF);
  static const elementPoison = Color(0xFF00CC00);
  static const elementDark = Color(0xFF444444);
  static const elementEarth = Color(0xFF886600);
  static const elementNormal = Color(0xFF888888);

  // Disabled
  static const disabled = Color(0xFFBBBBBB);
}

/// E-ink safe text sizes and icon sizes.
/// Kaleido 3: 300 PPI B&W, 150 PPI color. Min 16px text, 32dp icons.
class EinkSizes {
  // Text — all bold weight preferred
  static const textSmall = 16.0;
  static const textBody = 18.0;
  static const textLarge = 22.0;
  static const textTitle = 26.0;
  static const textHero = 36.0;
  static const textMega = 48.0;

  // Icons
  static const iconSmall = 28.0;
  static const iconMedium = 32.0;
  static const iconLarge = 40.0;

  // Touch targets
  static const tapTarget = 52.0;
  static const buttonHeight = 56.0;

  // RPG-specific
  static const avatarLarge = 48.0;
  static const avatarSmall = 36.0;
  static const hpBarHeight = 24.0;
}
