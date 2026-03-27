#!/bin/bash
set -e

cd "$(dirname "$0")/.."

IMAGE="registry.digitalocean.com/kass/maze-server"
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")

echo "Building maze-server $VERSION..."
docker build --platform linux/amd64 \
    --build-arg SERVICE_VERSION="$VERSION" \
    -t "$IMAGE:$VERSION" \
    -t "$IMAGE:latest" \
    .

echo "Pushing..."
docker push "$IMAGE:$VERSION"
docker push "$IMAGE:latest"

echo "Done. Image: $IMAGE:$VERSION"
