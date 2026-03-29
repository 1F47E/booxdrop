import 'package:flutter/material.dart';
import '../models/canvas_item.dart';

class BrushPicker extends StatelessWidget {
  final BrushType selected;
  final ValueChanged<BrushType> onChanged;

  const BrushPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _labels = {
    BrushType.round: 'Round',
    BrushType.flat: 'Flat',
    BrushType.marker: 'Marker',
    BrushType.crayon: 'Crayon',
  };

  static const _icons = {
    BrushType.round: Icons.circle,
    BrushType.flat: Icons.horizontal_rule,
    BrushType.marker: Icons.format_paint,
    BrushType.crayon: Icons.brush,
  };

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Brush Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: BrushType.values.map((brush) {
                final isSelected = selected == brush;
                return GestureDetector(
                  onTap: () {
                    onChanged(brush);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Colors.black
                            : const Color(0xFF999999),
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icons[brush], size: 28, color: Colors.black),
                        const SizedBox(height: 4),
                        Text(
                          _labels[brush]!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Icon(_icons[selected], size: 22, color: Colors.black),
      ),
    );
  }
}
