package config

import (
	"os"
	"strconv"
)

// Config holds server configuration.
type Config struct {
	Port  int
	Debug bool
}

// Load reads configuration from environment variables.
func Load() Config {
	port := 8085
	if p := os.Getenv("PORT"); p != "" {
		if n, err := strconv.Atoi(p); err == nil {
			port = n
		}
	}

	debug := os.Getenv("DEBUG") == "1"

	return Config{
		Port:  port,
		Debug: debug,
	}
}
