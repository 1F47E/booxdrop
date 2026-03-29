package ws

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/1F47E/maze-server/internal/match"
	"github.com/1F47E/maze-server/internal/maze"
	"github.com/1F47E/maze-server/internal/session"
	"github.com/gofiber/websocket/v2"
	"github.com/rs/zerolog"
)

// Message is the envelope for all WebSocket messages.
type Message struct {
	Type      string          `json:"type"`
	SessionID string          `json:"session_id,omitempty"`
	Payload   json.RawMessage `json:"payload,omitempty"`
}

// Handler manages WebSocket connections and routes messages.
type Handler struct {
	registry   *session.Registry
	matchStore *match.Store
	log        zerolog.Logger
	clients    sync.Map // deviceID -> *Client
}

// Client wraps a WebSocket connection.
type Client struct {
	conn     *websocket.Conn
	deviceID string
	mu       sync.Mutex
}

func (c *Client) Send(msg []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.conn.WriteMessage(websocket.TextMessage, msg)
}

func (c *Client) Close() {
	c.conn.Close()
}

// DeviceID returns the client's device ID.
func (c *Client) DeviceID() string {
	return c.deviceID
}

// SetDeviceID sets the client's device ID.
func (c *Client) SetDeviceID(id string) {
	c.deviceID = id
}

// NewClient creates a Client wrapping the given WebSocket connection.
func NewClient(conn *websocket.Conn) *Client {
	return &Client{conn: conn}
}

// NewHandler creates a new WebSocket handler.
func NewHandler(registry *session.Registry, matchStore *match.Store, log zerolog.Logger) *Handler {
	return &Handler{
		registry:   registry,
		matchStore: matchStore,
		log:        log,
	}
}

// HandleConnection handles a single WebSocket connection.
func (h *Handler) HandleConnection(c *websocket.Conn) {
	client := &Client{conn: c}
	defer func() {
		if client.deviceID != "" {
			h.clients.Delete(client.deviceID)
			h.cleanupDisconnectedPlayer(client.deviceID)
		}
		c.Close()
	}()

	// Set read deadline for initial hello
	c.SetReadDeadline(time.Now().Add(30 * time.Second))

	for {
		_, raw, err := c.ReadMessage()
		if err != nil {
			h.log.Debug().Err(err).Str("device", client.deviceID).Msg("read error")
			return
		}

		// Reset read deadline after successful read
		c.SetReadDeadline(time.Now().Add(60 * time.Second))

		var msg Message
		if err := json.Unmarshal(raw, &msg); err != nil {
			h.sendError(client, "", "invalid message format")
			continue
		}

		h.routeMessage(client, msg)
	}
}

func (h *Handler) routeMessage(client *Client, msg Message) {
	switch msg.Type {
	case "hello":
		h.handleHello(client, msg)
	case "auto_match":
		h.handleAutoMatch(client, msg)
	case "create_session":
		h.handleCreateSession(client, msg)
	case "join_session":
		h.handleJoinSession(client, msg)
	case "submit_maze":
		h.handleSubmitMaze(client, msg)
	case "set_done":
		h.handleSetDone(client, msg)
	case "move_attempt":
		h.handleMoveAttempt(client, msg)
	case "request_rematch":
		h.handleRematch(client, msg)
	case "leave_session":
		h.handleLeave(client, msg)
	case "ping":
		h.sendJSON(client, Message{Type: "pong"})
	default:
		h.sendError(client, msg.SessionID, "unknown message type: "+msg.Type)
	}
}

// --- Hello ---

type helloPayload struct {
	DeviceID    string `json:"device_id"`
	DisplayName string `json:"display_name"`
	Platform    string `json:"platform"`
	AppVersion  string `json:"app_version"`
}

