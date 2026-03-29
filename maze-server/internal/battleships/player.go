package battleships

// BattleState holds a single player's view of the ongoing battle.
type BattleState struct {
	// MyGrid holds your placed ships and marks where the opponent has fired.
	MyGrid *Grid

	// TargetGrid is your view of the opponent's grid (only shows your shots).
	TargetGrid *Grid

	ShotsFired     int
	Hits           int
	ShipsRemaining int // starts at 4, decrements when a ship is sunk
	ShipsSunk      int
}

// NewBattleState creates a BattleState from the player's fleet.
// The fleet is validated before calling this; ships are placed onto MyGrid.
func NewBattleState(fleet []ShipPlacement) *BattleState {
	myGrid := NewGrid()
	for i := range fleet {
		// Errors are ignored here — fleet must already be validated.
		_ = myGrid.PlaceShip(&fleet[i])
	}

	return &BattleState{
		MyGrid:         myGrid,
		TargetGrid:     NewGrid(),
		ShotsFired:     0,
		Hits:           0,
		ShipsRemaining: len(fleet),
		ShipsSunk:      0,
	}
}
