package session

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/1F47E/maze-server/internal/maze"
)

// Phase represents the current game phase.
type Phase string

const (
	PhaseLobby    Phase = "lobby"
	PhaseBuild    Phase = "build"
	PhaseCountdown Phase = "countdown"
	PhaseRace     Phase = "race"
	PhaseGameOver Phase = "game_over"
)

// Player represents a connected player.
type Player struct {
	DeviceID    string
	DisplayName string
	AppVersion  string
	Conn        PlayerConn
	Role        string // "host" or "guest"
}

// PlayerConn is the interface for sending messages to a player.
type PlayerConn interface {
	Send(msg []byte) error
	Close()
}

// Session holds the full state of a maze race game.
type Session struct {
	mu sync.Mutex

	ID        string
	JoinCode  string
	AutoMatch bool // true = open for auto-matchmaking
	Phase     Phase
	Created   time.Time

	Host  *Player
	Guest *Player

	HostMaze    *maze.Maze
	GuestMaze   *maze.Maze
	HostDone    bool
	GuestDone   bool

	// Race state: host explores guest's maze, guest explores host's maze
	HostRaceState  *maze.PlayerState
	GuestRaceState *maze.PlayerState

	Winner    string // device_id of winner
	RaceStart time.Time
}

// Registry manages active sessions.
type Registry struct {
	mu       sync.Mutex
	sessions map[string]*Session
	codes    map[string]string // joinCode -> sessionID
}

// NewRegistry creates a new session registry.
func NewRegistry() *Registry {
	return &Registry{
		sessions: make(map[string]*Session),
		codes:    make(map[string]string),
	}
}

// CreateSession creates a new session with the given host.
func (r *Registry) CreateSession(host *Player) *Session {
	r.mu.Lock()
	defer r.mu.Unlock()

	id := generateID()
	code := r.generateUniqueCode()

	s := &Session{
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
// or creates a new auto-match session if none available.
// Returns (session, isNewHost).
func (r *Registry) FindOrCreateAutoMatch(player *Player) (*Session, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Look for a waiting auto-match session
	for _, s := range r.sessions {
		s.mu.Lock()
		if s.AutoMatch && s.Phase == PhaseLobby && s.Guest == nil && s.Host.DeviceID != player.DeviceID {
			s.Guest = player
			s.mu.Unlock()
			return s, false // joined existing
		}
		s.mu.Unlock()
	}

	// No open session — create a new one
	id := generateID()
	code := r.generateUniqueCode()

	s := &Session{
		ID:        id,
		JoinCode:  code,
		AutoMatch: true,
		Phase:     PhaseLobby,
		Created:   time.Now(),
		Host:      player,
	}

	r.sessions[id] = s
	r.codes[code] = id
	return s, true // created as host
}

// JoinSession joins an existing session by join code.
func (r *Registry) JoinSession(code string, guest *Player) (*Session, error) {
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
func (r *Registry) GetSession(id string) *Session {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.sessions[id]
}

// GetSessionByCode returns a session by join code.
func (r *Registry) GetSessionByCode(code string) *Session {
	r.mu.Lock()
	defer r.mu.Unlock()
	sid, ok := r.codes[code]
	if !ok {
		return nil
	}
	return r.sessions[sid]
}

// FindSessionsByPlayer returns all sessions involving the given device ID.
func (r *Registry) FindSessionsByPlayer(deviceID string) []*Session {
	r.mu.Lock()
	defer r.mu.Unlock()

	var result []*Session
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

// RemoveSession removes a session.
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

// SubmitMaze submits and validates a maze for a player.
func (s *Session) SubmitMaze(deviceID string, m *maze.Maze) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := m.Validate(); err != nil {
		return err
	}

	if s.Host != nil && s.Host.DeviceID == deviceID {
		s.HostMaze = m
		return nil
	}
	if s.Guest != nil && s.Guest.DeviceID == deviceID {
		s.GuestMaze = m
		return nil
	}

	return fmt.Errorf("player not in session")
}

// SetDone marks a player as done building.
func (s *Session) SetDone(deviceID string, done bool) (bothDone bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Host != nil && s.Host.DeviceID == deviceID {
		s.HostDone = done
	} else if s.Guest != nil && s.Guest.DeviceID == deviceID {
		s.GuestDone = done
	}

	if s.HostDone && s.GuestDone && s.HostMaze != nil && s.GuestMaze != nil {
		return true
	}
	return false
}

// StartRace initializes race state.
func (s *Session) StartRace() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.Phase = PhaseRace
	s.RaceStart = time.Now()

	// Host explores guest's maze, guest explores host's maze
	s.HostRaceState = maze.NewPlayerState(s.GuestMaze)
	s.GuestRaceState = maze.NewPlayerState(s.HostMaze)
}

// ProcessMove processes a move for a player. Returns the move result and whether the game is over.
func (s *Session) ProcessMove(deviceID, direction string) (*maze.MoveResult, string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Phase != PhaseRace {
		return nil, "", fmt.Errorf("not in race phase")
	}

	var result maze.MoveResult
	var opponentEvent string

	if s.Host != nil && s.Host.DeviceID == deviceID {
		// Host explores guest's maze
		result = s.HostRaceState.ProcessMove(s.GuestMaze, direction)
		if result.Event != "" && result.Event != maze.EventHitWall {
			opponentEvent = result.Event
		}
		if result.GameOver {
			s.Winner = deviceID
			s.Phase = PhaseGameOver
		}
	} else if s.Guest != nil && s.Guest.DeviceID == deviceID {
		// Guest explores host's maze
		result = s.GuestRaceState.ProcessMove(s.HostMaze, direction)
		if result.Event != "" && result.Event != maze.EventHitWall {
			opponentEvent = result.Event
		}
		if result.GameOver {
			s.Winner = deviceID
			s.Phase = PhaseGameOver
		}
	} else {
		return nil, "", fmt.Errorf("player not in session")
	}

	return &result, opponentEvent, nil
}

// GetOpponent returns the opponent player for a given device ID.
func (s *Session) GetOpponent(deviceID string) *Player {
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

// GetPlayer returns the player for a given device ID.
func (s *Session) GetPlayer(deviceID string) *Player {
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

// IsWaitingLobby returns true if the session is in lobby with no guest.
func (s *Session) IsWaitingLobby() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.Phase == PhaseLobby && s.Guest == nil
}

// TransitionToBuild atomically transitions the session to build phase.
func (s *Session) TransitionToBuild() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.Phase = PhaseBuild
}

// VersionsMatch checks if both players have the same app version.
func (s *Session) VersionsMatch() bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Host == nil || s.Guest == nil {
		return true // not enough players to compare
	}
	return s.Host.AppVersion == s.Guest.AppVersion
}

// ResetForRematch resets the session for a new game.
func (s *Session) ResetForRematch() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.Phase = PhaseBuild
	s.HostMaze = nil
	s.GuestMaze = nil
	s.HostDone = false
	s.GuestDone = false
	s.HostRaceState = nil
	s.GuestRaceState = nil
	s.Winner = ""
	s.RaceStart = time.Time{}
}

