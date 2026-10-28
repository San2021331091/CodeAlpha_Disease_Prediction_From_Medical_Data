package services

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
)

type MLClient struct {
	URL  string
	HTTP *http.Client
}

func (m *MLClient) Forward(ctx context.Context, method, path string, payload []byte) (int, []byte, error) {
	req, err := http.NewRequestWithContext(ctx, method, m.URL+path, bytes.NewReader(payload))
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := m.HTTP.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer res.Body.Close()
	const maxResponse = 2 << 20
	data, err := io.ReadAll(io.LimitReader(res.Body, maxResponse+1))
	if err != nil {
		return 0, nil, err
	}
	if len(data) > maxResponse || !json.Valid(data) {
		return 0, nil, errors.New("invalid ML response")
	}
	return res.StatusCode, data, nil
}
