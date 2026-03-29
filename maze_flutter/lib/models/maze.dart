class Point {
  final int x;
  final int y;
  const Point(this.x, this.y);

  Point operator +(Point other) => Point(x + other.x, y + other.y);

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  Map<String, int> toJson() => {'x': x, 'y': y};

  factory Point.fromJson(Map<String, dynamic> json) =>
      Point(json['x'] as int, json['y'] as int);
}

class Tile {
  static const int floor = 0;
  static const int wall = 1;
  static const int key = 2;
  static const int door = 3;
  static const int treasure = 4;
  static const int hidden = -1;
  static const int openDoor = 5;
  static const int start = 6;
}

class Maze {
  static const int width = 7;
  static const int height = 7;

  final List<List<int>> cells;

  Maze() : cells = List.generate(height, (_) => List.filled(width, Tile.floor)) {
    cells[0][0] = Tile.start; // default start position
  }

  Maze.from(List<List<int>> data)
      : cells = data.map((r) => List<int>.from(r)).toList();

  int get(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return -1;
    return cells[y][x];
  }

  void set(int x, int y, int tile) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      cells[y][x] = tile;
    }
  }

  int countTile(int tile) {
    int count = 0;
    for (final row in cells) {
      for (final c in row) {
        if (c == tile) count++;
      }
    }
    return count;
  }

  bool get hasKey => countTile(Tile.key) == 1;
  bool get hasDoor => countTile(Tile.door) == 1;
  bool get hasTreasure => countTile(Tile.treasure) == 1;
  bool get hasStart => countTile(Tile.start) == 1;

  Point get startPos => _findTile(Tile.start) ?? const Point(0, 0);

  bool get hasRequiredTiles =>
      hasKey && hasDoor && hasTreasure && hasStart && countTile(Tile.wall) <= 20;

  bool get isLocallyValid => hasRequiredTiles && isSolvable;

  /// BFS solvability: start→key (no door), key→door (no door blocking),
  /// door→treasure (door open).
  bool get isSolvable {
    if (!hasRequiredTiles) return false;
    final keyPos = _findTile(Tile.key);
    final doorPos = _findTile(Tile.door);
    final treasurePos = _findTile(Tile.treasure);
    if (keyPos == null || doorPos == null || treasurePos == null) return false;

    return _canReach(startPos, keyPos, doorOpen: false) &&
        _canReach(keyPos, doorPos, doorOpen: false) &&
        _canReach(doorPos, treasurePos, doorOpen: true);
  }

  /// Human-readable validation error, or null if valid.
  String? get validationError {
    if (!hasStart) return 'Place a start tile';
    if (!hasKey) return 'Place a key';
    if (!hasDoor) return 'Place a door';
    if (!hasTreasure) return 'Place a treasure';
    if (countTile(Tile.wall) > 20) return 'Too many walls (max 20)';

    final keyPos = _findTile(Tile.key);
    final doorPos = _findTile(Tile.door);
    final treasurePos = _findTile(Tile.treasure);

    if (!_canReach(startPos, keyPos!, doorOpen: false)) {
      return "Can't reach the key from start";
    }
    if (!_canReach(keyPos, doorPos!, doorOpen: false)) {
      return "Can't reach the door from key";
    }
    if (!_canReach(doorPos, treasurePos!, doorOpen: true)) {
      return "Can't reach the treasure from door";
    }
    return null;
  }

  Point? _findTile(int tile) {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (get(x, y) == tile) return Point(x, y);
      }
    }
    return null;
  }

  bool _canReach(Point from, Point to, {required bool doorOpen}) {
    if (from == to) return true;
    final visited = List.generate(height, (_) => List.filled(width, false));
    final queue = <Point>[from];
    visited[from.y][from.x] = true;
    const dirs = [Point(0, 1), Point(0, -1), Point(-1, 0), Point(1, 0)];

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final d in dirs) {
        final nx = cur.x + d.x, ny = cur.y + d.y;
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if (visited[ny][nx]) continue;
        final next = Point(nx, ny);
        if (next == to) return true;
        final tile = get(nx, ny);
        if (tile == Tile.wall) continue;
        if (tile == Tile.door && !doorOpen) continue;
        visited[ny][nx] = true;
        queue.add(next);
      }
    }
    return false;
  }

  List<List<int>> toJson() => cells;

  Maze copy() => Maze.from(cells);
}

class SavedMaze {
  final String id;
  final String name;
  final List<List<int>> cells;
  final DateTime createdAt;

  SavedMaze({
    required this.id,
    required this.name,
    required this.cells,
    required this.createdAt,
  });

  factory SavedMaze.fromJson(Map<String, dynamic> json) => SavedMaze(
    id: json['id'] as String,
    name: json['name'] as String,
    cells: (json['cells'] as List).map((r) => List<int>.from(r as List)).toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cells': cells,
    'created_at': createdAt.toIso8601String(),
  };

  Maze toMaze() => Maze.from(cells);
}
