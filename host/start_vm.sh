#!/bin/bash
set -euo pipefail

VM_NAME="iot-parent"
SSH_PORT=22222

if ! virsh -c qemu:///session dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "Erreur : La VM '${VM_NAME}' n'est pas définie dans libvirt."
  echo "Pour la créer de zéro, exécutez :"
  echo "  ./host/setup_parent_vm.sh"
  exit 1
fi

STATE=$(virsh -c qemu:///session dominfo "$VM_NAME" | awk '/State:/ {print $2}')

if [ "$STATE" = "running" ]; then
  echo "La VM '${VM_NAME}' est déjà allumée."
else
  echo "Démarrage de la VM '${VM_NAME}'..."
  virsh -c qemu:///session start "$VM_NAME"
fi

echo "Attente de la disponibilité de la VM sur le port SSH ${SSH_PORT}..."
for i in $(seq 1 30); do
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" vagrant@127.0.0.1 "true" 2>/dev/null; then
    echo "✓ La VM est prête et accessible !"
    echo "Pour vous connecter : ./host/enter_vm.sh"
    exit 0
  fi
  sleep 1
done

echo "Attention : La VM a démarré mais le port SSH met du temps à répondre. Réessayez : ./host/enter_vm.sh"
