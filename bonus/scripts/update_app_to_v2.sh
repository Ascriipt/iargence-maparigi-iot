#!/bin/bash
set -euo pipefail

GITLAB_DOMAIN="${GITLAB_DOMAIN:-127.0.0.1.nip.io}"
GITLAB_HOST="${GITLAB_HOST:-gitlab.${GITLAB_DOMAIN}}"
GITLAB_HTTP_PORT="${GITLAB_HTTP_PORT:-8080}"
GITLAB_TOKEN="${GITLAB_TOKEN:-iot-local-token-42}"
GITLAB_PROJECT="${GITLAB_PROJECT:-iot-gitops}"
APP_PATH="${APP_PATH:-confs/app}"

tmp_repo="$(mktemp -d)"
trap 'rm -rf "$tmp_repo"' EXIT

git clone "http://root:${GITLAB_TOKEN}@${GITLAB_HOST}:${GITLAB_HTTP_PORT}/root/${GITLAB_PROJECT}.git" "$tmp_repo"
sed -i 's|wil42/playground:v1|wil42/playground:v2|g' "$tmp_repo/$APP_PATH/deployment.yaml"
git -C "$tmp_repo" config user.email "iot@example.local"
git -C "$tmp_repo" config user.name "IoT Bonus"
git -C "$tmp_repo" add "$APP_PATH/deployment.yaml"
git -C "$tmp_repo" commit -m "Update playground to v2" || true
git -C "$tmp_repo" push origin main

echo "Pushed v2 to local GitLab. Argo CD should sync the change into the dev namespace."
