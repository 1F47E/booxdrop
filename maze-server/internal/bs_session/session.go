package bs_session

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/1F47E/maze-server/internal/battleships"
	"github.com/1F47E/maze-server/internal/session"
)

// Phase represents the current game phase in Battleships.
type Phase string

const (
	PhaseLobby    Phase = "lobby"
	PhasePlace    Phase = "place"    // players are placing ships
	PhaseReady    Phase = "ready"    // both players placed, waiting for ready signal
	PhaseBattle   Phase = "battle"   // active game
	PhaseGameOver Phase = "game_over"
)

// ShotResult holds the outcome of a single fire_shot action.
type ShotResult struct {
	X         int                    `json:"x"`
	Y         int                    `json:"y"`
	Result    string                 `json:"result"`    // "hit", "miss", "sunk"
	ShipType  string                 `json:"ship_type"` // non-empty when sunk
	SunkCells []battleships.Point    `json:"sunk_cells,omitempty"`
	GameOver  bool                   `json:"game_over"`
	NextTurn  string                 `json:"next_turn"` // device_id of who shoots next
}

// BattleSession holds the full state of a Battleships game.
type BattleSession struct {
	mu sync.Mutex

	ID        string
	JoinCode  string
	AutoMatch bool
	Phase     Phase
	Created   time.Time

	Host  *session.Player
	Guest *session.Player

	HostFleet  []battleships.ShipPlacement
	GuestFleet []battleships.ShipPlacement

	HostReady  bool
	GuestReady bool

	HostBattleState  *battleships.BattleState
	GuestBattleState *battleships.BattleState

	ActiveTurn string // device_id of who fires next
	Winner     string // device_id of winner
}

// Registry manages active BattleSessions.
type Registry struct {
	mu       sync.Mutex
	sessions map[string]*BattleSession
	codes    map[string]string // joinCode -> sessionID
}

// NewRegistry creates a new BattleSession registry.
func NewRegistry() *Registry {
	return &Registry{
		sessions: make(map[string]*BattleSession),
		codes:    make(map[string]string),
	}
}

// CreateSession creates a new BattleSession with the given host.
func (r *Registry) CreateSession(host *session.Player) *BattleSession {
	r.mu.Lock()
	defer r.mu.Unlock()

	id := generateID()
	code := r.generateUniqueCode()

	s := &BattleSession{
		ID:       id,
		JoinCode: code,
		Phase:    PhaseLobby,
		Created:  time.Now(),
		Host:     host,
	}

	r.sessions[id] = s
	r.codes[code] = id
	return s
}

// FindOrCreateAutoMatch finds a waiting auto-match session and joins it,
// or creates a new auto-match session if none is available.
// Returns (session, isNewHost).
func (r *Registry) FindOrCreateAutoMatch(player *session.Player) (*BattleSession, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()

	for _, s := range r.sessions {
		s.mu.Lock()
		if s.AutoMatch && s.Phase == PhaseLobby && s.Guest == nil && s.Host.DeviceID != player.DeviceID {
			s.Guest = player
			s.mu.Unlock()
			return s, false
		}
		s.mu.Unlock()
	}

	id := generateID()
	code := r.generateUniqueCode()

	s := &BattleSession{
		ID:        id,
		JoinCode:  code,
		AutoMatch: true,
		Phase:     PhaseLobby,
		Created:   time.Now(),
		Host:      player,
	}

	r.sessions[id] = s
	r.codes[code] = id
	return s, true
}

