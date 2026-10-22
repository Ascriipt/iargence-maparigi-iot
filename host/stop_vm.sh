#!/bin/bash
set -euo pipefail

VM_NAME="iot-parent"

if ! virsh -c qemu:///session dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "La VM '${VM_NAME}' n'existe pas."
  exit 0
fi

STATE=$(virsh -c qemu:///session dominfo "$VM_NAME" | awk '/State:/ {print $2}')

if [ "$STATE" != "running" ]; then
  echo "La VM '${VM_NAME}' est déjà éteinte (état: ${STATE})."
  exit 0
fi

if [ "${1:-}" = "-f" ] || [ "${1:-}" = "--force" ]; then
  echo "Arrêt forcé de la VM '${VM_NAME}'..."
  virsh -c qemu:///session destroy "$VM_NAME"
  echo "✓ VM arrêtée immédiatement."
  exit 0
fi

echo "Extinction propre de la VM '${VM_NAME}'..."
virsh -c qemu:///session shutdown "$VM_NAME"

for i in $(seq 1 20); do
  STATE=$(virsh -c qemu:///session dominfo "$VM_NAME" 2>/dev/null | awk '/State:/ {print $2}' || echo "shut off")
  if [ "$STATE" = "shut" ] || [ "$STATE" = "shut off" ]; then
    echo "✓ La VM est complètement éteinte."
    exit 0
  fi
  sleep 1
done

echo "Note: La VM s'éteint en arrière-plan. (Utilisez './host/stop_vm.sh -f' pour forcer l'arrêt si besoin)."
