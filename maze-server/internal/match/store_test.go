package match

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/rs/zerolog"
)

func testStore(t *testing.T) (*Store, string) {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "matches.jsonl")
	log := zerolog.Nop()
	return NewStore(path, log), path
}

func sampleMatch(id string) MatchRecord {
	return MatchRecord{
		ID:              id,
		PlayedAt:        time.Now(),
		RaceDurationSec: 42,
		WinnerName:      "Alice",
		WinnerDeviceID:  "device_a",
		WinnerMoves:     12,
		LoserName:       "Bob",
		LoserDeviceID:   "device_b",
		LoserMoves:      8,
		HostMaze:        [][]int{{0, 1}, {1, 0}},
		GuestMaze:       [][]int{{0, 0}, {0, 1}},
		HostName:        "Alice",
		GuestName:       "Bob",
		Reason:          "found_treasure",
	}
}

func TestSaveAndList(t *testing.T) {
	s, _ := testStore(t)

	if err := s.Save(sampleMatch("m1")); err != nil {
		t.Fatalf("save: %v", err)
	}
	if err := s.Save(sampleMatch("m2")); err != nil {
		t.Fatalf("save: %v", err)
	}

	list := s.List(10)
	if len(list) != 2 {
		t.Fatalf("expected 2, got %d", len(list))
	}
	// Most recent first
	if list[0].ID != "m2" {
		t.Errorf("expected m2 first, got %s", list[0].ID)
	}
	if list[1].ID != "m1" {
		t.Errorf("expected m1 second, got %s", list[1].ID)
	}
}

func TestListLimit(t *testing.T) {
	s, _ := testStore(t)

	for i := range 5 {
		_ = s.Save(sampleMatch("m" + string(rune('0'+i))))
	}

	list := s.List(3)
	if len(list) != 3 {
		t.Fatalf("expected 3, got %d", len(list))
	}
}

func TestGet(t *testing.T) {
	s, _ := testStore(t)

	_ = s.Save(sampleMatch("m1"))
	_ = s.Save(sampleMatch("m2"))

	r := s.Get("m1")
	if r == nil {
		t.Fatal("expected to find m1")
	}
	if r.WinnerName != "Alice" {
		t.Errorf("wrong winner: %s", r.WinnerName)
	}

	if s.Get("nonexistent") != nil {
		t.Error("should return nil for missing ID")
	}
}

func TestListByPlayer(t *testing.T) {
	s, _ := testStore(t)

	m1 := sampleMatch("m1")
	m1.WinnerDeviceID = "device_a"
	m1.LoserDeviceID = "device_b"

	m2 := sampleMatch("m2")
	m2.WinnerDeviceID = "device_c"
	m2.LoserDeviceID = "device_a"

	m3 := sampleMatch("m3")
	m3.WinnerDeviceID = "device_c"
	m3.LoserDeviceID = "device_d"

	_ = s.Save(m1)
	_ = s.Save(m2)
	_ = s.Save(m3)

	// device_a played in m1 and m2
	list := s.ListByPlayer("device_a", 10)
	if len(list) != 2 {
		t.Fatalf("expected 2 matches for device_a, got %d", len(list))
	}

	// device_d only in m3
	list = s.ListByPlayer("device_d", 10)
	if len(list) != 1 {
		t.Fatalf("expected 1 match for device_d, got %d", len(list))
	}
}

func TestPersistence(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "matches.jsonl")
	log := zerolog.Nop()

	// Save with first store
	s1 := NewStore(path, log)
	_ = s1.Save(sampleMatch("m1"))
	_ = s1.Save(sampleMatch("m2"))

	// Load with new store
	s2 := NewStore(path, log)
	if s2.Count() != 2 {
		t.Fatalf("expected 2 after reload, got %d", s2.Count())
	}
	if s2.Get("m1") == nil {
		t.Error("m1 should exist after reload")
	}
}

func TestEmptyFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "matches.jsonl")

	// Create empty file
	_ = os.WriteFile(path, []byte(""), 0o644)

	log := zerolog.Nop()
	s := NewStore(path, log)
	if s.Count() != 0 {
		t.Fatalf("expected 0 from empty file, got %d", s.Count())
	}
}

func TestCount(t *testing.T) {
	s, _ := testStore(t)

	if s.Count() != 0 {
		t.Fatalf("expected 0, got %d", s.Count())
	}
	_ = s.Save(sampleMatch("m1"))
	if s.Count() != 1 {
		t.Fatalf("expected 1, got %d", s.Count())
	}
}
