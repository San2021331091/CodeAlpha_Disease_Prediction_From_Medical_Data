package config

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"github.com/joho/godotenv"
)

type Config struct {
	Address         string
	MLURL           string
	HistoryPath     string
	UpstreamTimeout time.Duration
}

// Load leaves process environment untouched: OS > service .env > root .env > defaults.
func Load(directory string) (Config, error) {
	values := map[string]string{}
	for _, path := range []string{filepath.Join(directory, "..", ".env"), filepath.Join(directory, ".env")} {
		loaded, err := godotenv.Read(path)
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			return Config{}, err
		}
		for key, value := range loaded {
			values[key] = value
		}
	}
	get := func(key, fallback string) string {
		if value, exists := os.LookupEnv(key); exists {
			return value
		}
		if value, exists := values[key]; exists {
			return value
		}
		return fallback
	}
	cfg := Config{Address: get("GATEWAY_ADDR",""), MLURL: strings.TrimRight(get("ML_SERVICE_URL", "http://127.0.0.1:8000"), "/"), HistoryPath: get("HISTORY_PATH", "data/history.json")}
	parsed, err := url.Parse(cfg.MLURL)
	if err != nil || parsed.Host == "" || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.RawQuery != "" || parsed.Fragment != "" || parsed.User != nil || parsed.Path != "" {
		return Config{}, fmt.Errorf("ML_SERVICE_URL must be an HTTP(S) origin")
	}
	_, portText, err := net.SplitHostPort(cfg.Address)
	port, portErr := strconv.Atoi(portText)
	if err != nil || portErr != nil || port < 1 || port > 65535 {
		return Config{}, fmt.Errorf("GATEWAY_ADDR must contain a host and valid port")
	}
	seconds, err := strconv.Atoi(get("UPSTREAM_TIMEOUT_SECONDS", "15"))
	if err != nil || seconds < 1 || seconds > 120 {
		return Config{}, fmt.Errorf("UPSTREAM_TIMEOUT_SECONDS must be between 1 and 120")
	}
	cfg.UpstreamTimeout = time.Duration(seconds) * time.Second
	if cfg.HistoryPath == "" {
		return Config{}, fmt.Errorf("HISTORY_PATH must not be empty")
	}
	if !filepath.IsAbs(cfg.HistoryPath) {
		cfg.HistoryPath = filepath.Join(directory, cfg.HistoryPath)
	}
	return cfg, nil
}
