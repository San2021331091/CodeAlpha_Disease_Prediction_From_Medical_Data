package routes

import (
	"codealpha/cellscope/gateway/internal/controllers"
	"github.com/gin-gonic/gin"
)

func New(g *controllers.Gateway) *gin.Engine {
	r := gin.New()
	r.Use(gin.Recovery())
	r.SetTrustedProxies(nil)
	r.GET("/health", g.Proxy("/health"))
	api := r.Group("/api")
	api.GET("/diseases", g.Proxy("/api/diseases"))
	api.GET("/schema", g.Proxy("/api/schema"))
	api.GET("/metrics", g.Proxy("/api/metrics"))
	api.GET("/samples", g.Proxy("/api/samples"))
	api.POST("/predict", g.Predict)
	api.GET("/history", g.History)
	api.DELETE("/history", g.ClearHistory)
	return r
}
