package bs_ws

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/1F47E/maze-server/internal/battleships"
	bssession "github.com/1F47E/maze-server/internal/bs_session"
	"github.com/1F47E/maze-server/internal/session"
	"github.com/1F47E/maze-server/internal/ws"
	"github.com/gofiber/websocket/v2"
	"github.com/rs/zerolog"
)

// Handler manages WebSocket connections for Battleships.
type Handler struct {
	registry *bssession.Registry
	log      zerolog.Logger
	clients  sync.Map // deviceID -> *ws.Client
}

// NewHandler creates a new Battleships WebSocket handler.
func NewHandler(registry *bssession.Registry, log zerolog.Logger) *Handler {
	return &Handler{
		registry: registry,
		log:      log,
	}
}

// HandleConnection handles a single WebSocket connection.
func (h *Handler) HandleConnection(c *websocket.Conn) {
	client := ws.NewClient(c)
	defer func() {
		if client.DeviceID() != "" {
			h.clients.Delete(client.DeviceID())
			h.cleanupDisconnectedPlayer(client.DeviceID())
		}
		c.Close()
	}()

	c.SetReadDeadline(time.Now().Add(30 * time.Second))

	for {
		_, raw, err := c.ReadMessage()
		if err != nil {
			h.log.Debug().Err(err).Str("device", client.DeviceID()).Msg("bs read error")
			return
		}
		c.SetReadDeadline(time.Now().Add(60 * time.Second))

		var msg ws.Message
		if err := json.Unmarshal(raw, &msg); err != nil {
			h.sendError(client, "", "invalid message format")
			continue
		}

		h.routeMessage(client, msg)
	}
}

func (h *Handler) routeMessage(client *ws.Client, msg ws.Message) {
	switch msg.Type {
	case "hello":
		h.handleHello(client, msg)
	case "auto_match":
		h.handleAutoMatch(client, msg)
	case "create_session":
		h.handleCreateSession(client, msg)
	case "join_session":
		h.handleJoinSession(client, msg)
	case "submit_fleet":
		h.handleSubmitFleet(client, msg)
	case "set_ready":
		h.handleSetReady(client, msg)
	case "fire_shot":
		h.handleFireShot(client, msg)
	case "request_state":
		h.handleRequestState(client, msg)
	case "request_rematch":
		h.handleRematch(client, msg)
	case "leave_session":
		h.handleLeave(client, msg)
	case "ping":
		h.sendJSON(client, ws.Message{Type: "pong"})
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

func (h *Handler) handleHello(client *ws.Client, msg ws.Message) {
	var p helloPayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, "", "invalid hello payload")
		return
	}
	if p.DeviceID == "" {
		h.sendError(client, "", "device_id required")
		return
	}

	client.SetDeviceID(p.DeviceID)
	h.clients.Store(p.DeviceID, client)

	h.log.Info().Str("device", p.DeviceID).Str("name", p.DisplayName).Msg("bs player connected")
}

// --- Auto Match ---

func (h *Handler) handleAutoMatch(client *ws.Client, msg ws.Message) {
	if client.DeviceID() == "" {
		h.sendError(client, "", "must send hello first")
		return
	}

	var p helloPayload
	_ = json.Unmarshal(msg.Payload, &p)

	player := &session.Player{
		DeviceID:    client.DeviceID(),
		DisplayName: p.DisplayName,
		AppVersion:  p.AppVersion,
		Conn:        client,
		Role:        "host",
	}

	s, isHost := h.registry.FindOrCreateAutoMatch(player)

	if isHost {
		h.log.Info().Str("session", s.ID).Msg("bs auto-match: waiting")
		h.sendJSON(client, ws.Message{
			Type:      "session_created",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"join_code": s.JoinCode, "auto_match": true}),
		})
	} else {
		player.Role = "guest"
		h.log.Info().Str("session", s.ID).Str("guest", client.DeviceID()).Msg("bs auto-match: joined")

		lobbyPayload := map[string]any{
			"host_name":         s.Host.DisplayName,
			"guest_name":        player.DisplayName,
			"host_app_version":  s.Host.AppVersion,
			"guest_app_version": player.AppVersion,
			"versions_match":    s.VersionsMatch(),
		}
		lobbyMsg := ws.Message{
			Type:      "lobby_state",
			SessionID: s.ID,
			Payload:   mustJSON(lobbyPayload),
		}
		h.sendToPlayer(s.Host, lobbyMsg)
		h.sendToPlayer(player, lobbyMsg)

		s.TransitionToPlace()

		h.sendJSON(client, ws.Message{
			Type:      "peer_joined",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"peer_name": s.Host.DisplayName}),
		})
		h.sendToPlayer(s.Host, ws.Message{
			Type:      "peer_joined",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"peer_name": player.DisplayName}),
		})
	}
}

