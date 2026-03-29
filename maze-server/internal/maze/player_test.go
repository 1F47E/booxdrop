package maze

import "testing"

func TestNewPlayerState(t *testing.T) {
	m := NewMaze(7, 7)
	ps := NewPlayerState(m)
	if ps.Position != m.StartPos() {
		t.Errorf("expected start at (0,0), got (%d,%d)", ps.Position.X, ps.Position.Y)
	}
	if ps.HasKey {
		t.Error("should not have key at start")
	}
	// Start and neighbors should be revealed
	if ps.Revealed[0][0] == TileHidden {
		t.Error("start tile should be revealed")
	}
}

func TestMoveFloor(t *testing.T) {
	m := validTestMaze()
	ps := NewPlayerState(m)

	// Move right from (0,0) — should be floor
	result := ps.ProcessMove(m, DirRight)
	if !result.Moved {
		t.Error("should move to floor")
	}
	if result.Position.X != 1 || result.Position.Y != 0 {
		t.Errorf("expected (1,0), got (%d,%d)", result.Position.X, result.Position.Y)
	}
	if result.Event != EventNone {
		t.Errorf("expected no event, got %s", result.Event)
	}
}

func TestMoveWall(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(1, 0, TileWall) // wall to the right of start
	ps := NewPlayerState(m)

	// Move right from (0,0) — wall at (1,0)
	result := ps.ProcessMove(m, DirRight)
	if result.Moved {
		t.Error("should not move into wall")
	}
	if result.Event != EventHitWall {
		t.Errorf("expected hit_wall, got %s", result.Event)
	}
	// Wall should be revealed
	if ps.Revealed[0][1] != TileWall {
		t.Error("wall should be revealed after hitting it")
	}
}

func TestPickupKey(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(2, 0, TileKey) // key two steps right of start
	ps := NewPlayerState(m)

	// Move right twice to reach key at (2,0)
	ps.ProcessMove(m, DirRight)
	result := ps.ProcessMove(m, DirRight)

	if !result.HasKey {
		t.Error("should have picked up key")
	}
	if result.Event != EventFoundKey {
		t.Errorf("expected found_key, got %s", result.Event)
	}
}

func TestDoorLocked(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(1, 0, TileDoor)
	m.Set(2, 0, TileKey)
	m.Set(6, 6, TileTreasure)

	ps := NewPlayerState(m)

	// Try to walk into door without key
	result := ps.ProcessMove(m, DirRight)
	if result.Moved {
		t.Error("should not pass through locked door")
	}
	if result.Event != EventDoorLocked {
		t.Errorf("expected door_locked, got %s", result.Event)
	}
}

func TestDoorOpenWithKey(t *testing.T) {
	m := NewMaze(7, 7)
	// key at (0,1), door at (0,2), treasure at (0,6)
	m.Set(0, 1, TileKey)
	m.Set(0, 2, TileDoor)
	m.Set(0, 6, TileTreasure)

	ps := NewPlayerState(m)

	// Move up to key
	result := ps.ProcessMove(m, DirUp)
	if !result.HasKey {
		t.Error("should have key")
	}
	if result.Event != EventFoundKey {
		t.Errorf("expected found_key, got %s", result.Event)
	}

	// Move up to door — should open
	result = ps.ProcessMove(m, DirUp)
	if !result.Moved {
		t.Error("should move through door with key")
	}
	if result.Event != EventDoorOpened {
		t.Errorf("expected door_opened, got %s", result.Event)
	}
}

func TestTreasureWin(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(0, 1, TileKey)
	m.Set(0, 2, TileDoor)
	m.Set(0, 3, TileTreasure)

	ps := NewPlayerState(m)

	// Move up three times: key -> door -> treasure
	ps.ProcessMove(m, DirUp) // key
	ps.ProcessMove(m, DirUp) // door (has key)
	result := ps.ProcessMove(m, DirUp) // treasure

	if !result.GameOver {
		t.Error("should be game over")
	}
	if result.Event != EventFoundTreasure {
		t.Errorf("expected found_treasure, got %s", result.Event)
	}
}

func TestFogOfWar(t *testing.T) {
	m := NewMaze(7, 7)
	m.Set(3, 3, TileWall)

	ps := NewPlayerState(m)

	// At start (0,0), tiles at (0,0), (1,0), (0,1) should be revealed
	// Far away tile (3,3) should be hidden
	if ps.Revealed[3][3] != TileHidden {
		t.Error("distant tile should be hidden")
	}

	// Move right several times
	for i := 0; i < 3; i++ {
		ps.ProcessMove(m, DirRight)
	}
	// Now at (3,0) — (3,1) should be revealed but (3,3) still hidden
	if ps.Revealed[3][3] != TileHidden {
		t.Error("(3,3) should still be hidden from (3,0)")
	}
}

func TestOutOfBounds(t *testing.T) {
	m := NewMaze(7, 7)
	ps := NewPlayerState(m)

	// Try to move left from (0,0)
	result := ps.ProcessMove(m, DirLeft)
	if result.Moved {
		t.Error("should not move out of bounds")
	}

	// Try to move down from (0,0)
	result = ps.ProcessMove(m, DirDown)
	if result.Moved {
		t.Error("should not move out of bounds")
	}
}

func TestInvalidDirection(t *testing.T) {
	m := NewMaze(7, 7)
	ps := NewPlayerState(m)

	result := ps.ProcessMove(m, "diagonal")
	if result.Moved {
		t.Error("invalid direction should not move")
	}
}

func TestGetAllRevealed(t *testing.T) {
	m := NewMaze(7, 7)
	ps := NewPlayerState(m)
	revealed := ps.GetAllRevealed()
	// At start, should have at least the start tile revealed
	if len(revealed) == 0 {
		t.Error("should have revealed tiles at start")
	}
	// Check start is in the list
	found := false
	for _, r := range revealed {
		if r.X == 0 && r.Y == 0 {
			found = true
			break
		}
	}
	if !found {
		t.Error("start tile should be in revealed list")
	}
}