func (h *Handler) handleHello(client *Client, msg Message) {
	var p helloPayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, "", "invalid hello payload")
		return
	}

	if p.DeviceID == "" {
		h.sendError(client, "", "device_id required")
		return
	}

	client.deviceID = p.DeviceID
	h.clients.Store(p.DeviceID, client)

	h.log.Info().Str("device", p.DeviceID).Str("name", p.DisplayName).Msg("player connected")
}

// --- Auto Match ---

func (h *Handler) handleAutoMatch(client *Client, msg Message) {
	if client.deviceID == "" {
		h.sendError(client, "", "must send hello first")
		return
	}

	var p helloPayload
	_ = json.Unmarshal(msg.Payload, &p)

	player := &session.Player{
		DeviceID:    client.deviceID,
		DisplayName: p.DisplayName,
		AppVersion:  p.AppVersion,
		Conn:        client,
		Role:        "host", // default; overwritten to "guest" if matched
	}

	s, isHost := h.registry.FindOrCreateAutoMatch(player)

	if isHost {
		h.log.Info().Str("session", s.ID).Msg("auto-match: created, waiting")

		h.sendJSON(client, Message{
			Type:      "session_created",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"join_code": s.JoinCode, "auto_match": true}),
		})
	} else {
		player.Role = "guest"
		h.log.Info().Str("session", s.ID).Str("guest", client.deviceID).Msg("auto-match: joined")

		// Send lobby_state to both
		lobbyPayload := map[string]any{
			"host_name":        s.Host.DisplayName,
			"guest_name":       player.DisplayName,
			"host_app_version": s.Host.AppVersion,
			"guest_app_version": player.AppVersion,
			"versions_match":   s.VersionsMatch(),
		}
		lobbyMsg := Message{
			Type:      "lobby_state",
			SessionID: s.ID,
			Payload:   mustJSON(lobbyPayload),
		}
		h.sendToPlayer(s.Host, lobbyMsg)
		h.sendToPlayer(player, lobbyMsg)

		// Transition to build
		s.TransitionToBuild()

		// Notify peer_joined to both
		h.sendJSON(client, Message{
			Type:      "peer_joined",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"peer_name": s.Host.DisplayName}),
		})
		h.sendToPlayer(s.Host, Message{
			Type:      "peer_joined",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"peer_name": player.DisplayName}),
		})
	}
}

// --- Create Session ---

func (h *Handler) handleCreateSession(client *Client, msg Message) {
	if client.deviceID == "" {
		h.sendError(client, "", "must send hello first")
		return
	}

	var p helloPayload
	// Re-parse from the stored hello data — or just use deviceID
	_ = json.Unmarshal(msg.Payload, &p)

	player := &session.Player{
		DeviceID:    client.deviceID,
		DisplayName: p.DisplayName,
		AppVersion:  p.AppVersion,
		Conn:        client,
		Role:        "host",
	}

	s := h.registry.CreateSession(player)

	h.log.Info().Str("session", s.ID).Str("code", s.JoinCode).Msg("session created")

	h.sendJSON(client, Message{
		Type:      "session_created",
		SessionID: s.ID,
		Payload:   mustJSON(map[string]any{"join_code": s.JoinCode}),
	})
}

// --- Join Session ---

type joinPayload struct {
	JoinCode    string `json:"join_code"`
	DisplayName string `json:"display_name"`
	AppVersion  string `json:"app_version"`
}

