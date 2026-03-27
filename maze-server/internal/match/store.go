package match

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"sync"

	"github.com/rs/zerolog"
)

// Store persists match records as NDJSON (one JSON object per line).
type Store struct {
	mu      sync.RWMutex
	records []MatchRecord
	path    string
	log     zerolog.Logger
}

// NewStore creates a store that reads/writes to the given file path.
func NewStore(path string, log zerolog.Logger) *Store {
	s := &Store{
		path: path,
		log:  log,
	}
	s.load()
	return s
}

// Save persists a match record to disk, then appends to memory.
func (s *Store) Save(r MatchRecord) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Ensure directory exists
	dir := filepath.Dir(s.path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		s.log.Error().Err(err).Msg("create data dir")
		return err
	}

	f, err := os.OpenFile(s.path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		s.log.Error().Err(err).Msg("open matches file")
		return err
	}
	defer f.Close()

	data, err := json.Marshal(r)
	if err != nil {
		return err
	}
	data = append(data, '\n')
	if _, err = f.Write(data); err != nil {
		s.log.Error().Err(err).Msg("write match")
		return err
	}

	// Only append to memory after successful disk write
	s.records = append(s.records, r)
	return nil
}

// List returns the most recent N match records.
func (s *Store) List(limit int) []MatchRecord {
	s.mu.RLock()
	defer s.mu.RUnlock()

	n := len(s.records)
	if limit <= 0 || limit > n {
		limit = n
	}

	// Return most recent first
	result := make([]MatchRecord, limit)
	for i := range limit {
		result[i] = s.records[n-1-i]
	}
	return result
}

// Get returns a single match by ID, or nil if not found.
func (s *Store) Get(id string) *MatchRecord {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for i := range s.records {
		if s.records[i].ID == id {
			r := s.records[i]
			return &r
		}
	}
	return nil
}

// ListByPlayer returns matches involving a specific device ID.
func (s *Store) ListByPlayer(deviceID string, limit int) []MatchRecord {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []MatchRecord
	// Iterate from newest to oldest
	for i := len(s.records) - 1; i >= 0; i-- {
		r := s.records[i]
		if r.WinnerDeviceID == deviceID || r.LoserDeviceID == deviceID {
			result = append(result, r)
			if limit > 0 && len(result) >= limit {
				break
			}
		}
	}
	return result
}

// Count returns the total number of stored matches.
func (s *Store) Count() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.records)
}

// load reads the NDJSON file into memory on startup.
func (s *Store) load() {
	f, err := os.Open(s.path)
	if err != nil {
		if os.IsNotExist(err) {
			s.log.Info().Str("path", s.path).Msg("no existing matches file, starting fresh")
			return
		}
		s.log.Error().Err(err).Msg("open matches file for loading")
		return
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024) // 1MB line buffer
	count := 0
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}
		var r MatchRecord
		if err := json.Unmarshal(line, &r); err != nil {
			s.log.Warn().Err(err).Int("line", count+1).Msg("skip bad match line")
			continue
		}
		s.records = append(s.records, r)
		count++
	}
	s.log.Info().Int("count", count).Msg("loaded match history")
}
