#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

$SUDO apt-get update -y
$SUDO apt-get install -y ca-certificates curl git gnupg jq lsb-release docker.io

$SUDO systemctl enable docker
$SUDO systemctl start docker

if ! groups "$USER" | grep -q '\bdocker\b'; then
  $SUDO usermod -aG docker "$USER"
  echo "The current user was added to the docker group."
  echo "Log out and log back in before running the bonus setup without sudo."
fi

if ! command -v kubectl >/dev/null 2>&1; then
  curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  $SUDO install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
fi

if ! command -v k3d >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

docker --version
k3d version
kubectl version --client
helm version
