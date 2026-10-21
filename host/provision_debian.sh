#!/bin/bash
set -euo pipefail

echo "=== [1/4] Installing system dependencies, KVM, Libvirt & Vagrant ==="
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  vagrant \
  vagrant-libvirt \
  docker.io \
  curl \
  git \
  make \
  jq \
  rsync

echo "=== [2/4] Setting up permissions and services ==="
sudo usermod -aG libvirt,kvm,docker "$USER"
if ! grep -q '^user = "root"' /etc/libvirt/qemu.conf 2>/dev/null; then
  echo -e 'user = "root"\ngroup = "root"' | sudo tee -a /etc/libvirt/qemu.conf
fi
sudo systemctl enable --now libvirtd || true
sudo systemctl restart libvirtd || true
sudo systemctl enable --now docker || true
sudo virsh net-autostart default 2>/dev/null || true
sudo virsh net-start default 2>/dev/null || true

echo "=== [3/4] Installing Kubernetes tools (kubectl, k3d, helm) ==="
if ! command -v kubectl >/dev/null 2>&1; then
  curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
fi

if ! command -v k3d >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "=== [4/4] Verifying nested virtualization & environment ==="
if [ -e /dev/kvm ]; then
  echo "SUCCESS: /dev/kvm is available! Hardware-accelerated nested virtualization is active."
else
  echo "WARNING: /dev/kvm not found! Nested virtualization may be slow."
fi

echo
echo "Installed versions:"
vagrant --version
docker --version
kubectl version --client
k3d version
helm version

echo
echo "=========================================================="
echo " Parent VM is fully provisioned!"
echo " IMPORTANT: Log out and log back into SSH (or run 'newgrp libvirt && newgrp docker') to apply group permissions."
echo "=========================================================="
