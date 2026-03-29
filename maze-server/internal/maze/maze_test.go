package maze

import "testing"

// Helper: create a valid test maze.
// Layout (y=0 is bottom, x left to right):
//
//	y=6: . . . . . . T
//	y=5: . 1 1 1 1 . .
//	y=4: . . . . D . .
//	y=3: . . . . . . .
//	y=2: . K . 1 1 1 1
//	y=1: . . . . . . .
//	y=0: S . . . . . .
//
// S=start(0,0), K=key(1,2), D=door(4,4), T=treasure(6,6)
// Path start->key: (0,0)->(1,0)->(1,1)->(1,2)=key [3 moves]
// Path key->door: (1,2)->(1,3)->(2,3)->(3,3)->(4,3)->(4,4)=door [5 moves, no door blocking]
// Path door->treasure: (4,4)->(5,4)->(5,5)->(5,6)->(6,6)=treasure [4 moves]
// Total: 12 moves >= 8 minimum
func validTestMaze() *Maze {
	m := NewMaze(7, 7)
	// Row y=2 walls (block direct east path from key)
	m.Set(3, 2, TileWall)
	m.Set(4, 2, TileWall)
	m.Set(5, 2, TileWall)
	m.Set(6, 2, TileWall)
	// Row y=5 walls (force path around)
	m.Set(1, 5, TileWall)
	m.Set(2, 5, TileWall)
	m.Set(3, 5, TileWall)
	m.Set(4, 5, TileWall)
	// Key at (1,2)
	m.Set(1, 2, TileKey)
	// Door at (4,4)
	m.Set(4, 4, TileDoor)
	// Treasure at (6,6)
	m.Set(6, 6, TileTreasure)
	// Start at (0,0)
	m.Set(0, 0, TileStart)
	return m
}

func TestTileEncoding(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(3, 4, TileWall)
	if m.Get(3, 4) != TileWall {
		t.Errorf("expected wall at (3,4), got %d", m.Get(3, 4))
	}
	if m.Get(0, 0) != TileFloor {
		t.Errorf("expected floor at (0,0), got %d", m.Get(0, 0))
	}
	// Out of bounds
	if m.Get(-1, 0) != -1 {
		t.Errorf("expected -1 for out of bounds")
	}
}

func TestStartPos(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(0, 0, TileStart)
	s := m.StartPos()
	if s.X != 0 || s.Y != 0 {
		t.Errorf("start should be (0,0), got (%d,%d)", s.X, s.Y)
	}
}

func TestValidMaze(t *testing.T) {
	m := validTestMaze()
	if err := m.Validate(); err != nil {
		t.Errorf("expected valid maze, got: %v", err)
	}
}

func TestInvalidMaze_NoKey(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(4, 4, TileDoor)
	m.Set(4, 6, TileTreasure)
	err := m.Validate()
	if err == nil {
		t.Error("expected error for missing key")
	}
}

func TestInvalidMaze_NoDoor(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(1, 2, TileKey)
	m.Set(4, 6, TileTreasure)
	err := m.Validate()
	if err == nil {
		t.Error("expected error for missing door")
	}
}

func TestInvalidMaze_NoTreasure(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(1, 2, TileKey)
	m.Set(4, 4, TileDoor)
	err := m.Validate()
	if err == nil {
		t.Error("expected error for missing treasure")
	}
}

func TestInvalidMaze_MultipleKeys(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(1, 2, TileKey)
	m.Set(2, 2, TileKey)
	m.Set(4, 4, TileDoor)
	m.Set(4, 6, TileTreasure)
	err := m.Validate()
	if err == nil {
		t.Error("expected error for multiple keys")
	}
}

func TestInvalidMaze_StartBlocked(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(0, 0, TileWall)
	m.Set(1, 2, TileKey)
	m.Set(4, 4, TileDoor)
	m.Set(4, 6, TileTreasure)
	err := m.Validate()
	if err == nil {
		t.Error("expected error for blocked start")
	}
}

func TestInvalidMaze_KeyUnreachable(t *testing.T) {
	m := NewMaze(7, 7)
	// Surround key with walls
	m.Set(3, 3, TileKey)
	m.Set(2, 3, TileWall)
	m.Set(4, 3, TileWall)
	m.Set(3, 2, TileWall)
	m.Set(3, 4, TileWall)
	m.Set(5, 5, TileDoor)
	m.Set(6, 6, TileTreasure)
	err := m.Validate()
	if err == nil {
		t.Error("expected error for unreachable key")
	}
}

func TestInvalidMaze_TooManyWalls(t *testing.T) {
	m := NewMaze(7, 7)
	// Place 21 walls
	count := 0
	for y := 1; y < 7 && count < 21; y++ {
		for x := 0; x < 7 && count < 21; x++ {
			if x == 0 && y == 0 {
				continue
			}
			m.Set(x, y, TileWall)
			count++
		}
	}
	m.Set(1, 0, TileKey)
	m.Set(2, 0, TileDoor)
	m.Set(3, 0, TileTreasure)
	err := m.Validate()
	if err == nil {
		t.Error("expected error for too many walls")
	}
}

func TestInvalidMaze_TooEasy(t *testing.T) {
	// All objects adjacent to start — trivial path
	m := NewMaze(7, 7)
	m.Set(1, 0, TileKey)
	m.Set(2, 0, TileDoor)
	m.Set(3, 0, TileTreasure)
	err := m.Validate()
	if err == nil {
		t.Error("expected error for too-easy maze")
	}
}

func TestShortestPath(t *testing.T) {
	m := validTestMaze()
	// Start (0,0) to key (1,2)
	dist := m.shortestPath(m.StartPos(), Point{1, 2}, false)
	if dist < 0 {
		t.Error("expected reachable path from start to key")
	}
	t.Logf("start->key distance: %d", dist)
}

func TestReachability_DoorBlocks(t *testing.T) {
	m := validTestMaze()
	door := Point{4, 4}
	treasure := Point{6, 6}
	distNoDoor := m.shortestPath(door, treasure, false)
	distWithDoor := m.shortestPath(door, treasure, true)
	t.Logf("door->treasure (closed): %d, (open): %d", distNoDoor, distWithDoor)
	if distWithDoor < 0 {
		t.Error("treasure should be reachable from door when open")
	}
}
