package maze

// PlayerState tracks a player's race state.
type PlayerState struct {
	Position  Point  `json:"position"`
	HasKey    bool   `json:"has_key"`
	DoorOpen  bool   `json:"door_open"`
	MoveCount int    `json:"move_count"`
	Revealed  [][]int `json:"-"` // discovered tile codes per cell
}

// RevealedTile represents a single revealed tile for JSON payloads.
type RevealedTile struct {
	X    int `json:"x"`
	Y    int `json:"y"`
	Tile int `json:"tile"`
}

// MoveResult is returned by ProcessMove.
type MoveResult struct {
	Moved     bool           `json:"moved"`
	Position  Point          `json:"position"`
	HasKey    bool           `json:"has_key"`
	Revealed  []RevealedTile `json:"revealed"`
	Event     string         `json:"event"`
	GameOver  bool           `json:"game_over"`
}

// NewPlayerState creates a fresh player state for the start of a race.
func NewPlayerState(m *Maze) *PlayerState {
	revealed := make([][]int, m.Height)
	for y := range revealed {
		revealed[y] = make([]int, m.Width)
		for x := range revealed[y] {
			revealed[y][x] = TileHidden
		}
	}

	ps := &PlayerState{
		Position: m.StartPos(),
		Revealed: revealed,
	}

	// Reveal start and neighbors
	ps.revealAround(m.StartPos(), m)

	return ps
}

// ProcessMove attempts to move the player in the given direction on the given maze.
func (ps *PlayerState) ProcessMove(m *Maze, direction string) MoveResult {
	dx, dy := dirToDelta(direction)
	if dx == 0 && dy == 0 {
		return MoveResult{
			Moved:    false,
			Position: ps.Position,
			HasKey:   ps.HasKey,
			Event:    EventNone,
		}
	}

	nx, ny := ps.Position.X+dx, ps.Position.Y+dy

	// Out of bounds
	if nx < 0 || nx >= m.Width || ny < 0 || ny >= m.Height {
		return MoveResult{
			Moved:    false,
			Position: ps.Position,
			HasKey:   ps.HasKey,
			Event:    EventNone,
		}
	}

	tile := m.Get(nx, ny)
	target := Point{X: nx, Y: ny}

	var newRevealed []RevealedTile

	switch tile {
	case TileWall:
		// Reveal the wall, don't move
		newRevealed = ps.revealSingle(target, m)
		ps.MoveCount++
		return MoveResult{
			Moved:    false,
			Position: ps.Position,
			HasKey:   ps.HasKey,
			Revealed: newRevealed,
			Event:    EventHitWall,
		}

	case TileDoor:
		if !ps.HasKey {
			// Reveal the door, don't move
			newRevealed = ps.revealSingle(target, m)
			ps.MoveCount++
			return MoveResult{
				Moved:    false,
				Position: ps.Position,
				HasKey:   ps.HasKey,
				Revealed: newRevealed,
				Event:    EventDoorLocked,
			}
		}
		// Has key — open door and move through
		ps.DoorOpen = true
		ps.Position = target
		ps.MoveCount++
		newRevealed = ps.revealAround(target, m)
		// Mark door as open in revealed
		ps.Revealed[target.Y][target.X] = TileOpenDoor
		// Update the revealed list to show open door
		for i, r := range newRevealed {
			if r.X == target.X && r.Y == target.Y {
				newRevealed[i].Tile = TileOpenDoor
			}
		}
		return MoveResult{
			Moved:    true,
			Position: ps.Position,
			HasKey:   ps.HasKey,
			Revealed: newRevealed,
			Event:    EventDoorOpened,
		}

	case TileKey:
		ps.HasKey = true
		ps.Position = target
		ps.MoveCount++
		newRevealed = ps.revealAround(target, m)
		return MoveResult{
			Moved:    true,
			Position: ps.Position,
			HasKey:   ps.HasKey,
			Revealed: newRevealed,
			Event:    EventFoundKey,
		}

	case TileTreasure:
		ps.Position = target
		ps.MoveCount++
		newRevealed = ps.revealAround(target, m)
		return MoveResult{
			Moved:    true,
			Position: ps.Position,
			HasKey:   ps.HasKey,
			Revealed: newRevealed,
			Event:    EventFoundTreasure,
			GameOver: true,
		}

	default:
		// Floor — just move
		ps.Position = target
		ps.MoveCount++
		newRevealed = ps.revealAround(target, m)
		return MoveResult{
			Moved:    true,
			Position: ps.Position,
			HasKey:   ps.HasKey,
			Revealed: newRevealed,
			Event:    EventNone,
		}
	}
}

// revealAround reveals the tile at pos and its 4 neighbors.
// Returns newly revealed tiles.
func (ps *PlayerState) revealAround(pos Point, m *Maze) []RevealedTile {
	var newly []RevealedTile

	points := []Point{
		pos,
		{pos.X, pos.Y + 1},
		{pos.X, pos.Y - 1},
		{pos.X - 1, pos.Y},
		{pos.X + 1, pos.Y},
	}

	for _, p := range points {
		tiles := ps.revealSingle(p, m)
		newly = append(newly, tiles...)
	}

	return newly
}

// revealSingle reveals a single tile if not already revealed.
func (ps *PlayerState) revealSingle(p Point, m *Maze) []RevealedTile {
	if m == nil {
		return nil
	}
	if p.X < 0 || p.X >= m.Width || p.Y < 0 || p.Y >= m.Height {
		return nil
	}
	if ps.Revealed[p.Y][p.X] != TileHidden {
		return nil // already revealed
	}

	tile := m.Get(p.X, p.Y)
	// If door is opened, show as open door
	if tile == TileDoor && ps.DoorOpen {
		tile = TileOpenDoor
	}
	ps.Revealed[p.Y][p.X] = tile
	return []RevealedTile{{X: p.X, Y: p.Y, Tile: tile}}
}

// GetAllRevealed returns all currently revealed tiles.
func (ps *PlayerState) GetAllRevealed() []RevealedTile {
	var tiles []RevealedTile
	for y := range ps.Revealed {
		for x := range ps.Revealed[y] {
			if ps.Revealed[y][x] != TileHidden {
				tiles = append(tiles, RevealedTile{X: x, Y: y, Tile: ps.Revealed[y][x]})
			}
		}
	}
	return tiles
}

func dirToDelta(dir string) (int, int) {
	switch dir {
	case DirUp:
		return 0, 1
	case DirDown:
		return 0, -1
	case DirLeft:
		return -1, 0
	case DirRight:
		return 1, 0
	default:
		return 0, 0
	}
}
