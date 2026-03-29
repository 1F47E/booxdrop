package battleships

import "fmt"

// Grid dimensions.
const (
	Width  = 8
	Height = 8
)

// Cell state constants.
const (
	CellEmpty = 0
	CellShip  = 1
	CellHit   = 2
	CellMiss  = 3
	CellSunk  = 4
)

// Point is a grid coordinate.
type Point struct {
	X int `json:"x"`
	Y int `json:"y"`
}

// Grid holds the state of an 8x8 battleships grid.
type Grid struct {
	Cells      [][]int
	ships      []*ShipPlacement
	sunkShips  map[int]bool // index into ships slice
}

// NewGrid creates an empty 8x8 grid.
func NewGrid() *Grid {
	cells := make([][]int, Height)
	for i := range cells {
		cells[i] = make([]int, Width)
	}
	return &Grid{
		Cells:     cells,
		ships:     nil,
		sunkShips: make(map[int]bool),
	}
}

// PlaceShip places a ship on the grid, validating for overlap.
func (g *Grid) PlaceShip(ship *ShipPlacement) error {
	for _, pt := range ship.Cells {
		if pt.X < 0 || pt.X >= Width || pt.Y < 0 || pt.Y >= Height {
			return fmt.Errorf("cell (%d,%d) out of bounds", pt.X, pt.Y)
		}
		if g.Cells[pt.Y][pt.X] != CellEmpty {
			return fmt.Errorf("cell (%d,%d) already occupied", pt.X, pt.Y)
		}
	}
	for _, pt := range ship.Cells {
		g.Cells[pt.Y][pt.X] = CellShip
	}
	g.ships = append(g.ships, ship)
	return nil
}

// FireShot processes a shot at (x, y).
// Returns:
//   - result: "hit", "miss", or "sunk"
//   - shipType: name of ship if sunk
//   - sunkCells: all cells of the ship if sunk
//   - gameOver: true when all ships are sunk
func (g *Grid) FireShot(x, y int) (result string, shipType string, sunkCells []Point, gameOver bool) {
	if x < 0 || x >= Width || y < 0 || y >= Height {
		return "miss", "", nil, false
	}

	cell := g.Cells[y][x]

	if cell == CellEmpty {
		g.Cells[y][x] = CellMiss
		return "miss", "", nil, false
	}

	if cell == CellHit || cell == CellMiss || cell == CellSunk {
		// Already fired here — treat as miss (no-op logically, but shouldn't happen in normal play)
		return "miss", "", nil, false
	}

	// It's a ship cell
	g.Cells[y][x] = CellHit

	// Check if the ship this cell belongs to is now fully sunk
	for i, ship := range g.ships {
		if g.sunkShips[i] {
			continue
		}
		if !shipContainsPoint(ship.Cells, Point{X: x, Y: y}) {
			continue
		}
		// This ship was hit — check if all its cells are hit
		if g.allCellsHit(ship.Cells) {
			g.sunkShips[i] = true
			// Mark all cells as sunk
			for _, pt := range ship.Cells {
				g.Cells[pt.Y][pt.X] = CellSunk
			}
			gameOver = g.AllShipsSunk()
			return "sunk", ship.Type.Name, ship.Cells, gameOver
		}
		return "hit", "", nil, false
	}

	// Hit something but no ship record (shouldn't happen)
	return "hit", "", nil, false
}

// AllShipsSunk returns true when every ship has been sunk.
func (g *Grid) AllShipsSunk() bool {
	if len(g.ships) == 0 {
		return false
	}
	return len(g.sunkShips) == len(g.ships)
}

// allCellsHit returns true if every cell in pts has been hit or sunk.
func (g *Grid) allCellsHit(pts []Point) bool {
	for _, pt := range pts {
		c := g.Cells[pt.Y][pt.X]
		if c != CellHit && c != CellSunk {
			return false
		}
	}
	return true
}

func shipContainsPoint(cells []Point, pt Point) bool {
	for _, c := range cells {
		if c.X == pt.X && c.Y == pt.Y {
			return true
		}
	}
	return false
}
