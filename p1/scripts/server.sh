#!/bin/bash

set -e

SERVER_IP="192.168.56.110"
FLANNEL_IFACE=$(ip -o addr show to "${SERVER_IP}/32" | awk '{print $2; exit}')

if [ -z "$FLANNEL_IFACE" ]; then
  echo "Unable to find network interface for ${SERVER_IP}" >&2
  exit 1
fi

apt-get update -y

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--bind-address=${SERVER_IP} \
  --advertise-address=${SERVER_IP} \
  --node-ip=${SERVER_IP} \
  --write-kubeconfig-mode=644 \
  --disable-cloud-controller \
  --flannel-iface=${FLANNEL_IFACE}" sh -

while [ ! -f /var/lib/rancher/k3s/server/node-token ] || [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  sleep 2
done

until kubectl get --raw=/readyz >/dev/null 2>&1; do
  sleep 2
done

cp /var/lib/rancher/k3s/server/node-token /vagrant_shared/token

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
