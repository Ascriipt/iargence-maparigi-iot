#!/bin/bash

apt-get update -y

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--bind-address=192.168.56.110 \
  --advertise-address=192.168.56.110 \
  --node-ip=192.168.56.110 \
  --flannel-iface=eth1" sh -

sleep 10

cp /var/lib/rancher/k3s/server/node-token /vagrant_shared/token

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config
