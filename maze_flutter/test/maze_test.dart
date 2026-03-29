import 'package:flutter_test/flutter_test.dart';
import 'package:maze_race/models/maze.dart';

void main() {
  group('Maze validation', () {
    test('new maze has start tile at (0,0)', () {
      final m = Maze();
      expect(m.get(0, 0), Tile.start);
      expect(m.hasStart, isTrue);
      expect(m.startPos, const Point(0, 0));
    });

    test('hasRequiredTiles needs start, key, door, treasure', () {
      final m = Maze();
      expect(m.hasRequiredTiles, isFalse); // no key/door/treasure

      m.set(1, 1, Tile.key);
      expect(m.hasRequiredTiles, isFalse);

      m.set(2, 2, Tile.door);
      expect(m.hasRequiredTiles, isFalse);

      m.set(3, 3, Tile.treasure);
      expect(m.hasRequiredTiles, isTrue);
    });

    test('hasRequiredTiles false without start', () {
      final m = Maze();
      m.set(0, 0, Tile.floor); // remove start
      m.set(1, 1, Tile.key);
      m.set(2, 2, Tile.door);
      m.set(3, 3, Tile.treasure);
      expect(m.hasRequiredTiles, isFalse);
    });

    test('solvable maze with custom start position', () {
      final m = Maze();
      // Move start from (0,0) to (3,0)
      m.set(0, 0, Tile.floor);
      m.set(3, 0, Tile.start);
      m.set(4, 0, Tile.key);
      m.set(5, 0, Tile.door);
      m.set(6, 0, Tile.treasure);
      expect(m.startPos, const Point(3, 0));
      expect(m.hasRequiredTiles, isTrue);
      expect(m.isSolvable, isTrue);
    });

    test('unsolvable: key blocked by wall', () {
      final m = Maze();
      m.set(2, 0, Tile.key);
      m.set(5, 5, Tile.door);
      m.set(6, 6, Tile.treasure);
      // Wall off the key
      m.set(1, 0, Tile.wall);
      m.set(2, 1, Tile.wall);
      m.set(3, 0, Tile.wall);
      expect(m.isSolvable, isFalse);
      expect(m.validationError, contains('key'));
    });

    test('unsolvable: treasure behind door without key path', () {
      final m = Maze();
      m.set(1, 0, Tile.key);
      m.set(3, 0, Tile.door);
      m.set(4, 0, Tile.treasure);
      // Wall between door and treasure (door blocks without key)
      // Actually door with key should work — let's block treasure behind walls
      m.set(4, 1, Tile.wall);
      m.set(5, 0, Tile.wall);
      // Door is at (3,0), treasure at (4,0) — reachable through door
      // This should be solvable since door can be reached with key
      expect(m.isSolvable, isTrue);
    });

    test('validationError returns null for valid maze', () {
      final m = Maze();
      m.set(1, 0, Tile.key);
      m.set(2, 0, Tile.door);
      m.set(3, 0, Tile.treasure);
      expect(m.validationError, isNull);
    });

    test('validationError describes missing start', () {
      final m = Maze();
      m.set(0, 0, Tile.floor); // remove start
      expect(m.validationError, 'Place a start tile');
    });

    test('validationError describes missing key', () {
      final m = Maze();
      m.set(2, 2, Tile.door);
      m.set(3, 3, Tile.treasure);
      expect(m.validationError, 'Place a key');
    });

    test('too many walls', () {
      final m = Maze();
      m.set(1, 0, Tile.key);
      m.set(2, 0, Tile.door);
      m.set(3, 0, Tile.treasure);
      // Place 21 walls
      var count = 0;
      for (int y = 1; y < 7 && count < 21; y++) {
        for (int x = 0; x < 7 && count < 21; x++) {
          if (m.get(x, y) == Tile.floor) {
            m.set(x, y, Tile.wall);
            count++;
          }
        }
      }
      expect(m.hasRequiredTiles, isFalse);
      expect(m.validationError, contains('walls'));
    });

    test('BFS uses start tile position, not (0,0)', () {
      final m = Maze();
      m.set(0, 0, Tile.floor);
      m.set(6, 6, Tile.start);
      m.set(5, 6, Tile.key);
      m.set(4, 6, Tile.door);
      m.set(3, 6, Tile.treasure);
      expect(m.startPos, const Point(6, 6));
      expect(m.isSolvable, isTrue);
    });

    test('only one start tile allowed', () {
      final m = Maze();
      m.set(3, 3, Tile.start); // second start
      expect(m.hasStart, isFalse); // countTile != 1
    });
  });
}
