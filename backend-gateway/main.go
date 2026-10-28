package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"codealpha/cellscope/gateway/internal/config"
	"codealpha/cellscope/gateway/internal/controllers"
	"codealpha/cellscope/gateway/internal/models"
	"codealpha/cellscope/gateway/internal/routes"
	"codealpha/cellscope/gateway/internal/services"
	"github.com/gin-gonic/gin"
)

func main() {
	directory, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	cfg, err := config.Load(directory)
	if err != nil {
		log.Fatal(err)
	}
	store, err := models.OpenStore(cfg.HistoryPath)
	if err != nil {
		log.Fatal(err)
	}
	gin.SetMode(gin.ReleaseMode)
	controller := &controllers.Gateway{ML: &services.MLClient{URL: cfg.MLURL, HTTP: &http.Client{Timeout: cfg.UpstreamTimeout}}, Store: store}
	server := &http.Server{Addr: cfg.Address, Handler: routes.New(controller), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 20 * time.Second, WriteTimeout: cfg.UpstreamTimeout + 10*time.Second, IdleTimeout: 60 * time.Second}
	go func() {
		log.Printf("CellScope Gin gateway listening on %s", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Print(err)
	}
}
