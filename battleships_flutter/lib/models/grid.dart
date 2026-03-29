class CellState {
  static const int empty = 0;
  static const int ship = 1;
  static const int hit = 2;
  static const int miss = 3;
  static const int sunk = 4;
}

class BattleGrid {
  static const int size = 8;

  final List<List<int>> cells;

  BattleGrid()
      : cells = List.generate(
          size,
          (_) => List.filled(size, CellState.empty),
        );

  /// Creates a BattleGrid from a 2-D list received from the server.
  BattleGrid.fromCells(List<List<int>> source)
      : cells = List.generate(
          size,
          (y) => List.generate(size, (x) {
            if (y < source.length && x < source[y].length) {
              return source[y][x];
            }
            return CellState.empty;
          }),
        );

  int get(int x, int y) => cells[y][x];

  void set(int x, int y, int state) {
    cells[y][x] = state;
  }
}
