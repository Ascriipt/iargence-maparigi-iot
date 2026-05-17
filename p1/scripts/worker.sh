#!/bin/bash

set -e

WORKER_IP="192.168.56.111"
FLANNEL_IFACE=$(ip -o addr show to "${WORKER_IP}/32" | awk '{print $2; exit}')

if [ -z "$FLANNEL_IFACE" ]; then
  echo "Unable to find network interface for ${WORKER_IP}" >&2
  exit 1
fi

apt-get update -y

while [ ! -f /vagrant_shared/token ]; do
  sleep 2
done

TOKEN=$(cat /vagrant_shared/token)

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 \
  K3S_TOKEN=$TOKEN \
  INSTALL_K3S_EXEC="--node-ip=${WORKER_IP} --flannel-iface=${FLANNEL_IFACE}" \
  sh -
