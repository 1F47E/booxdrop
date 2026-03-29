package maze

import "fmt"

// Tile codes (base)
const (
	TileFloor    = 0
	TileWall     = 1
	TileKey      = 2
	TileDoor     = 3
	TileTreasure = 4
	TileStart    = 6
)

// Discovered tile codes (runtime)
const (
	TileHidden  = -1
	TileOpenDoor = 5
)

// Direction constants
const (
	DirUp    = "up"
	DirDown  = "down"
	DirLeft  = "left"
	DirRight = "right"
)

// Move events
const (
	EventNone        = ""
	EventFoundKey    = "found_key"
	EventDoorLocked  = "door_locked"
	EventDoorOpened  = "door_opened"
	EventFoundTreasure = "found_treasure"
	EventHitWall     = "hit_wall"
)

// Point represents a canonical grid position.
// x: 0..width-1 left to right, y: 0..height-1 bottom to top.
type Point struct {
	X int `json:"x"`
	Y int `json:"y"`
}

// Maze represents a player-built maze.
type Maze struct {
	Width  int   `json:"width"`
	Height int   `json:"height"`
	Cells  [][]int `json:"cells"`
}

// NewMaze creates an empty maze filled with floor tiles.
func NewMaze(w, h int) *Maze {
	cells := make([][]int, h)
	for y := range cells {
		cells[y] = make([]int, w)
	}
	return &Maze{Width: w, Height: h, Cells: cells}
}

// Get returns the tile at canonical (x, y).
func (m *Maze) Get(x, y int) int {
	if x < 0 || x >= m.Width || y < 0 || y >= m.Height {
		return -1
	}
	return m.Cells[y][x]
}

// Set sets the tile at canonical (x, y).
func (m *Maze) Set(x, y, tile int) {
	if x >= 0 && x < m.Width && y >= 0 && y < m.Height {
		m.Cells[y][x] = tile
	}
}

// StartPos returns the start position by finding the start tile, or (0,0) as fallback.
func (m *Maze) StartPos() Point {
	for y := 0; y < m.Height; y++ {
		for x := 0; x < m.Width; x++ {
			if m.Get(x, y) == TileStart {
				return Point{X: x, Y: y}
			}
		}
	}
	return Point{X: 0, Y: 0}
}

// Validate checks that the maze is valid per MVP rules.
// Returns nil if valid, an error describing the problem otherwise.
func (m *Maze) Validate() error {
	if m.Width != 7 || m.Height != 7 {
		return fmt.Errorf("maze must be 7x7, got %dx%d", m.Width, m.Height)
	}

	// Count special tiles
	var keyPos, doorPos, treasurePos, startPos *Point
	wallCount := 0
	for y := 0; y < m.Height; y++ {
		for x := 0; x < m.Width; x++ {
			switch m.Get(x, y) {
			case TileStart:
				if startPos != nil {
					return fmt.Errorf("multiple start tiles found")
				}
				p := Point{X: x, Y: y}
				startPos = &p
			case TileKey:
				if keyPos != nil {
					return fmt.Errorf("multiple keys found")
				}
				p := Point{X: x, Y: y}
				keyPos = &p
			case TileDoor:
				if doorPos != nil {
					return fmt.Errorf("multiple doors found")
				}
				p := Point{X: x, Y: y}
				doorPos = &p
			case TileTreasure:
				if treasurePos != nil {
					return fmt.Errorf("multiple treasures found")
				}
				p := Point{X: x, Y: y}
				treasurePos = &p
			case TileWall:
				wallCount++
			}
		}
	}

	if startPos == nil {
		return fmt.Errorf("maze must have exactly one start tile")
	}
	if keyPos == nil {
		return fmt.Errorf("maze must have exactly one key")
	}
	if doorPos == nil {
		return fmt.Errorf("maze must have exactly one door")
	}
	if treasurePos == nil {
		return fmt.Errorf("maze must have exactly one treasure")
	}
	if wallCount > 20 {
		return fmt.Errorf("too many walls: %d (max 20)", wallCount)
	}

	// Reachability: start -> key (no door crossing)
	if !m.reachable(*startPos, *keyPos, false) {
		return fmt.Errorf("key is not reachable from start without crossing door")
	}

	// Reachability: key -> door (no door blocking, since we just need to reach the door cell)
	if !m.reachable(*keyPos, *doorPos, false) {
		return fmt.Errorf("door is not reachable from key")
	}

	// Reachability: door -> treasure (door is now open)
	if !m.reachable(*doorPos, *treasurePos, true) {
		return fmt.Errorf("treasure is not reachable from door")
	}

	// Minimum path length check
	pathLen := m.shortestPath(*startPos, *keyPos, false) +
		m.shortestPath(*keyPos, *doorPos, false) +
		m.shortestPath(*doorPos, *treasurePos, true)
	if pathLen < 8 {
		return fmt.Errorf("maze is too easy: shortest solution is %d moves (min 8)", pathLen)
	}

	return nil
}

// reachable checks if dst is reachable from src using BFS.
// If doorOpen is false, door tiles block passage.
func (m *Maze) reachable(src, dst Point, doorOpen bool) bool {
	return m.shortestPath(src, dst, doorOpen) >= 0
}

// shortestPath returns the shortest path length from src to dst, or -1 if unreachable.
func (m *Maze) shortestPath(src, dst Point, doorOpen bool) int {
	if src == dst {
		return 0
	}

	visited := make([][]bool, m.Height)
	for i := range visited {
		visited[i] = make([]bool, m.Width)
	}

	type state struct {
		pos  Point
		dist int
	}

	queue := []state{{pos: src, dist: 0}}
	visited[src.Y][src.X] = true

	dirs := []Point{{0, 1}, {0, -1}, {-1, 0}, {1, 0}}

	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]

		for _, d := range dirs {
			nx, ny := cur.pos.X+d.X, cur.pos.Y+d.Y
			if nx < 0 || nx >= m.Width || ny < 0 || ny >= m.Height {
				continue
			}
			if visited[ny][nx] {
				continue
			}

			next := Point{X: nx, Y: ny}

			// Check destination before applying tile filter —
			// we can always reach the destination tile itself.
			if next == dst {
				return cur.dist + 1
			}

			tile := m.Get(nx, ny)
			if tile == TileWall {
				continue
			}
			if tile == TileDoor && !doorOpen {
				continue
			}

			visited[ny][nx] = true
			queue = append(queue, state{pos: next, dist: cur.dist + 1})
		}
	}

	return -1
}