// --- Create Session ---

func (h *Handler) handleCreateSession(client *ws.Client, msg ws.Message) {
	if client.DeviceID() == "" {
		h.sendError(client, "", "must send hello first")
		return
	}

	var p helloPayload
	_ = json.Unmarshal(msg.Payload, &p)

	player := &session.Player{
		DeviceID:    client.DeviceID(),
		DisplayName: p.DisplayName,
		AppVersion:  p.AppVersion,
		Conn:        client,
		Role:        "host",
	}

	s := h.registry.CreateSession(player)
	h.log.Info().Str("session", s.ID).Str("code", s.JoinCode).Msg("bs session created")

	h.sendJSON(client, ws.Message{
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

func (h *Handler) handleJoinSession(client *ws.Client, msg ws.Message) {
	if client.DeviceID() == "" {
		h.sendError(client, "", "must send hello first")
		return
	}

	var p joinPayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, "", "invalid join payload")
		return
	}

	player := &session.Player{
		DeviceID:    client.DeviceID(),
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

	h.log.Info().Str("session", s.ID).Str("guest", client.DeviceID()).Msg("bs player joined")

	lobbyPayload := map[string]any{
		"host_name":         s.Host.DisplayName,
		"guest_name":        player.DisplayName,
		"host_app_version":  s.Host.AppVersion,
		"guest_app_version": player.AppVersion,
		"versions_match":    s.VersionsMatch(),
	}
	lobbyMsg := ws.Message{
		Type:      "lobby_state",
		SessionID: s.ID,
		Payload:   mustJSON(lobbyPayload),
	}
	h.sendToPlayer(s.Host, lobbyMsg)
	h.sendToPlayer(player, lobbyMsg)

	s.TransitionToPlace()

	h.sendJSON(client, ws.Message{
		Type:      "peer_joined",
		SessionID: s.ID,
		Payload:   mustJSON(map[string]any{"peer_name": s.Host.DisplayName}),
	})
	h.sendToPlayer(s.Host, ws.Message{
		Type:      "peer_joined",
		SessionID: s.ID,
		Payload:   mustJSON(map[string]any{"peer_name": player.DisplayName}),
	})
}

// --- Submit Fleet ---

type submitFleetPayload struct {
	Ships []shipPlacementJSON `json:"ships"`
}

type shipPlacementJSON struct {
	Type  shipTypeJSON   `json:"type"`
	Cells []battleships.Point `json:"cells"`
}

type shipTypeJSON struct {
	Name string `json:"name"`
	Size int    `json:"size"`
}

func (h *Handler) handleSubmitFleet(client *ws.Client, msg ws.Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	var p submitFleetPayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendJSON(client, ws.Message{
			Type:      "fleet_invalid",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"error": "invalid fleet payload"}),
		})
		return
	}

	// Convert JSON ships to battleships.ShipPlacement
	fleet := make([]battleships.ShipPlacement, len(p.Ships))
	for i, sp := range p.Ships {
		fleet[i] = battleships.ShipPlacement{
			Type:  battleships.ShipType{Name: sp.Type.Name, Size: sp.Type.Size},
			Cells: sp.Cells,
		}
	}

	if err := s.SubmitFleet(client.DeviceID(), fleet); err != nil {
		h.sendJSON(client, ws.Message{
			Type:      "fleet_invalid",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"error": err.Error()}),
		})
		return
	}

	h.sendJSON(client, ws.Message{
		Type:      "fleet_valid",
		SessionID: s.ID,
	})

	h.log.Info().Str("session", s.ID).Str("player", client.DeviceID()).Msg("bs fleet submitted")

	// Notify opponent that peer has placed fleet
	opponent := s.GetOpponent(client.DeviceID())
	if opponent != nil {
		h.sendToPlayer(opponent, ws.Message{
			Type:      "peer_fleet_placed",
			SessionID: s.ID,
		})
	}
}

