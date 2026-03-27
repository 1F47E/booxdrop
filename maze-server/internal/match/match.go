package match

import "time"

// MatchRecord stores the result of a completed maze race.
type MatchRecord struct {
	ID              string    `json:"id"`
	PlayedAt        time.Time `json:"played_at"`
	RaceDurationSec int       `json:"race_duration_s"`

	WinnerName     string `json:"winner_name"`
	WinnerDeviceID string `json:"winner_device_id"`
	WinnerMoves    int    `json:"winner_moves"`

	LoserName      string `json:"loser_name"`
	LoserDeviceID  string `json:"loser_device_id"`
	LoserMoves     int    `json:"loser_moves"`

	HostMaze      [][]int `json:"host_maze"`
	GuestMaze     [][]int `json:"guest_maze"`
	HostName      string  `json:"host_name"`
	GuestName     string  `json:"guest_name"`
	HostDeviceID  string  `json:"host_device_id"`
	GuestDeviceID string  `json:"guest_device_id"`

	Reason string `json:"reason"`
}
