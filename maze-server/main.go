package main

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/1F47E/maze-server/internal/config"
	"github.com/1F47E/maze-server/internal/match"
	"github.com/1F47E/maze-server/internal/session"
	"github.com/1F47E/maze-server/internal/ws"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/websocket/v2"
	"github.com/rs/zerolog"
)

func main() {
	cfg := config.Load()

	// Logger
	level := zerolog.InfoLevel
	if cfg.Debug {
		level = zerolog.DebugLevel
	}
	log := zerolog.New(zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339}).
		With().Timestamp().Logger().Level(level)

	// Session registry
	registry := session.NewRegistry()
	registry.StartCleanup()

	// Match store
	matchStore := match.NewStore("data/matches.jsonl", log)
	log.Info().Int("matches", matchStore.Count()).Msg("match store ready")

	// WebSocket handler
	wsHandler := ws.NewHandler(registry, matchStore, log)

	// Fiber app
	app := fiber.New(fiber.Config{
		DisableStartupMessage: true,
	})

	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept",
	}))

	// Health check
	app.Get("/api/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "ok",
			"time":    time.Now().UTC().Format(time.RFC3339),
			"matches": matchStore.Count(),
		})
	})

	// Match history endpoints
	app.Get("/api/matches", func(c *fiber.Ctx) error {
		limit := 50
		if l := c.Query("limit"); l != "" {
			if n, err := strconv.Atoi(l); err == nil && n > 0 {
				limit = n
			}
		}

		playerID := c.Query("player")
		if playerID != "" {
			return c.JSON(matchStore.ListByPlayer(playerID, limit))
		}
		return c.JSON(matchStore.List(limit))
	})

	app.Get("/api/matches/:id", func(c *fiber.Ctx) error {
		id := c.Params("id")
		r := matchStore.Get(id)
		if r == nil {
			return c.Status(404).JSON(fiber.Map{"error": "match not found"})
		}
		return c.JSON(r)
	})

	// WebSocket upgrade
	app.Use("/ws", func(c *fiber.Ctx) error {
		if websocket.IsWebSocketUpgrade(c) {
			return c.Next()
		}
		return fiber.ErrUpgradeRequired
	})

	app.Get("/ws/maze", websocket.New(func(c *websocket.Conn) {
		wsHandler.HandleConnection(c)
	}))

	// Static debug page (served from embedded or file)
	app.Static("/debug", "./web")

	addr := fmt.Sprintf(":%d", cfg.Port)
	log.Info().Str("addr", addr).Msg("maze-server starting")
	if err := app.Listen(addr); err != nil {
		log.Fatal().Err(err).Msg("server failed")
	}
}
