import 'package:flutter/material.dart';
import '../providers/settings_provider.dart';

class BgColorPicker extends StatelessWidget {
  final int selectedColor;
  final double brightness;
  final ValueChanged<int> onColorChanged;
  final ValueChanged<double> onBrightnessChanged;

  const BgColorPicker({
    super.key,
    required this.selectedColor,
    required this.brightness,
    required this.onColorChanged,
    required this.onBrightnessChanged,
  });

  Color _applyBrightness(Color c, double b) {
    return Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      (c.r * 255 * b).round().clamp(0, 255),
      (c.g * 255 * b).round().clamp(0, 255),
      (c.b * 255 * b).round().clamp(0, 255),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color circles — 4x4 grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SettingsProvider.presetColors.map((colorVal) {
            final color = Color(colorVal);
            final adjusted = _applyBrightness(color, brightness);
            final isSelected = colorVal == selectedColor;

            return GestureDetector(
              onTap: () => onColorChanged(colorVal),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: adjusted,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.black26,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // Brightness slider
        Row(
          children: [
            const Icon(Icons.brightness_low, size: 18, color: Colors.black38),
            Expanded(
              child: Slider(
                value: brightness,
                min: 0.5,
                max: 1.0,
                divisions: 10,
                activeColor: Colors.black,
                inactiveColor: Colors.black26,
                onChanged: onBrightnessChanged,
              ),
            ),
            const Icon(Icons.brightness_high, size: 18, color: Colors.black),
          ],
        ),
      ],
    );
  }
}