func (h *Handler) handleJoinSession(client *Client, msg Message) {
	if client.deviceID == "" {
		h.sendError(client, "", "must send hello first")
		return
	}

	var p joinPayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, "", "invalid join payload")
		return
	}

	player := &session.Player{
		DeviceID:    client.deviceID,
		DisplayName: p.DisplayName,
		AppVersion:  p.AppVersion,
		Conn:        client,
		Role:        "guest",
	}

	s, err := h.registry.JoinSession(p.JoinCode, player)
	if err != nil {
		h.sendError(client, "", err.Error())
		return
	}

	h.log.Info().Str("session", s.ID).Str("guest", client.deviceID).Msg("player joined")

	// Send lobby_state to both players
	lobbyPayload := map[string]any{
		"host_name":         s.Host.DisplayName,
		"guest_name":        player.DisplayName,
		"host_app_version":  s.Host.AppVersion,
		"guest_app_version": player.AppVersion,
		"versions_match":    s.VersionsMatch(),
	}

	lobbyMsg := Message{
		Type:      "lobby_state",
		SessionID: s.ID,
		Payload:   mustJSON(lobbyPayload),
	}

	h.sendToPlayer(s.Host, lobbyMsg)
	h.sendToPlayer(player, lobbyMsg)

	// Check version mismatch
	if !s.VersionsMatch() {
		mismatchMsg := Message{
			Type:      "version_mismatch",
			SessionID: s.ID,
			Payload: mustJSON(map[string]any{
				"host_app_version":  s.Host.AppVersion,
				"guest_app_version": player.AppVersion,
				"message":           "Both apps need the same version to play",
			}),
		}
		h.sendToPlayer(s.Host, mismatchMsg)
		h.sendToPlayer(player, mismatchMsg)
	}

	// Transition to build phase
	s.Phase = session.PhaseBuild

	// Notify peer_joined to host
	h.sendJSON(client, Message{
		Type:      "peer_joined",
		SessionID: s.ID,
		Payload:   mustJSON(map[string]any{"peer_name": s.Host.DisplayName}),
	})

	h.sendToPlayer(s.Host, Message{
		Type:      "peer_joined",
		SessionID: s.ID,
		Payload:   mustJSON(map[string]any{"peer_name": player.DisplayName}),
	})
}

// --- Submit Maze ---

type submitMazePayload struct {
	Width  int     `json:"width"`
	Height int     `json:"height"`
	Cells  [][]int `json:"cells"`
}

func (h *Handler) handleSubmitMaze(client *Client, msg Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	var p submitMazePayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, msg.SessionID, "invalid maze payload")
		return
	}

	m := &maze.Maze{
		Width:  p.Width,
		Height: p.Height,
		Cells:  p.Cells,
	}

	if err := s.SubmitMaze(client.deviceID, m); err != nil {
		h.sendJSON(client, Message{
			Type:      "maze_invalid",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"error": err.Error()}),
		})
		return
	}

	h.sendJSON(client, Message{
		Type:      "maze_valid",
		SessionID: s.ID,
	})

	h.log.Info().Str("session", s.ID).Str("player", client.deviceID).Msg("maze submitted")
}

// --- Set Done ---

type setDonePayload struct {
	Done bool `json:"done"`
}

func (h *Handler) handleSetDone(client *Client, msg Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	var p setDonePayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, msg.SessionID, "invalid done payload")
		return
	}

	bothDone := s.SetDone(client.deviceID, p.Done)

	// Notify opponent of build state
	opponent := s.GetOpponent(client.deviceID)
	if opponent != nil {
		state := "building"
		if p.Done {
			state = "done"
		}
		h.sendToPlayer(opponent, Message{
			Type:      "peer_build_state",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"state": state}),
		})
	}

	if bothDone {
		// Send both_done, then start race after countdown
		bothDoneMsg := Message{
			Type:      "both_done",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"countdown_seconds": 3}),
		}
		h.sendToPlayer(s.Host, bothDoneMsg)
		h.sendToPlayer(s.Guest, bothDoneMsg)

		// Start race after countdown
		go func() {
			time.Sleep(3 * time.Second)
			s.StartRace()

			// Send race_started with initial revealed state
			h.sendRaceStarted(s)
		}()
	}
}

