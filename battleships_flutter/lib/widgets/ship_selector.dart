import 'package:flutter/material.dart';
import '../models/ship.dart';

/// Ship selection toolbar for the placement screen.
///
/// Displays four ship buttons (one per required type).  The selected ship gets
/// a thick border.  Placed ships are greyed-out with a checkmark and are not
/// tappable.  A rotate button below the row toggles orientation.
class ShipSelector extends StatelessWidget {
  final ShipType? selectedType;
  final Set<ShipType> placedTypes;
  final bool isHorizontal;
  final void Function(ShipType type) onSelect;
  final VoidCallback onRotate;

  const ShipSelector({
    super.key,
    required this.selectedType,
    required this.placedTypes,
    required this.isHorizontal,
    required this.onSelect,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: kFleetOrder.map((type) => _ShipButton(
            type: type,
            isSelected: selectedType == type,
            isPlaced: placedTypes.contains(type),
            onTap: () => onSelect(type),
          )).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onRotate,
            icon: const Icon(Icons.rotate_right, size: 22),
            label: Text(
              isHorizontal ? 'Horizontal' : 'Vertical',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShipButton extends StatelessWidget {
  final ShipType type;
  final bool isSelected;
  final bool isPlaced;
  final VoidCallback onTap;

  const _ShipButton({
    required this.type,
    required this.isSelected,
    required this.isPlaced,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPlaced ? const Color(0xFF999999) : Colors.black;
    final bgColor = isSelected ? const Color(0xFFE8FFE8) : Colors.white;
    final borderWidth = isSelected ? 3.0 : 1.5;

    return GestureDetector(
      onTap: isPlaced ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 70, minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: color, width: borderWidth),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPlaced)
              const Icon(Icons.check_circle, size: 20, color: Color(0xFF009900))
            else
              _SizeIndicator(size: type.size),
            const SizedBox(height: 4),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '${type.size}',
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of filled squares representing the ship's cell count.
class _SizeIndicator extends StatelessWidget {
  final int size;
  const _SizeIndicator({required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(size, (i) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        color: const Color(0xFF00CC00),
      )),
    );
  }
}
