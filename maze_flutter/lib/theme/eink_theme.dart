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
  static const textMuted = Color(0xFF666666);  // minimum contrast on e-ink
  static const textOnDark = white;

  // Grid tiles
  static const tileFloor = offWhite;
  static const tileWall = Color(0xFF222222);
  static const tileKey = yellow;
  static const tileDoor = purple;
  static const tileTreasure = red;
  static const tileStart = green;
  static const tileHidden = Color(0xFFCCCCCC);

  // Tile borders (same hue but darker)
  static const tileBorderFloor = Color(0xFFBBBBBB);
  static const tileBorderWall = black;
  static const tileBorderKey = Color(0xFFCC9900);
  static const tileBorderDoor = Color(0xFF5500AA);
  static const tileBorderTreasure = Color(0xFFCC0000);
  static const tileBorderStart = Color(0xFF006600);
  static const tileBorderHidden = Color(0xFFAAAAAA);

  // Disabled
  static const disabled = Color(0xFFBBBBBB);
}

/// E-ink safe text sizes and icon sizes.
/// Kaleido 3: 300 PPI B&W, 150 PPI color. Min 16px text, 32dp icons.
class EinkSizes {
  // Text — all bold weight preferred
  static const textSmall = 16.0;     // absolute minimum on e-ink
  static const textBody = 18.0;
  static const textLarge = 22.0;
  static const textTitle = 26.0;
  static const textHero = 36.0;

  // Icons
  static const iconSmall = 28.0;     // minimum visible on Kaleido 3
  static const iconMedium = 32.0;
  static const iconLarge = 40.0;

  // Touch targets
  static const tapTarget = 52.0;     // min 48dp, we use 52 for comfort
  static const buttonHeight = 56.0;

  // Grid emoji
  static const gridEmoji = 22.0;
  static const miniGridEmoji = 16.0;
}
