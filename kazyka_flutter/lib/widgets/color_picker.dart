import 'package:flutter/material.dart';

class ColorPicker extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;

  const ColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const colors = <Color>[
    Colors.black,
    Color(0xFF555555),
    Colors.white,
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFDD835), // yellow
    Color(0xFFFB8C00), // orange
    Color(0xFF8E24AA), // purple
    Color(0xFF6D4C41), // brown
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: colors.map((c) {
        final isSelected = selected == c;
        return GestureDetector(
          onTap: () => onChanged(c),
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.black26,
                width: isSelected ? 3 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
