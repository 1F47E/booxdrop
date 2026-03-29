package battleships

import (
	"testing"
)

// --- Fleet validation tests ---

func TestValidateFleet_Valid(t *testing.T) {
	fleet := standardFleet()
	if err := ValidateFleet(fleet, Width, Height); err != nil {
		t.Fatalf("expected valid fleet, got error: %v", err)
	}
}

func TestValidateFleet_WrongCount(t *testing.T) {
	fleet := standardFleet()[:3] // only 3 ships
	if err := ValidateFleet(fleet, Width, Height); err == nil {
		t.Fatal("expected error for 3-ship fleet, got nil")
	}
}

func TestValidateFleet_Overlap(t *testing.T) {
	fleet := []ShipPlacement{
		{Type: ShipCarrier, Cells: []Point{{0, 0}, {1, 0}, {2, 0}, {3, 0}}},
		{Type: ShipBattleship, Cells: []Point{{2, 0}, {3, 0}, {4, 0}}}, // overlaps at (2,0),(3,0)
		{Type: ShipCruiser, Cells: []Point{{0, 4}, {1, 4}}},
		{Type: ShipSub, Cells: []Point{{0, 6}, {1, 6}}},
	}
	if err := ValidateFleet(fleet, Width, Height); err == nil {
		t.Fatal("expected overlap error, got nil")
	}
}

func TestValidateFleet_OutOfBounds(t *testing.T) {
	fleet := []ShipPlacement{
		{Type: ShipCarrier, Cells: []Point{{5, 0}, {6, 0}, {7, 0}, {8, 0}}}, // X=8 is out of bounds
		{Type: ShipBattleship, Cells: []Point{{0, 2}, {1, 2}, {2, 2}}},
		{Type: ShipCruiser, Cells: []Point{{0, 4}, {1, 4}}},
		{Type: ShipSub, Cells: []Point{{0, 6}, {1, 6}}},
	}
	if err := ValidateFleet(fleet, Width, Height); err == nil {
		t.Fatal("expected out-of-bounds error, got nil")
	}
}

func TestValidateFleet_DiagonalAdjacency(t *testing.T) {
	fleet := []ShipPlacement{
		{Type: ShipCarrier, Cells: []Point{{0, 0}, {1, 0}, {2, 0}, {3, 0}}},
		// Battleship starts at (4,1) — diagonally adjacent to Carrier's (3,0)
		{Type: ShipBattleship, Cells: []Point{{4, 1}, {5, 1}, {6, 1}}},
		{Type: ShipCruiser, Cells: []Point{{0, 4}, {1, 4}}},
		{Type: ShipSub, Cells: []Point{{0, 6}, {1, 6}}},
	}
	if err := ValidateFleet(fleet, Width, Height); err == nil {
		t.Fatal("expected diagonal adjacency error, got nil")
	}
}

func TestValidateFleet_NotContiguous(t *testing.T) {
	fleet := []ShipPlacement{
		{Type: ShipCarrier, Cells: []Point{{0, 0}, {1, 0}, {3, 0}, {4, 0}}}, // gap at X=2
		{Type: ShipBattleship, Cells: []Point{{0, 2}, {1, 2}, {2, 2}}},
		{Type: ShipCruiser, Cells: []Point{{0, 4}, {1, 4}}},
		{Type: ShipSub, Cells: []Point{{0, 6}, {1, 6}}},
	}
	if err := ValidateFleet(fleet, Width, Height); err == nil {
		t.Fatal("expected non-contiguous error, got nil")
	}
}

func TestValidateFleet_WrongSize(t *testing.T) {
	fleet := []ShipPlacement{
		{Type: ShipCarrier, Cells: []Point{{0, 0}, {1, 0}, {2, 0}}}, // Carrier should be size 4
		{Type: ShipBattleship, Cells: []Point{{0, 2}, {1, 2}, {2, 2}}},
		{Type: ShipCruiser, Cells: []Point{{0, 4}, {1, 4}}},
		{Type: ShipSub, Cells: []Point{{0, 6}, {1, 6}}},
	}
	if err := ValidateFleet(fleet, Width, Height); err == nil {
		t.Fatal("expected wrong-size error, got nil")
	}
}

