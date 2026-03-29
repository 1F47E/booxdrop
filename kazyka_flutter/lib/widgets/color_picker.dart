import 'package:flutter/material.dart';

class ColorPicker extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;
  final Color? customColor;
  final VoidCallback? onCustomColorTap;

  const ColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.customColor,
    this.onCustomColorTap,
  });

  // Kaleido 3 e-ink optimized: high-saturation, bright primaries
  static const colors = <Color>[
    Colors.black,
    Color(0xFF444444), // dark gray
    Color(0xFF999999), // mid gray
    Colors.white,
    Color(0xFFFF0000), // red — pure
    Color(0xFFFF1493), // deep pink
    Color(0xFFFF5522), // deep orange
    Color(0xFFFF8800), // orange
    Color(0xFFFFDD00), // yellow
    Color(0xFF66CC00), // lime
    Color(0xFF00CC00), // green
    Color(0xFF00CCCC), // cyan
    Color(0xFF0066FF), // blue
    Color(0xFF4400FF), // indigo
    Color(0xFF7700CC), // purple
    Color(0xFF884400), // brown
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...colors.map((c) {
          final isSelected = selected == c;
          return GestureDetector(
            onTap: () => onChanged(c),
            child: Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black : const Color(0xFF666666),
                  width: isSelected ? 3 : 1,
                ),
              ),
            ),
          );
        }),
        // Custom color / + button
        if (onCustomColorTap != null)
          GestureDetector(
            onTap: onCustomColorTap,
            child: Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: customColor ?? Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: (customColor != null && selected == customColor)
                      ? Colors.black
                      : const Color(0xFF666666),
                  width: (customColor != null && selected == customColor)
                      ? 3
                      : 1,
                ),
              ),
              child: customColor == null
                  ? const Icon(Icons.add, size: 16, color: Colors.black)
                  : null,
            ),
          ),
      ],
    );
  }
}