func (h *Handler) sendRaceStarted(s *session.Session) {
	// Host explores guest's maze — start at guest maze's start pos
	hostRevealed := s.HostRaceState.GetAllRevealed()
	h.sendToPlayer(s.Host, Message{
		Type:      "race_started",
		SessionID: s.ID,
		Payload: mustJSON(map[string]any{
			"position":    s.GuestMaze.StartPos(),
			"revealed":    hostRevealed,
			"active_turn": s.Host.DeviceID,
		}),
	})

	// Guest explores host's maze — start at host maze's start pos
	guestRevealed := s.GuestRaceState.GetAllRevealed()
	h.sendToPlayer(s.Guest, Message{
		Type:      "race_started",
		SessionID: s.ID,
		Payload: mustJSON(map[string]any{
			"position":    s.HostMaze.StartPos(),
			"revealed":    guestRevealed,
			"active_turn": s.Host.DeviceID,
		}),
	})
}

// --- Move ---

type movePayload struct {
	Direction string `json:"direction"`
}

func (h *Handler) handleMoveAttempt(client *Client, msg Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	var p movePayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, msg.SessionID, "invalid move payload")
		return
	}

	result, opponentEvent, activeTurn, err := s.ProcessMove(client.deviceID, p.Direction)
	if err != nil {
		h.sendError(client, msg.SessionID, err.Error())
		return
	}

	// Send move result to player
	h.sendJSON(client, Message{
		Type:      "move_result",
		SessionID: s.ID,
		Payload:   mustJSON(result),
	})

	// Send opponent progress if notable event
	if opponentEvent != "" {
		opponent := s.GetOpponent(client.deviceID)
		player := s.GetPlayer(client.deviceID)
		if opponent != nil && player != nil {
			h.sendToPlayer(opponent, Message{
				Type:      "opponent_progress",
				SessionID: s.ID,
				Payload: mustJSON(map[string]any{
					"event":       opponentEvent,
					"player_name": player.DisplayName,
				}),
			})
		}
	}

	// Broadcast turn change to both players (skip if game is over)
	if !result.GameOver {
		turnMsg := Message{
			Type:      "turn_changed",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"active_device_id": activeTurn}),
		}
		h.sendToPlayer(s.Host, turnMsg)
		h.sendToPlayer(s.Guest, turnMsg)
	}

	// Check game over
	if result.GameOver {
		// Atomically snapshot all session data under lock
		snap := s.BuildGameOverSnapshot(client.deviceID)
		if snap == nil {
			h.sendError(client, msg.SessionID, "invalid session state at game over")
			return
		}

		// Save match record
		if h.matchStore != nil {
			record := match.MatchRecord{
				ID:              s.ID,
				PlayedAt:        time.Now(),
				RaceDurationSec: snap.RaceDurationSec,
				WinnerName:      snap.WinnerName,
				WinnerDeviceID:  snap.WinnerDeviceID,
				WinnerMoves:     snap.WinnerMoves,
				LoserName:       snap.LoserName,
				LoserDeviceID:   snap.LoserDeviceID,
				LoserMoves:      snap.LoserMoves,
				HostMaze:        snap.HostMaze,
				GuestMaze:       snap.GuestMaze,
				HostName:        snap.HostName,
				GuestName:       snap.GuestName,
				HostDeviceID:    snap.HostDeviceID,
				GuestDeviceID:   snap.GuestDeviceID,
				Reason:          "found_treasure",
			}
			if err := h.matchStore.Save(record); err != nil {
				h.log.Error().Err(err).Msg("save match record")
			}
		}

		// Enriched game_over payload
		gameOverMsg := Message{
			Type:      "game_over",
			SessionID: s.ID,
			Payload: mustJSON(map[string]any{
				"winner_device_id": snap.WinnerDeviceID,
				"winner_name":      snap.WinnerName,
				"reason":           "found_treasure",
				"race_duration_s":  snap.RaceDurationSec,
				"winner_moves":     snap.WinnerMoves,
				"loser_name":       snap.LoserName,
				"loser_device_id":  snap.LoserDeviceID,
				"loser_moves":      snap.LoserMoves,
				"host_maze":        snap.HostMaze,
				"guest_maze":       snap.GuestMaze,
				"host_name":        snap.HostName,
				"guest_name":       snap.GuestName,
				"host_device_id":   snap.HostDeviceID,
				"guest_device_id":  snap.GuestDeviceID,
			}),
		}
		h.sendToPlayer(s.Host, gameOverMsg)
		h.sendToPlayer(s.Guest, gameOverMsg)
	}
}

