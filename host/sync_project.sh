#!/bin/bash
set -euo pipefail

SSH_PORT=22222
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)/"

echo "Syncing ${SRC_DIR} to vagrant@127.0.0.1:~/IOT/ ..."
rsync -avz --delete \
  -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p ${SSH_PORT}" \
  --exclude=".vagrant" \
  --exclude="*.log" \
  --exclude="p1/shared/token" \
  "${SRC_DIR}" vagrant@127.0.0.1:~/IOT/

echo "Project synced successfully."