// JoinSession joins an existing session by join code.
func (r *Registry) JoinSession(code string, guest *session.Player) (*BattleSession, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	sid, ok := r.codes[code]
	if !ok {
		return nil, fmt.Errorf("invalid join code")
	}

	s, ok := r.sessions[sid]
	if !ok {
		return nil, fmt.Errorf("session not found")
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Guest != nil {
		return nil, fmt.Errorf("session is full")
	}

	s.Guest = guest
	return s, nil
}

// GetSession returns a session by ID.
func (r *Registry) GetSession(id string) *BattleSession {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.sessions[id]
}

// FindSessionsByPlayer returns all sessions involving the given device ID.
func (r *Registry) FindSessionsByPlayer(deviceID string) []*BattleSession {
	r.mu.Lock()
	defer r.mu.Unlock()

	var result []*BattleSession
	for _, s := range r.sessions {
		s.mu.Lock()
		match := (s.Host != nil && s.Host.DeviceID == deviceID) ||
			(s.Guest != nil && s.Guest.DeviceID == deviceID)
		s.mu.Unlock()
		if match {
			result = append(result, s)
		}
	}
	return result
}

// RemoveSession removes a session by ID.
func (r *Registry) RemoveSession(id string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	s, ok := r.sessions[id]
	if !ok {
		return
	}
	delete(r.codes, s.JoinCode)
	delete(r.sessions, id)
}

// IsWaitingLobby returns true if the session is in lobby with no guest.
func (s *BattleSession) IsWaitingLobby() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.Phase == PhaseLobby && s.Guest == nil
}

// GetOpponent returns the opponent of the given device ID.
func (s *BattleSession) GetOpponent(deviceID string) *session.Player {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Host != nil && s.Host.DeviceID == deviceID {
		return s.Guest
	}
	if s.Guest != nil && s.Guest.DeviceID == deviceID {
		return s.Host
	}
	return nil
}

// GetPlayer returns the player with the given device ID.
func (s *BattleSession) GetPlayer(deviceID string) *session.Player {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Host != nil && s.Host.DeviceID == deviceID {
		return s.Host
	}
	if s.Guest != nil && s.Guest.DeviceID == deviceID {
		return s.Guest
	}
	return nil
}

// SubmitFleet validates and stores a player's fleet.
// Transitions the session to PhasePlace once the first fleet is received,
// and to PhaseReady once both fleets are in.
func (s *BattleSession) SubmitFleet(deviceID string, ships []battleships.ShipPlacement) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Phase == PhaseLobby {
		return fmt.Errorf("cannot submit fleet before opponent joins")
	}

	if err := battleships.ValidateFleet(ships, battleships.Width, battleships.Height); err != nil {
		return err
	}

	isHost := s.Host != nil && s.Host.DeviceID == deviceID
	isGuest := s.Guest != nil && s.Guest.DeviceID == deviceID

	if !isHost && !isGuest {
		return fmt.Errorf("player not in session")
	}

	if isHost {
		s.HostFleet = ships
	} else {
		s.GuestFleet = ships
	}

	if s.Phase == PhaseLobby {
		s.Phase = PhasePlace
	}

	if s.HostFleet != nil && s.GuestFleet != nil && s.Phase == PhasePlace {
		s.Phase = PhaseReady
	}

	return nil
}

// SetReady marks a player ready. Returns true when both players are ready.
func (s *BattleSession) SetReady(deviceID string, ready bool) (bothReady bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Host != nil && s.Host.DeviceID == deviceID {
		s.HostReady = ready
	} else if s.Guest != nil && s.Guest.DeviceID == deviceID {
		s.GuestReady = ready
	}

	return s.HostReady && s.GuestReady
}

// StartBattle creates BattleStates and transitions to PhaseBattle.
// Host fires first.
func (s *BattleSession) StartBattle() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.HostFleet == nil || s.GuestFleet == nil {
		return fmt.Errorf("both fleets must be submitted before starting battle")
	}

	s.HostBattleState = battleships.NewBattleState(s.HostFleet)
	s.GuestBattleState = battleships.NewBattleState(s.GuestFleet)
	s.Phase = PhaseBattle
	s.ActiveTurn = s.Host.DeviceID

	return nil
}