// --- Shot processing tests ---

func TestFireShot_Miss(t *testing.T) {
	g := NewGrid()
	ship := ShipPlacement{Type: ShipSub, Cells: []Point{{0, 0}, {1, 0}}}
	_ = g.PlaceShip(&ship)

	result, _, _, gameOver := g.FireShot(5, 5)
	if result != "miss" {
		t.Fatalf("expected miss, got %q", result)
	}
	if gameOver {
		t.Fatal("expected gameOver=false")
	}
	if g.Cells[5][5] != CellMiss {
		t.Fatal("expected CellMiss at (5,5)")
	}
}

func TestFireShot_Hit(t *testing.T) {
	g := NewGrid()
	ship := ShipPlacement{Type: ShipCruiser, Cells: []Point{{2, 3}, {3, 3}}}
	_ = g.PlaceShip(&ship)

	result, _, _, gameOver := g.FireShot(2, 3)
	if result != "hit" {
		t.Fatalf("expected hit, got %q", result)
	}
	if gameOver {
		t.Fatal("expected gameOver=false")
	}
	if g.Cells[3][2] != CellHit {
		t.Fatal("expected CellHit at (2,3)")
	}
}

func TestFireShot_Sunk(t *testing.T) {
	g := NewGrid()
	ship := ShipPlacement{Type: ShipSub, Cells: []Point{{0, 0}, {1, 0}}}
	_ = g.PlaceShip(&ship)

	// Hit both cells
	r1, _, _, _ := g.FireShot(0, 0)
	if r1 != "hit" {
		t.Fatalf("first shot: expected hit, got %q", r1)
	}

	r2, shipType, sunkCells, gameOver := g.FireShot(1, 0)
	if r2 != "sunk" {
		t.Fatalf("second shot: expected sunk, got %q", r2)
	}
	if shipType != "Sub" {
		t.Fatalf("expected shipType=Sub, got %q", shipType)
	}
	if len(sunkCells) != 2 {
		t.Fatalf("expected 2 sunkCells, got %d", len(sunkCells))
	}
	if !gameOver {
		t.Fatal("expected gameOver=true (only one ship on grid)")
	}
	// Both cells should be CellSunk
	for _, pt := range sunkCells {
		if g.Cells[pt.Y][pt.X] != CellSunk {
			t.Fatalf("expected CellSunk at (%d,%d)", pt.X, pt.Y)
		}
	}
}

func TestFireShot_AllShipsSunk(t *testing.T) {
	fleet := standardFleet()
	g := NewGrid()
	for i := range fleet {
		if err := g.PlaceShip(&fleet[i]); err != nil {
			t.Fatalf("PlaceShip: %v", err)
		}
	}

	// Sink all ships
	var gameOver bool
	for _, ship := range fleet {
		for _, pt := range ship.Cells {
			_, _, _, gameOver = g.FireShot(pt.X, pt.Y)
		}
	}

	if !gameOver {
		t.Fatal("expected gameOver=true after sinking all ships")
	}
	if !g.AllShipsSunk() {
		t.Fatal("expected AllShipsSunk()=true")
	}
}

func TestAllShipsSunk_EmptyGrid(t *testing.T) {
	g := NewGrid()
	if g.AllShipsSunk() {
		t.Fatal("empty grid should not report AllShipsSunk")
	}
}

// --- BattleState tests ---