// --- Rematch ---

func (h *Handler) handleRematch(client *Client, msg Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	s.ResetForRematch()

	resetMsg := Message{
		Type:      "lobby_state",
		SessionID: s.ID,
		Payload: mustJSON(map[string]any{
			"host_name":        s.Host.DisplayName,
			"guest_name":       s.Guest.DisplayName,
			"host_app_version": s.Host.AppVersion,
			"guest_app_version": s.Guest.AppVersion,
			"versions_match":   s.VersionsMatch(),
			"rematch":          true,
		}),
	}

	h.sendToPlayer(s.Host, resetMsg)
	h.sendToPlayer(s.Guest, resetMsg)
}

// --- Leave ---

func (h *Handler) handleLeave(client *Client, msg Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	opponent := s.GetOpponent(client.deviceID)
	if opponent != nil {
		player := s.GetPlayer(client.deviceID)
		name := ""
		if player != nil {
			name = player.DisplayName
		}
		h.sendToPlayer(opponent, Message{
			Type:      "peer_left",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"player_name": name}),
		})
	}

	h.registry.RemoveSession(s.ID)
}

// --- Helpers ---

func (h *Handler) getSessionForPlayer(client *Client, sessionID string) *session.Session {
	if sessionID == "" {
		h.sendError(client, "", "session_id required")
		return nil
	}
	s := h.registry.GetSession(sessionID)
	if s == nil {
		h.sendError(client, sessionID, "session not found")
		return nil
	}
	return s
}

func (h *Handler) sendJSON(client *Client, msg Message) {
	data, err := json.Marshal(msg)
	if err != nil {
		h.log.Error().Err(err).Msg("marshal error")
		return
	}
	if err := client.Send(data); err != nil {
		h.log.Debug().Err(err).Str("device", client.deviceID).Msg("send error")
	}
}

func (h *Handler) sendToPlayer(player *session.Player, msg Message) {
	if player == nil || player.Conn == nil {
		return
	}
	data, err := json.Marshal(msg)
	if err != nil {
		h.log.Error().Err(err).Msg("marshal error")
		return
	}
	if err := player.Conn.Send(data); err != nil {
		h.log.Debug().Err(err).Str("device", player.DeviceID).Msg("send to player error")
	}
}

func (h *Handler) sendError(client *Client, sessionID, errMsg string) {
	h.sendJSON(client, Message{
		Type:      "error",
		SessionID: sessionID,
		Payload:   mustJSON(map[string]string{"message": errMsg}),
	})
}

// cleanupDisconnectedPlayer removes orphaned lobby sessions and notifies opponents.
func (h *Handler) cleanupDisconnectedPlayer(deviceID string) {
	sessions := h.registry.FindSessionsByPlayer(deviceID)
	for _, s := range sessions {
		if s.IsWaitingLobby() {
			// Orphaned waiting session — remove it
			h.registry.RemoveSession(s.ID)
			h.log.Info().Str("session", s.ID).Msg("removed orphaned lobby session")
		} else {
			opponent := s.GetOpponent(deviceID)
			if opponent != nil {
				h.sendToPlayer(opponent, Message{
					Type:      "peer_left",
					SessionID: s.ID,
					Payload:   mustJSON(map[string]any{"player_name": ""}),
				})
			}
		}
	}
}

func mustJSON(v any) json.RawMessage {
	data, err := json.Marshal(v)
	if err != nil {
		panic(fmt.Sprintf("mustJSON: %v", err))
	}
	return data
}
