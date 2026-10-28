package controllers

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"codealpha/cellscope/gateway/internal/models"
	"codealpha/cellscope/gateway/internal/services"
	"codealpha/cellscope/gateway/internal/views"
	"github.com/gin-gonic/gin"
)

type Gateway struct {
	ML    *services.MLClient
	Store *models.Store
}

func (g *Gateway) Proxy(path string) gin.HandlerFunc {
	return func(c *gin.Context) {
		upstreamPath := path
		if disease := c.Query("disease"); disease != "" {
			if disease != "breast_cancer" && disease != "heart_disease" && disease != "diabetes" { views.Error(c, 400, "Unknown disease."); return }
			upstreamPath += "?disease=" + url.QueryEscape(disease)
		}
		status, data, err := g.ML.Forward(c.Request.Context(), http.MethodGet, upstreamPath, nil)
		if err != nil {
			views.Error(c, 502, "ML service unavailable. Check that FastAPI is running.")
			return
		}
		views.Upstream(c, status, data)
	}
}

func (g *Gateway) Predict(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 64<<10)
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		views.Error(c, 413, "Prediction request exceeds 64 KB.")
		return
	}
	if !json.Valid(payload) {
		views.Error(c, 400, "Request must be valid JSON.")
		return
	}
	status, data, err := g.ML.Forward(c.Request.Context(), http.MethodPost, "/api/predict", payload)
	if err != nil {
		views.Error(c, 502, "ML service unavailable. Check that FastAPI is running.")
		return
	}
	if status != 200 {
		views.Upstream(c, status, data)
		return
	}
	var result models.PredictionSummary
	if json.Unmarshal(data, &result) != nil || !result.Valid() {
		views.Error(c, 502, "ML service returned an invalid prediction.")
		return
	}
	record, err := g.Store.Add(json.RawMessage(data))
	if err != nil {
		views.Error(c, 500, "Prediction could not be saved. Check history storage.")
		return
	}
	views.JSON(c, 200, record)
}

func (g *Gateway) History(c *gin.Context) {
	limit, err := strconv.Atoi(c.DefaultQuery("limit", "50"))
	if err != nil || limit < 1 || limit > 200 {
		views.Error(c, 400, "limit must be between 1 and 200")
		return
	}
	records, total := g.Store.List(limit)
	views.JSON(c, 200, gin.H{"records": records, "total": total})
}

func (g *Gateway) ClearHistory(c *gin.Context) {
	if err := g.Store.Clear(); err != nil {
		views.Error(c, 500, "Could not clear history.")
		return
	}
	views.JSON(c, 200, gin.H{"deleted": true})
}
