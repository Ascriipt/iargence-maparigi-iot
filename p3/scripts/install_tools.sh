#!/bin/bash
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"

if command -v apt-get >/dev/null 2>&1; then
  if [ "$(id -u)" -eq 0 ]; then
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release docker.io
    systemctl enable docker || true
    systemctl start docker || true
  elif sudo -n true 2>/dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release docker.io
    sudo systemctl enable docker || true
    sudo systemctl start docker || true
    if ! groups "$USER" | grep -q '\bdocker\b'; then
      sudo usermod -aG docker "$USER"
    fi
  fi
fi

if ! command -v kubectl >/dev/null 2>&1; then
  curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -m 0755 /tmp/kubectl "$BIN_DIR/kubectl"
fi

if ! command -v k3d >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | USE_SUDO=false K3D_INSTALL_DIR="$BIN_DIR" bash
fi

docker --version
k3d version
kubectl version --client
