import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/grid.dart';
import '../models/ship.dart';
import '../providers/battle_provider.dart';
import '../services/sound_service.dart';
import '../widgets/grid_widget.dart';
import '../widgets/ship_selector.dart';

class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  ShipType? _selectedType;
  bool _isHorizontal = true;

  // Grid that the user sees — ship cells set to CellState.ship.
  final BattleGrid _grid = BattleGrid();

  // Ships the user has fully placed.
  final List<Ship> _placedShips = [];

  // Cells that form the hover/preview on the last tapped cell.
  Set<ShipPoint> _previewCells = {};
  Set<ShipPoint> _invalidCells = {};

  // Cache: which ship types have been placed.
  Set<ShipType> get _placedTypes =>
      _placedShips.map((s) => s.type).toSet();

  bool get _allPlaced => _placedTypes.length == kFleetOrder.length;

  // -----------------------------------------------------------------------
  // Placement helpers
  // -----------------------------------------------------------------------

  /// Returns the candidate cells for a ship of [type] anchored at (x, y)
  /// in the current orientation.  Returns null if any cell is out of bounds.
  List<ShipPoint>? _candidateCells(ShipType type, int x, int y) {
    final sz = type.size;
    final cells = <ShipPoint>[];

    for (int i = 0; i < sz; i++) {
      final cx = _isHorizontal ? x + i : x;
      final cy = _isHorizontal ? y : y + i;
      if (cx >= BattleGrid.size || cy >= BattleGrid.size) return null;
      cells.add(ShipPoint(cx, cy));
    }
    return cells;
  }

  /// Returns the occupied + buffer cells for already-placed ships.
  /// Used to check adjacency (all 8 neighbours).
  Set<ShipPoint> _occupiedWithBuffer() {
    final result = <ShipPoint>{};
    for (final ship in _placedShips) {
      for (final pt in ship.cells) {
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = pt.x + dx;
            final ny = pt.y + dy;
            if (nx >= 0 && nx < BattleGrid.size && ny >= 0 && ny < BattleGrid.size) {
              result.add(ShipPoint(nx, ny));
            }
          }
        }
      }
    }
    return result;
  }

  /// Validates whether [cells] can be placed given current placed ships.
  bool _isValidPlacement(List<ShipPoint> cells) {
    final occupied = _occupiedWithBuffer();
    for (final pt in cells) {
      if (occupied.contains(pt)) return false;
    }
    return true;
  }

  void _onCellTap(int x, int y) {
    final type = _selectedType;
    if (type == null) return;
    if (_placedTypes.contains(type)) return;

    final cells = _candidateCells(type, x, y);
    if (cells == null) {
      // Out of bounds — show nothing.
      setState(() {
        _previewCells = {};
        _invalidCells = {};
      });
      return;
    }

    if (_isValidPlacement(cells)) {
      // Commit placement.
      final ship = Ship(type, cells);
      SoundService.playPlace();
      setState(() {
        _placedShips.add(ship);
        for (final pt in cells) {
          _grid.set(pt.x, pt.y, CellState.ship);
        }
        _previewCells = {};
        _invalidCells = {};
        // Auto-advance to next unplaced ship.
        _selectedType = _nextUnplaced();
      });
    } else {
      // Show invalid cells so user can see why placement failed.
      setState(() {
        _invalidCells = cells.toSet();
        _previewCells = {};
      });
      // Clear invalid highlight after a brief delay.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _invalidCells = {};
          });
        }
      });
    }
  }

  /// Returns the next ship type that has not yet been placed, or null.
  ShipType? _nextUnplaced() {
    final placed = _placedTypes;
    for (final t in kFleetOrder) {
      if (!placed.contains(t)) return t;
    }
    return null;
  }

  void _removeLast() {
    if (_placedShips.isEmpty) return;
    setState(() {
      final last = _placedShips.removeLast();
      for (final pt in last.cells) {
        _grid.set(pt.x, pt.y, CellState.empty);
      }
      _selectedType = last.type;
      _previewCells = {};
      _invalidCells = {};
    });
  }

  void _clearAll() {
    setState(() {
      _placedShips.clear();
      for (int y = 0; y < BattleGrid.size; y++) {
        for (int x = 0; x < BattleGrid.size; x++) {
          _grid.set(x, y, CellState.empty);
        }
      }
      _selectedType = kFleetOrder.first;
      _previewCells = {};
      _invalidCells = {};
    });
  }

  // -----------------------------------------------------------------------
  // Status text
  // -----------------------------------------------------------------------

  String _statusText(BattleProvider battle) {
    if (battle.fleetValid && !battle.ready) {
      return 'Fleet accepted! Press Ready when set.';
    }
    if (battle.ready && !battle.peerReady) {
      return 'Waiting for ${battle.peerName ?? "opponent"} to be ready...';
    }
    if (battle.peerReady && !battle.ready) {
      return 'Opponent is ready — press Ready!';
    }
    if (_selectedType == null && !_allPlaced) {
      return 'All ships placed — tap Submit Fleet.';
    }
    if (_selectedType != null) {
      final orient = _isHorizontal ? 'horizontal' : 'vertical';
      return 'Tap grid to place ${_selectedType!.label} ($orient)';
    }
    return '';
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final battle = context.watch<BattleProvider>();

    // Initialise selectedType on first build.
    if (_selectedType == null && !_allPlaced) {
      _selectedType = _nextUnplaced();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Place Your Ships',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => battle.leave(),
        ),
        actions: [
          if (_placedShips.isNotEmpty && !battle.fleetValid)
            TextButton(
              onPressed: _removeLast,
              child: const Text(
                'Undo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          if (_placedShips.isNotEmpty && !battle.fleetValid)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                'Clear',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Opponent / banner info
              if (battle.peerName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'vs ${battle.peerName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Status / banner text
              _BannerBar(battle: battle, statusText: _statusText(battle)),

              const SizedBox(height: 8),

              // Grid — constrained height so buttons fit below
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: GridWidget(
                  grid: _grid,
                  onCellTap: _canTapGrid(battle) ? _onCellTap : null,
                  showShips: true,
                  previewCells: _previewCells,
                  invalidCells: _invalidCells,
                ),
              ),

              const SizedBox(height: 8),

              // Ship selector (hidden after fleet is submitted)
              if (!battle.fleetValid)
                ShipSelector(
                  selectedType: _selectedType,
                  placedTypes: _placedTypes,
                  isHorizontal: _isHorizontal,
                  onSelect: (type) {
                    setState(() {
                      _selectedType = type;
                      _previewCells = {};
                      _invalidCells = {};
                    });
                  },
                  onRotate: () {
                    setState(() {
                      _isHorizontal = !_isHorizontal;
                      _previewCells = {};
                      _invalidCells = {};
                    });
                  },
                ),

              const SizedBox(height: 12),

              // Primary action button
              _ActionButton(
                battle: battle,
                allPlaced: _allPlaced,
                onSubmitFleet: () => battle.submitFleet(_placedShips),
                onSetReady: () => battle.setReady(true),
              ),

              const SizedBox(height: 8),

              // Leave button
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: () => battle.leave(),
                  style: TextButton.styleFrom(foregroundColor: Colors.black54),
                  child: const Text(
                    'Leave Game',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canTapGrid(BattleProvider battle) {
    // Disable tapping once fleet has been submitted.
    return !battle.fleetValid && _selectedType != null;
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _BannerBar extends StatelessWidget {
  final BattleProvider battle;
  final String statusText;

  const _BannerBar({required this.battle, required this.statusText});

  @override
  Widget build(BuildContext context) {
    final bannerText = battle.banner;
    final bannerType = battle.bannerType;

    if (bannerText != null && bannerText.isNotEmpty) {
      final isError = bannerType == 'error';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFDDDD) : const Color(0xFFDDFFDD),
          border: Border.all(
            color: isError ? const Color(0xFFCC0000) : const Color(0xFF009900),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          bannerText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isError ? const Color(0xFFCC0000) : const Color(0xFF006600),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (statusText.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          statusText,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ActionButton extends StatelessWidget {
  final BattleProvider battle;
  final bool allPlaced;
  final VoidCallback onSubmitFleet;
  final VoidCallback onSetReady;

  const _ActionButton({
    required this.battle,
    required this.allPlaced,
    required this.onSubmitFleet,
    required this.onSetReady,
  });

  @override
  Widget build(BuildContext context) {
    // Fleet not yet submitted — show Submit button when all ships placed.
    if (!battle.fleetValid) {
      return SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: allPlaced ? onSubmitFleet : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: allPlaced ? Colors.black : const Color(0xFFCCCCCC),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFCCCCCC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            allPlaced ? 'Submit Fleet' : 'Place All Ships First',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Fleet valid — show Ready button.
    final isReady = battle.ready;
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isReady ? null : onSetReady,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isReady ? const Color(0xFF009900) : Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF009900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          isReady ? 'Waiting for opponent...' : 'Ready!',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
