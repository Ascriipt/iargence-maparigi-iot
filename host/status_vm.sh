#!/bin/bash
VM_NAME="iot-parent"
SSH_PORT=22222

if ! virsh -c qemu:///session dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "État de la VM '${VM_NAME}' : NON DÉFINIE (Disque ou domaine absent)"
  echo "Pour la créer : ./host/setup_parent_vm.sh"
  exit 1
fi

virsh -c qemu:///session dominfo "$VM_NAME"
echo ""
if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 -p "$SSH_PORT" vagrant@127.0.0.1 "true" 2>/dev/null; then
  echo "✓ SSH (port ${SSH_PORT}) : ACCESSIBLE (prêt pour ./host/enter_vm.sh)"
else
  echo "✗ SSH (port ${SSH_PORT}) : INACCESSIBLE"
fi
