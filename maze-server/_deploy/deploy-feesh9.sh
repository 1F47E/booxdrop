#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Deploying to feesh9..."
ssh feesh9 'mkdir -p ~/apps/maze-server'
scp feesh9/docker-compose.yml feesh9:~/apps/maze-server/docker-compose.yml
scp feesh9/update.sh feesh9:~/apps/maze-server/update.sh
ssh feesh9 'chmod +x ~/apps/maze-server/update.sh'
ssh feesh9 'cd ~/apps/maze-server && bash update.sh'

echo "Deploy complete."