func TestNewBattleState(t *testing.T) {
	fleet := standardFleet()
	bs := NewBattleState(fleet)

	if bs.ShipsRemaining != 4 {
		t.Fatalf("expected ShipsRemaining=4, got %d", bs.ShipsRemaining)
	}
	if bs.ShotsFired != 0 {
		t.Fatalf("expected ShotsFired=0, got %d", bs.ShotsFired)
	}
	if bs.Hits != 0 {
		t.Fatalf("expected Hits=0, got %d", bs.Hits)
	}
	if bs.MyGrid == nil {
		t.Fatal("MyGrid should not be nil")
	}
	if bs.TargetGrid == nil {
		t.Fatal("TargetGrid should not be nil")
	}
}

// --- helpers ---

// standardFleet returns a well-spread valid fleet for testing.
// Ships are placed with at least 2 cells of separation.
func standardFleet() []ShipPlacement {
	return []ShipPlacement{
		{
			Type:  ShipCarrier,
			Cells: []Point{{0, 0}, {1, 0}, {2, 0}, {3, 0}},
		},
		{
			Type:  ShipBattleship,
			Cells: []Point{{0, 2}, {1, 2}, {2, 2}},
		},
		{
			Type:  ShipCruiser,
			Cells: []Point{{0, 4}, {1, 4}},
		},
		{
			Type:  ShipSub,
			Cells: []Point{{0, 6}, {1, 6}},
		},
	}
}

func TestSimFleet(t *testing.T) {
	// Bob's fleet from the sim
	fleet := []ShipPlacement{
		{Type: ShipCarrier, Cells: []Point{{2,2},{3,2},{4,2},{5,2}}},
		{Type: ShipBattleship, Cells: []Point{{0,0},{1,0},{2,0}}},
		{Type: ShipCruiser, Cells: []Point{{3,6},{4,6}}},
		{Type: ShipSub, Cells: []Point{{4,4},{5,4}}},
	}
	
	if err := ValidateFleet(fleet, Width, Height); err != nil {
		t.Fatalf("fleet invalid: %v", err)
	}

	bs := NewBattleState(fleet)
	
	// Fire at (1,2) — should be MISS (no ship there)
	r, _, _, _ := bs.MyGrid.FireShot(1, 2)
	if r != "miss" {
		t.Fatalf("(1,2) expected miss, got %s. Cell was %d", r, bs.MyGrid.Cells[2][1])
	}
	
	// Fire at (2,2) — carrier cell, should be HIT
	r, _, _, _ = bs.MyGrid.FireShot(2, 2)
	if r != "hit" {
		t.Fatalf("(2,2) expected hit, got %s", r)
	}
}

func TestSubSinkExact(t *testing.T) {
	fleet := []ShipPlacement{
		{Type: ShipCarrier, Cells: []Point{{0,5},{1,5},{2,5},{3,5}}},
		{Type: ShipBattleship, Cells: []Point{{0,3},{1,3},{2,3}}},
		{Type: ShipCruiser, Cells: []Point{{3,0},{4,0}}},
		{Type: ShipSub, Cells: []Point{{0,0},{1,0}}},
	}
	
	bs := NewBattleState(fleet)
	t.Logf("Cell (0,0)=%d, (1,0)=%d", bs.MyGrid.Cells[0][0], bs.MyGrid.Cells[0][1])
	
	r1, _, _, _ := bs.MyGrid.FireShot(0, 0)
	t.Logf("Shot (0,0): %s, cell now=%d", r1, bs.MyGrid.Cells[0][0])
	
	r2, shipType, _, gameOver := bs.MyGrid.FireShot(1, 0)
	t.Logf("Shot (1,0): %s, shipType=%s, gameOver=%v", r2, shipType, gameOver)
	
	if r2 != "sunk" {
		for i, ship := range fleet {
			for _, c := range ship.Cells {
				cell := bs.MyGrid.Cells[c.Y][c.X]
				t.Logf("  Ship %d (%s) cell (%d,%d) = %d", i, ship.Type.Name, c.X, c.Y, cell)
			}
		}
		t.Fatalf("Expected sunk, got %s", r2)
	}
}