// --- Set Ready ---

type setReadyPayload struct {
	Ready bool `json:"ready"`
}

func (h *Handler) handleSetReady(client *ws.Client, msg ws.Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	var p setReadyPayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, msg.SessionID, "invalid ready payload")
		return
	}

	bothReady := s.SetReady(client.DeviceID(), p.Ready)

	// Notify opponent of ready state
	opponent := s.GetOpponent(client.DeviceID())
	if opponent != nil {
		h.sendToPlayer(opponent, ws.Message{
			Type:      "peer_ready_state",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"ready": p.Ready}),
		})
	}

	if bothReady {
		// Start the battle first — only notify clients if successful
		if err := s.StartBattle(); err != nil {
			h.log.Error().Err(err).Str("session", s.ID).Msg("StartBattle failed")
			h.sendError(client, s.ID, "cannot start battle: "+err.Error())
			return
		}

		bothReadyMsg := ws.Message{
			Type:      "both_ready",
			SessionID: s.ID,
		}
		h.sendToPlayer(s.Host, bothReadyMsg)
		h.sendToPlayer(s.Guest, bothReadyMsg)

		h.sendBattleStarted(s)
	}
}

func (h *Handler) sendBattleStarted(s *bssession.BattleSession) {
	// Both players get battle_started with their initial view
	msg := ws.Message{
		Type:      "battle_started",
		SessionID: s.ID,
		Payload: mustJSON(map[string]any{
			"active_turn": s.ActiveTurn,
		}),
	}
	h.sendToPlayer(s.Host, msg)
	h.sendToPlayer(s.Guest, msg)
}

// --- Fire Shot ---

type fireShotPayload struct {
	X int `json:"x"`
	Y int `json:"y"`
}

func (h *Handler) handleFireShot(client *ws.Client, msg ws.Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	var p fireShotPayload
	if err := json.Unmarshal(msg.Payload, &p); err != nil {
		h.sendError(client, msg.SessionID, "invalid fire_shot payload")
		return
	}

	shotResult, err := s.ProcessShot(client.DeviceID(), p.X, p.Y)
	if err != nil {
		h.sendError(client, msg.SessionID, err.Error())
		return
	}

	// Send shot_result to the shooter
	h.sendJSON(client, ws.Message{
		Type:      "shot_result",
		SessionID: s.ID,
		Payload:   mustJSON(shotResult),
	})

	// Send opponent_shot to the opponent
	opponent := s.GetOpponent(client.DeviceID())
	if opponent != nil {
		h.sendToPlayer(opponent, ws.Message{
			Type:      "opponent_shot",
			SessionID: s.ID,
			Payload:   mustJSON(shotResult),
		})
	}

	if shotResult.GameOver {
		winner := s.GetPlayer(client.DeviceID())
		loser := opponent

		winnerName := ""
		loserName := ""
		loserDeviceID := ""
		if winner != nil {
			winnerName = winner.DisplayName
		}
		if loser != nil {
			loserName = loser.DisplayName
			loserDeviceID = loser.DeviceID
		}

		gameOverMsg := ws.Message{
			Type:      "game_over",
			SessionID: s.ID,
			Payload: mustJSON(map[string]any{
				"winner_device_id": client.DeviceID(),
				"winner_name":      winnerName,
				"loser_device_id":  loserDeviceID,
				"loser_name":       loserName,
				"reason":           "all_ships_sunk",
			}),
		}
		h.sendToPlayer(s.Host, gameOverMsg)
		h.sendToPlayer(s.Guest, gameOverMsg)
	} else {
		// Broadcast turn change to both
		turnMsg := ws.Message{
			Type:      "turn_changed",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"active_device_id": shotResult.NextTurn}),
		}
		h.sendToPlayer(s.Host, turnMsg)
		h.sendToPlayer(s.Guest, turnMsg)
	}
}

// --- Request State ---

