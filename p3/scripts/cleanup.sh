#!/bin/bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-p3}"

if k3d cluster list "$CLUSTER_NAME" >/dev/null 2>&1; then
  k3d cluster delete "$CLUSTER_NAME"
else
  echo "Cluster $CLUSTER_NAME does not exist."
fi
