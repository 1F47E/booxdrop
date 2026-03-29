package battleships

import "fmt"

// ShipType describes a kind of ship.
type ShipType struct {
	Name string
	Size int
}

// The four ship types used in a standard fleet.
var (
	ShipCarrier    = ShipType{Name: "Carrier", Size: 4}
	ShipBattleship = ShipType{Name: "Battleship", Size: 3}
	ShipCruiser    = ShipType{Name: "Cruiser", Size: 2}
	ShipSub        = ShipType{Name: "Sub", Size: 2}
)

// FleetShipTypes is the required fleet, in order, for validation.
var FleetShipTypes = []ShipType{ShipCarrier, ShipBattleship, ShipCruiser, ShipSub}

// ShipPlacement holds a ship's type and the cells it occupies.
type ShipPlacement struct {
	Type  ShipType `json:"type"`
	Cells []Point  `json:"cells"`
}

// ValidateFleet validates a full fleet of ships:
//   - Exactly 4 ships matching Carrier(4), Battleship(3), Cruiser(2), Sub(2)
//   - All cells within bounds
//   - Each ship is a contiguous horizontal or vertical line
//   - No overlap between ships
//   - No diagonal adjacency between different ships
func ValidateFleet(ships []ShipPlacement, gridWidth, gridHeight int) error {
	if len(ships) != 4 {
		return fmt.Errorf("fleet must contain exactly 4 ships, got %d", len(ships))
	}

	// Validate each ship individually
	for i, ship := range ships {
		if err := validateShipPlacement(ship, gridWidth, gridHeight); err != nil {
			return fmt.Errorf("ship %d (%s): %w", i, ship.Type.Name, err)
		}
	}

	// Check fleet has exactly the required ship types
	if err := validateFleetComposition(ships); err != nil {
		return err
	}

	// Check overlap
	if err := validateNoOverlap(ships); err != nil {
		return err
	}

	// Check no diagonal adjacency between different ships
	if err := validateNoAdjacentShips(ships); err != nil {
		return err
	}

	return nil
}

// validateShipPlacement checks bounds, size match, and contiguity.
func validateShipPlacement(ship ShipPlacement, gridWidth, gridHeight int) error {
	if len(ship.Cells) != ship.Type.Size {
		return fmt.Errorf("expected %d cells, got %d", ship.Type.Size, len(ship.Cells))
	}

	for _, pt := range ship.Cells {
		if pt.X < 0 || pt.X >= gridWidth || pt.Y < 0 || pt.Y >= gridHeight {
			return fmt.Errorf("cell (%d,%d) out of bounds", pt.X, pt.Y)
		}
	}

	if len(ship.Cells) == 1 {
		return nil // single-cell ships are trivially contiguous
	}

	// Determine orientation: all same X (vertical) or all same Y (horizontal)
	allSameX := true
	allSameY := true
	for _, pt := range ship.Cells {
		if pt.X != ship.Cells[0].X {
			allSameX = false
		}
		if pt.Y != ship.Cells[0].Y {
			allSameY = false
		}
	}

	if !allSameX && !allSameY {
		return fmt.Errorf("ship cells are not aligned horizontally or vertically")
	}

	// Check contiguity: the cells should form a consecutive sequence
	if allSameX {
		// Vertical — check consecutive Y values
		ys := make([]int, len(ship.Cells))
		for i, pt := range ship.Cells {
			ys[i] = pt.Y
		}
		if err := checkConsecutive(ys); err != nil {
			return fmt.Errorf("vertical ship not contiguous: %w", err)
		}
	} else {
		// Horizontal — check consecutive X values
		xs := make([]int, len(ship.Cells))
		for i, pt := range ship.Cells {
			xs[i] = pt.X
		}
		if err := checkConsecutive(xs); err != nil {
			return fmt.Errorf("horizontal ship not contiguous: %w", err)
		}
	}

	return nil
}

// checkConsecutive verifies that a slice of ints forms a contiguous run
// (any order is accepted — we sort logically by checking min/max span).
func checkConsecutive(vals []int) error {
	min, max := vals[0], vals[0]
	seen := make(map[int]bool)
	for _, v := range vals {
		if v < min {
			min = v
		}
		if v > max {
			max = v
		}
		if seen[v] {
			return fmt.Errorf("duplicate coordinate %d", v)
		}
		seen[v] = true
	}
	if max-min != len(vals)-1 {
		return fmt.Errorf("coordinates are not consecutive (%d..%d for %d cells)", min, max, len(vals))
	}
	return nil
}

// validateFleetComposition checks that exactly the required ship types are present.
func validateFleetComposition(ships []ShipPlacement) error {
	required := map[string]int{
		ShipCarrier.Name:    ShipCarrier.Size,
		ShipBattleship.Name: ShipBattleship.Size,
		ShipCruiser.Name:    ShipCruiser.Size,
		ShipSub.Name:        ShipSub.Size,
	}

	count := make(map[string]int)
	for _, ship := range ships {
		count[ship.Type.Name]++
		// Verify size matches the expected size for that name
		req, ok := required[ship.Type.Name]
		if !ok {
			return fmt.Errorf("unknown ship type: %q", ship.Type.Name)
		}
		if ship.Type.Size != req {
			return fmt.Errorf("ship %q has wrong size %d (expected %d)", ship.Type.Name, ship.Type.Size, req)
		}
	}

	for name := range required {
		if count[name] != 1 {
			return fmt.Errorf("fleet must have exactly 1 %s, got %d", name, count[name])
		}
	}

	return nil
}

// validateNoOverlap ensures no two ships share a cell.
func validateNoOverlap(ships []ShipPlacement) error {
	occupied := make(map[[2]int]string) // [x,y] -> ship name
	for _, ship := range ships {
		for _, pt := range ship.Cells {
			key := [2]int{pt.X, pt.Y}
			if existing, ok := occupied[key]; ok {
				return fmt.Errorf("ships %q and %q overlap at (%d,%d)", existing, ship.Type.Name, pt.X, pt.Y)
			}
			occupied[key] = ship.Type.Name
		}
	}
	return nil
}

// validateNoAdjacentShips ensures no two different ships are diagonally adjacent
// (orthogonal adjacency is also disallowed, as in strict Battleships rules).
func validateNoAdjacentShips(ships []ShipPlacement) error {
	// Build a map of cell -> ship index
	cellToShip := make(map[[2]int]int)
	for i, ship := range ships {
		for _, pt := range ship.Cells {
			cellToShip[[2]int{pt.X, pt.Y}] = i
		}
	}

	// All 8 neighbors (including diagonals)
	directions := [][2]int{
		{-1, -1}, {0, -1}, {1, -1},
		{-1, 0}, {1, 0},
		{-1, 1}, {0, 1}, {1, 1},
	}

	for i, ship := range ships {
		for _, pt := range ship.Cells {
			for _, d := range directions {
				neighbor := [2]int{pt.X + d[0], pt.Y + d[1]}
				if j, ok := cellToShip[neighbor]; ok && j != i {
					return fmt.Errorf("ships %q and %q are adjacent at (%d,%d)",
						ship.Type.Name, ships[j].Type.Name, pt.X, pt.Y)
				}
			}
		}
	}

	return nil
}