// ProcessShot validates the turn, fires on the opponent's grid, and flips the turn.
func (s *BattleSession) ProcessShot(deviceID string, x, y int) (*ShotResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Phase != PhaseBattle {
		return nil, fmt.Errorf("not in battle phase")
	}
	if s.ActiveTurn != deviceID {
		return nil, fmt.Errorf("not your turn")
	}

	// Determine which grid to fire on (opponent's MyGrid)
	// and which BattleState to update for the shooter's TargetGrid.
	var shooterState *battleships.BattleState
	var targetState *battleships.BattleState

	if s.Host != nil && s.Host.DeviceID == deviceID {
		shooterState = s.HostBattleState
		targetState = s.GuestBattleState
	} else if s.Guest != nil && s.Guest.DeviceID == deviceID {
		shooterState = s.GuestBattleState
		targetState = s.HostBattleState
	} else {
		return nil, fmt.Errorf("player not in session")
	}

	// Fire on the opponent's MyGrid
	result, shipType, sunkCells, gameOver := targetState.MyGrid.FireShot(x, y)

	// Mirror the shot result onto the shooter's TargetGrid for UI display
	if result == "miss" {
		shooterState.TargetGrid.Cells[y][x] = battleships.CellMiss
	} else if result == "hit" {
		shooterState.TargetGrid.Cells[y][x] = battleships.CellHit
	} else { // sunk
		for _, pt := range sunkCells {
			shooterState.TargetGrid.Cells[pt.Y][pt.X] = battleships.CellSunk
		}
	}

	// Update shooter stats
	shooterState.ShotsFired++
	if result == "hit" || result == "sunk" {
		shooterState.Hits++
	}
	if result == "sunk" {
		shooterState.ShipsSunk++
		targetState.ShipsRemaining--
	}

	if gameOver {
		s.Phase = PhaseGameOver
		s.Winner = deviceID
	}

	// Flip turn (only when game is not over)
	nextTurn := ""
	if !gameOver {
		if s.Host != nil && s.Guest != nil {
			if s.ActiveTurn == s.Host.DeviceID {
				s.ActiveTurn = s.Guest.DeviceID
			} else {
				s.ActiveTurn = s.Host.DeviceID
			}
		}
		nextTurn = s.ActiveTurn
	}

	return &ShotResult{
		X:         x,
		Y:         y,
		Result:    result,
		ShipType:  shipType,
		SunkCells: sunkCells,
		GameOver:  gameOver,
		NextTurn:  nextTurn,
	}, nil
}

// TransitionToPlace atomically transitions the session to the place phase.
func (s *BattleSession) TransitionToPlace() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.Phase = PhasePlace
}

// ResetForRematch resets the session to PhasePlace so players can replace ships.
func (s *BattleSession) ResetForRematch() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.Phase = PhasePlace
	s.HostFleet = nil
	s.GuestFleet = nil
	s.HostReady = false
	s.GuestReady = false
	s.HostBattleState = nil
	s.GuestBattleState = nil
	s.ActiveTurn = ""
	s.Winner = ""
}

// VersionsMatch returns true when both players share the same AppVersion.
func (s *BattleSession) VersionsMatch() bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Host == nil || s.Guest == nil {
		return true
	}
	return s.Host.AppVersion == s.Guest.AppVersion
}

// Cleanup removes stale sessions older than 1 hour that are not in active battle.
func (r *Registry) Cleanup() {
	r.mu.Lock()
	defer r.mu.Unlock()

	cutoff := time.Now().Add(-1 * time.Hour)
	for id, s := range r.sessions {
		if s.Created.Before(cutoff) && s.Phase != PhaseBattle {
			delete(r.codes, s.JoinCode)
			delete(r.sessions, id)
		}
	}
}

// StartCleanup starts a background goroutine that periodically cleans up stale sessions.
func (r *Registry) StartCleanup() {
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			r.Cleanup()
		}
	}()
}

func (r *Registry) generateUniqueCode() string {
	for {
		n, _ := rand.Int(rand.Reader, big.NewInt(1000))
		code := fmt.Sprintf("%03d", n.Int64())
		if _, exists := r.codes[code]; !exists {
			return code
		}
	}
}

func generateID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return fmt.Sprintf("bsess_%x", b)
}