// GetRaceStateForPlayer returns the race state for the given player
func (s *Session) GetRaceStateForPlayer(deviceID string) *maze.PlayerState {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Host != nil && s.Host.DeviceID == deviceID {
		return s.HostRaceState
	}
	if s.Guest != nil && s.Guest.DeviceID == deviceID {
		return s.GuestRaceState
	}
	return nil
}

// GameOverSnapshot captures all data needed for the game_over payload and match record.
// Must be called while session fields are still populated (before rematch reset).
type GameOverSnapshot struct {
	WinnerName     string
	WinnerDeviceID string
	WinnerMoves    int
	LoserName      string
	LoserDeviceID  string
	LoserMoves     int
	HostName       string
	GuestName      string
	HostDeviceID   string
	GuestDeviceID  string
	HostMaze       [][]int
	GuestMaze      [][]int
	RaceDurationSec int
}

// BuildGameOverSnapshot atomically reads session state under lock.
func (s *Session) BuildGameOverSnapshot(winnerDeviceID string) *GameOverSnapshot {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.Host == nil || s.Guest == nil {
		return nil
	}

	snap := &GameOverSnapshot{
		HostName:      s.Host.DisplayName,
		GuestName:     s.Guest.DisplayName,
		HostDeviceID:  s.Host.DeviceID,
		GuestDeviceID: s.Guest.DeviceID,
	}

	if s.Host.DeviceID == winnerDeviceID {
		snap.WinnerName = s.Host.DisplayName
		snap.WinnerDeviceID = s.Host.DeviceID
		snap.LoserName = s.Guest.DisplayName
		snap.LoserDeviceID = s.Guest.DeviceID
		if s.HostRaceState != nil {
			snap.WinnerMoves = s.HostRaceState.MoveCount
		}
		if s.GuestRaceState != nil {
			snap.LoserMoves = s.GuestRaceState.MoveCount
		}
	} else {
		snap.WinnerName = s.Guest.DisplayName
		snap.WinnerDeviceID = s.Guest.DeviceID
		snap.LoserName = s.Host.DisplayName
		snap.LoserDeviceID = s.Host.DeviceID
		if s.GuestRaceState != nil {
			snap.WinnerMoves = s.GuestRaceState.MoveCount
		}
		if s.HostRaceState != nil {
			snap.LoserMoves = s.HostRaceState.MoveCount
		}
	}

	if s.HostMaze != nil {
		snap.HostMaze = s.HostMaze.Cells
	}
	if s.GuestMaze != nil {
		snap.GuestMaze = s.GuestMaze.Cells
	}

	if !s.RaceStart.IsZero() {
		snap.RaceDurationSec = int(time.Since(s.RaceStart).Seconds())
	}

	return snap
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
	return fmt.Sprintf("sess_%x", b)
}

// Cleanup removes stale sessions (older than 1 hour with no activity).
func (r *Registry) Cleanup() {
	r.mu.Lock()
	defer r.mu.Unlock()

	cutoff := time.Now().Add(-1 * time.Hour)
	for id, s := range r.sessions {
		if s.Created.Before(cutoff) && s.Phase != PhaseRace {
			delete(r.codes, s.JoinCode)
			delete(r.sessions, id)
		}
	}
}

// StartCleanup starts a background goroutine that cleans up stale sessions.
func (r *Registry) StartCleanup() {
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			r.Cleanup()
		}
	}()
}