func (h *Handler) handleRequestState(client *ws.Client, msg ws.Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	deviceID := client.DeviceID()
	isHost := s.Host != nil && s.Host.DeviceID == deviceID

	var myState *battleships.BattleState
	var opponentState *battleships.BattleState

	if isHost {
		myState = s.HostBattleState
		opponentState = s.GuestBattleState
	} else {
		myState = s.GuestBattleState
		opponentState = s.HostBattleState
	}

	payload := map[string]any{
		"phase":       s.Phase,
		"active_turn": s.ActiveTurn,
		"winner":      s.Winner,
	}

	if myState != nil {
		payload["my_grid"] = myState.MyGrid.Cells
		payload["target_grid"] = myState.TargetGrid.Cells
		payload["shots_fired"] = myState.ShotsFired
		payload["hits"] = myState.Hits
		payload["ships_sunk"] = myState.ShipsSunk
		payload["ships_remaining"] = myState.ShipsRemaining
	}

	if opponentState != nil {
		payload["opponent_ships_remaining"] = opponentState.ShipsRemaining
	}

	h.sendJSON(client, ws.Message{
		Type:      "battle_state",
		SessionID: s.ID,
		Payload:   mustJSON(payload),
	})
}

// --- Rematch ---

func (h *Handler) handleRematch(client *ws.Client, msg ws.Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	s.ResetForRematch()

	resetMsg := ws.Message{
		Type:      "lobby_state",
		SessionID: s.ID,
		Payload: mustJSON(map[string]any{
			"host_name":         s.Host.DisplayName,
			"guest_name":        s.Guest.DisplayName,
			"host_app_version":  s.Host.AppVersion,
			"guest_app_version": s.Guest.AppVersion,
			"versions_match":    s.VersionsMatch(),
			"rematch":           true,
		}),
	}
	h.sendToPlayer(s.Host, resetMsg)
	h.sendToPlayer(s.Guest, resetMsg)
}

// --- Leave ---

func (h *Handler) handleLeave(client *ws.Client, msg ws.Message) {
	s := h.getSessionForPlayer(client, msg.SessionID)
	if s == nil {
		return
	}

	opponent := s.GetOpponent(client.DeviceID())
	if opponent != nil {
		player := s.GetPlayer(client.DeviceID())
		name := ""
		if player != nil {
			name = player.DisplayName
		}
		h.sendToPlayer(opponent, ws.Message{
			Type:      "peer_left",
			SessionID: s.ID,
			Payload:   mustJSON(map[string]any{"player_name": name}),
		})
	}

	h.registry.RemoveSession(s.ID)
}

// --- Helpers ---

func (h *Handler) getSessionForPlayer(client *ws.Client, sessionID string) *bssession.BattleSession {
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

func (h *Handler) sendJSON(client *ws.Client, msg ws.Message) {
	data, err := json.Marshal(msg)
	if err != nil {
		h.log.Error().Err(err).Msg("bs marshal error")
		return
	}
	if err := client.Send(data); err != nil {
		h.log.Debug().Err(err).Str("device", client.DeviceID()).Msg("bs send error")
	}
}

func (h *Handler) sendToPlayer(player *session.Player, msg ws.Message) {
	if player == nil || player.Conn == nil {
		return
	}
	data, err := json.Marshal(msg)
	if err != nil {
		h.log.Error().Err(err).Msg("bs marshal error")
		return
	}
	if err := player.Conn.Send(data); err != nil {
		h.log.Debug().Err(err).Str("device", player.DeviceID).Msg("bs send to player error")
	}
}

func (h *Handler) sendError(client *ws.Client, sessionID, errMsg string) {
	h.sendJSON(client, ws.Message{
		Type:      "error",
		SessionID: sessionID,
		Payload:   mustJSON(map[string]string{"message": errMsg}),
	})
}

func (h *Handler) cleanupDisconnectedPlayer(deviceID string) {
	sessions := h.registry.FindSessionsByPlayer(deviceID)
	for _, s := range sessions {
		if s.IsWaitingLobby() {
			h.registry.RemoveSession(s.ID)
			h.log.Info().Str("session", s.ID).Msg("bs removed orphaned lobby session")
		} else {
			opponent := s.GetOpponent(deviceID)
			if opponent != nil {
				h.sendToPlayer(opponent, ws.Message{
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
