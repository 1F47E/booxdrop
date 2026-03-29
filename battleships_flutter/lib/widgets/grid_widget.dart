import 'package:flutter/material.dart';
import '../models/grid.dart';
import '../models/ship.dart';

/// Colours — e-ink safe, high contrast, no pastels.
const _kColorEmpty = Colors.white;
const _kColorShip = Color(0xFF00CC00); // green
const _kColorHit = Color(0xFFCC0000); // red
const _kColorMiss = Color(0xFF888888); // dark grey
const _kColorSunk = Color(0xFF444444); // near-black
const _kColorPreview = Color(0xFFAAddAA); // light green preview
const _kColorInvalid = Color(0xFFFFAAAA); // light red — invalid placement
const _kBorderColor = Colors.black;
const _kBorderWidth = 2.0;
const _kMinCellSize = 40.0;

/// A single cell rendered with the appropriate fill and a thick black border.
class _GridCell extends StatelessWidget {
  final Color fill;
  final bool hasTapTarget;
  final VoidCallback? onTap;

  const _GridCell({
    required this.fill,
    this.hasTapTarget = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell = Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: _kBorderColor, width: _kBorderWidth / 2),
      ),
    );

    if (onTap != null) {
      cell = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cell,
      );
    }

    return cell;
  }
}

/// Reusable 8x8 grid renderer.
///
/// Parameters:
///   [grid]         — the 8x8 state to render.
///   [onCellTap]    — callback when user taps a cell; null disables tapping.
///   [showShips]    — whether to colour ship cells green (false on opponent grid).
///   [previewCells] — cells to highlight as a ship preview (valid placement).
///   [invalidCells] — cells to highlight as invalid (out-of-bounds / overlap).
class GridWidget extends StatelessWidget {
  final BattleGrid grid;
  final void Function(int x, int y)? onCellTap;
  final bool showShips;
  final Set<ShipPoint> previewCells;
  final Set<ShipPoint> invalidCells;

  const GridWidget({
    super.key,
    required this.grid,
    this.onCellTap,
    this.showShips = true,
    this.previewCells = const {},
    this.invalidCells = const {},
  });

  Color _colorFor(int x, int y) {
    final pt = ShipPoint(x, y);

    if (invalidCells.contains(pt)) return _kColorInvalid;
    if (previewCells.contains(pt)) return _kColorPreview;

    final state = grid.get(x, y);
    switch (state) {
      case CellState.ship:
        return showShips ? _kColorShip : _kColorEmpty;
      case CellState.hit:
        return _kColorHit;
      case CellState.miss:
        return _kColorMiss;
      case CellState.sunk:
        return _kColorSunk;
      default:
        return _kColorEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _kBorderColor, width: _kBorderWidth),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize =
                constraints.maxWidth / BattleGrid.size;
            // Warn in debug if cells are too small for e-ink touch.
            assert(
              cellSize >= _kMinCellSize,
              'Grid cells are $cellSize dp — below e-ink minimum $_kMinCellSize dp',
            );

            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: BattleGrid.size,
              ),
              itemCount: BattleGrid.size * BattleGrid.size,
              itemBuilder: (context, index) {
                final x = index % BattleGrid.size;
                final y = index ~/ BattleGrid.size;
                return _GridCell(
                  fill: _colorFor(x, y),
                  hasTapTarget: onCellTap != null,
                  onTap: onCellTap != null ? () => onCellTap!(x, y) : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
