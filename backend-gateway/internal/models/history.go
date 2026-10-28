package models

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type PredictionSummary struct {
	Label       string   `json:"label"`
	Probability *float64 `json:"malignant_probability"`
	Disease string `json:"disease"`
	PositiveProbability *float64 `json:"positive_probability"`
}

func (p PredictionSummary) Valid() bool {
	probability := p.PositiveProbability
	if probability == nil && (p.Disease == "" || p.Disease == "breast_cancer") { probability = p.Probability }
	labels := map[string][]string{"": {"benign", "malignant"}, "breast_cancer": {"benign", "malignant"}, "heart_disease": {"heart_disease_absent", "heart_disease_present"}, "diabetes": {"diabetes_negative", "diabetes_positive"}}
	allowed := labels[p.Disease]
	return len(allowed) == 2 && (p.Label == allowed[0] || p.Label == allowed[1]) && probability != nil && *probability >= 0 && *probability <= 1
}

type Record struct {
	ID        string          `json:"id"`
	CreatedAt time.Time       `json:"created_at"`
	Result    json.RawMessage `json:"result"`
}

// Store saves only model results, never identifying details or measurements.
// A single gateway process owns the file; rename commits changes before publishing them in memory.
type Store struct {
	mu      sync.Mutex
	path    string
	records []Record
}

func OpenStore(path string) (*Store, error) {
	s := &Store{path: path, records: []Record{}}
	contents, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(contents, &s.records); err != nil {
		return nil, fmt.Errorf("read history: %w", err)
	}
	if s.records == nil {
		s.records = []Record{}
	}
	return s, nil
}

func (s *Store) commit(records []Record) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(records, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(s.path), ".history-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if _, err = tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Close(); err != nil {
		return err
	}
	if err = os.Rename(name, s.path); err != nil {
		return err
	}
	s.records = records
	return nil
}

func (s *Store) Add(result json.RawMessage) (Record, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var token [16]byte
	if _, err := rand.Read(token[:]); err != nil {
		return Record{}, err
	}
	record := Record{ID: hex.EncodeToString(token[:]), CreatedAt: time.Now().UTC(), Result: result}
	records := append([]Record{record}, s.records...)
	if len(records) > 200 {
		records = records[:200]
	}
	return record, s.commit(records)
}

func (s *Store) List(limit int) ([]Record, int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	n := len(s.records)
	if limit > n {
		limit = n
	}
	return append([]Record{}, s.records[:limit]...), n
}

func (s *Store) Clear() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.commit([]Record{})
}
