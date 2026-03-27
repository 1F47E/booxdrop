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
}

class Maze {
  static const int width = 7;
  static const int height = 7;

  final List<List<int>> cells;

  Maze() : cells = List.generate(height, (_) => List.filled(width, Tile.floor));

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
  bool get isStartFloor => get(0, 0) == Tile.floor;

  bool get isLocallyValid =>
      hasKey && hasDoor && hasTreasure && isStartFloor && countTile(Tile.wall) <= 20;

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
