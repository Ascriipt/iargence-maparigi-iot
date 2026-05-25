#!/bin/bash
set -euo pipefail

SERVER_IP="192.168.56.110"
FLANNEL_IFACE=$(ip -o addr show to "${SERVER_IP}/32" | awk '{print $2; exit}')

if [ -z "$FLANNEL_IFACE" ]; then
  echo "Unable to find network interface for ${SERVER_IP}" >&2
  exit 1
fi

apt-get update -y
apt-get install -y curl

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--bind-address=${SERVER_IP} \
  --advertise-address=${SERVER_IP} \
  --node-ip=${SERVER_IP} \
  --write-kubeconfig-mode=644 \
  --flannel-iface=${FLANNEL_IFACE}" sh -

while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  sleep 2
done

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

until kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

wait_for_deployment() {
  namespace="$1"
  deployment="$2"
  timeout="$3"

  end=$((SECONDS + timeout))
  until kubectl -n "$namespace" get deployment "$deployment" >/dev/null 2>&1; do
    if [ "$SECONDS" -ge "$end" ]; then
      echo "Timed out waiting for deployment/${deployment} in namespace ${namespace}" >&2
      exit 1
    fi
    sleep 2
  done
}

kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl apply -f /vagrant/confs/apps.yaml
wait_for_deployment kube-system traefik 180
kubectl -n kube-system rollout status deployment/traefik --timeout=180s
kubectl rollout status deployment/app1 --timeout=180s
kubectl rollout status deployment/app2 --timeout=180s
kubectl rollout status deployment/app3 --timeout=180s
