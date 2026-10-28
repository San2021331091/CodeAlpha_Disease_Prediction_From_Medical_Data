package main

import (
	"codealpha/cellscope/gateway/internal/controllers"
	"codealpha/cellscope/gateway/internal/models"
	"codealpha/cellscope/gateway/internal/routes"
	"codealpha/cellscope/gateway/internal/services"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestPredictionPersistenceAndClear(t *testing.T) {
	ml := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.Method == "POST" {
			w.Write([]byte(`{"label":"benign","malignant_probability":0.1}`))
			return
		}
		w.Write([]byte(`{"status":"ok"}`))
	}))
	defer ml.Close()
	path := filepath.Join(t.TempDir(), "history.json")
	store, err := models.OpenStore(path)
	if err != nil {
		t.Fatal(err)
	}
	g := &controllers.Gateway{ML: &services.MLClient{URL: ml.URL, HTTP: ml.Client()}, Store: store}
	r := routes.New(g)
	for i := 0; i < 2; i++ {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest("POST", "/api/predict", strings.NewReader(`{"features":{}}`)))
		if w.Code != 200 {
			t.Fatalf("prediction: %d %s", w.Code, w.Body.String())
		}
		var record models.Record
		if err := json.Unmarshal(w.Body.Bytes(), &record); err != nil || record.ID == "" || record.CreatedAt.IsZero() {
			t.Fatal("invalid prediction record")
		}
	}
	reloaded, err := models.OpenStore(path)
	if err != nil {
		t.Fatal(err)
	}
	items, total := reloaded.List(1)
	if total != 2 || len(items) != 1 {
		t.Fatal("history not persisted")
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("DELETE", "/api/history", nil))
	if w.Code != 200 {
		t.Fatal(w.Body.String())
	}
	reloaded, err = models.OpenStore(path)
	if err != nil {
		t.Fatal(err)
	}
	_, total = reloaded.List(200)
	if total != 0 {
		t.Fatal("clear not persisted")
	}
}

func TestErrorsDoNotCreateHistory(t *testing.T) {
	for _, upstreamStatus := range []int{422, 503} {
		ml := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(upstreamStatus)
			w.Write([]byte(`{"detail":"upstream error"}`))
		}))
		store, _ := models.OpenStore(filepath.Join(t.TempDir(), "history.json"))
		g := &controllers.Gateway{ML: &services.MLClient{URL: ml.URL, HTTP: &http.Client{Timeout: time.Second}}, Store: store}
		r := routes.New(g)
		for _, tc := range []struct {
			body   string
			status int
		}{{`{}`, upstreamStatus}, {`bad`, 400}, {strings.Repeat("x", 65537), 413}} {
			w := httptest.NewRecorder()
			r.ServeHTTP(w, httptest.NewRequest("POST", "/api/predict", strings.NewReader(tc.body)))
			if w.Code != tc.status {
				t.Fatalf("got %d want %d", w.Code, tc.status)
			}
		}
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest("GET", "/api/history?limit=-1", nil))
		if w.Code != 400 {
			t.Fatal("invalid history limit accepted")
		}
		_, total := store.List(200)
		if total != 0 {
			t.Fatal("failed requests saved")
		}
		ml.Close()
	}
}
