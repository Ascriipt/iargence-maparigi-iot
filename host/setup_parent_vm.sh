#!/bin/bash
set -euo pipefail

# Configuration
VM_NAME="iot-parent"
RAM_MB=8192
VCPUS=4
SSH_PORT=22222
APP_PORT=8888
ARGO_PORT=8080

BASE_DIR="/goinfre/${USER}/iot_parent_vm"
IMAGE_NAME="debian-12-genericcloud-amd64.qcow2"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
DISK_IMAGE="${BASE_DIR}/disk.qcow2"
BASE_IMAGE="${BASE_DIR}/${IMAGE_NAME}"

echo "=== [1/4] Checking host requirements ==="
for cmd in virt-install virsh qemu-img virt-customize curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command on host: $cmd" >&2
    exit 1
  fi
done

mkdir -p "$BASE_DIR"

echo "=== [2/4] Preparing Debian 12 base image ==="
if [ ! -f "$BASE_IMAGE" ]; then
  echo "Downloading Debian 12 cloud image to ${BASE_IMAGE}..."
  curl -L --progress-bar -o "$BASE_IMAGE" "$IMAGE_URL"
else
  echo "Using existing base image: ${BASE_IMAGE}"
fi

# Clean previous VM if exists
if virsh -c qemu:///session dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "Stopping and cleaning existing VM: ${VM_NAME}..."
  virsh -c qemu:///session destroy "$VM_NAME" >/dev/null 2>&1 || true
  virsh -c qemu:///session undefine "$VM_NAME" >/dev/null 2>&1 || true
fi

rm -f "$DISK_IMAGE"

# Create a 40GB thin copy-on-write disk backed by base image
qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$DISK_IMAGE" 40G

echo "=== [3/4] Configuring disk with virt-customize ==="
SSH_PUB_ARG=()
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
  SSH_PUB_ARG=(--ssh-inject "vagrant:file:$HOME/.ssh/id_ed25519.pub")
elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
  SSH_PUB_ARG=(--ssh-inject "vagrant:file:$HOME/.ssh/id_rsa.pub")
fi

virt-customize -a "$DISK_IMAGE" \
  --root-password password:vagrant \
  --run-command 'useradd -m -s /bin/bash -G sudo vagrant || true' \
  --password vagrant:password:vagrant \
  --run-command 'echo "vagrant ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vagrant && chmod 0440 /etc/sudoers.d/vagrant' \
  --hostname "$VM_NAME" \
  "${SSH_PUB_ARG[@]}" \
  --run-command 'ssh-keygen -A' \
  --run-command 'sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config' \
  --run-command 'systemctl enable ssh' \
  --run-command 'printf "[Match]\nName=en*\n\n[Network]\nDHCP=yes\nDNS=1.1.1.1 8.8.8.8\n" > /etc/systemd/network/20-wired.network && systemctl enable systemd-networkd' \
  --install rsync

echo "=== [4/4] Launching Parent VM with virt-install ==="
virt-install --connect qemu:///session \
  --name "$VM_NAME" \
  --osinfo debian12 \
  --memory "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --disk path="$DISK_IMAGE",format=qcow2,bus=virtio \
  --network type=user,backend.type=passt,model=virtio,portForward0.proto=tcp,portForward0.range0.start=${SSH_PORT},portForward0.range0.to=22,portForward1.proto=tcp,portForward1.range0.start=${APP_PORT},portForward1.range0.to=8888,portForward2.proto=tcp,portForward2.range0.start=${ARGO_PORT},portForward2.range0.to=8080 \
  --graphics none \
  --import \
  --noautoconsole

echo "Waiting for SSH to become ready on port ${SSH_PORT}..."
for i in $(seq 1 30); do
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" vagrant@127.0.0.1 "true" 2>/dev/null; then
    echo "SSH connection established successfully!"
    break
  fi
  sleep 2
done

echo
echo "=========================================================="
echo " Parent VM '${VM_NAME}' is ready!"
echo " - SSH command:      ./host/enter_vm.sh"
echo " - Direct SSH:       ssh -p ${SSH_PORT} vagrant@127.0.0.1"
echo " - Default password: vagrant"
echo " - Port forward app: http://localhost:${APP_PORT}"
echo " - Port forward Argo:http://localhost:${ARGO_PORT}"
echo "=========================================================="
echo "Next step: Run ./host/sync_project.sh then ./host/enter_vm.sh"
