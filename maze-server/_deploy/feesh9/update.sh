#!/bin/bash
set -e

IMAGE="registry.digitalocean.com/kass/maze-server:latest"

echo "Pulling latest image..."
docker pull "$IMAGE"

RUNNING=$(docker compose ps -q app 2>/dev/null || true)
if [ -n "$RUNNING" ]; then
    CURRENT=$(docker inspect --format='{{.Image}}' "$RUNNING" 2>/dev/null || true)
    LATEST=$(docker inspect --format='{{.Id}}' "$IMAGE" 2>/dev/null || true)
    if [ "$CURRENT" = "$LATEST" ]; then
        echo "Already up to date."
        exit 0
    fi
fi

echo "Updating..."
docker compose down
docker compose up -d

echo "Done. Maze server running on port 8085."
