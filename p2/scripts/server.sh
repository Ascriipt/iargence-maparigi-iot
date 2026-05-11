#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y curl

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--bind-address=192.168.56.110 \
  --advertise-address=192.168.56.110 \
  --node-ip=192.168.56.110 \
  --flannel-iface=eth1" sh -

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

until kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl apply -f /vagrant/confs/apps.yaml
kubectl -n kube-system rollout status deployment/traefik --timeout=180s || true
kubectl rollout status deployment/app1 --timeout=180s
kubectl rollout status deployment/app2 --timeout=180s
kubectl rollout status deployment/app3 --timeout=180s
