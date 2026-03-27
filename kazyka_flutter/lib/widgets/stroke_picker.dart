import 'package:flutter/material.dart';

class StrokePicker extends StatelessWidget {
  final double selected;
  final ValueChanged<double> onChanged;

  const StrokePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const widths = [3.0, 6.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widths.map((w) {
        final isSelected = selected == w;
        return GestureDetector(
          onTap: () => onChanged(w),
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : const Color(0xFF666666),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Container(
                width: w + 2,
                height: w + 2,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
