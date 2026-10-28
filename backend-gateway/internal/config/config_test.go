package config

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestConfigPrecedenceAndRelativeStorage(t *testing.T) {
	root := t.TempDir()
	service := filepath.Join(root, "gateway")
	if err := os.Mkdir(service, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, ".env"), []byte("ML_SERVICE_URL=http://root:8000\nUPSTREAM_TIMEOUT_SECONDS=11\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(service, ".env"), []byte("ML_SERVICE_URL=http://service:8001\nGATEWAY_ADDR=127.0.0.1:8089\nHISTORY_PATH=results/history.json\n"), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("ML_SERVICE_URL", "http://process:8002")
	cfg, err := Load(service)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.MLURL != "http://process:8002" || cfg.Address != "127.0.0.1:8089" || cfg.UpstreamTimeout != 11*time.Second || cfg.HistoryPath != filepath.Join(service, "results/history.json") {
		t.Fatalf("unexpected configuration: %+v", cfg)
	}
}

func TestRejectInvalidConfiguration(t *testing.T) {
	for _, value := range []string{"file:///tmp/model", "http://localhost:8000/api", "http://user:pass@localhost:8000"} {
		t.Run(value, func(t *testing.T) {
			t.Setenv("ML_SERVICE_URL", value)
			if _, err := Load(t.TempDir()); err == nil {
				t.Fatal("invalid upstream accepted")
			}
		})
	}
}
