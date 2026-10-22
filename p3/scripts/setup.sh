#!/bin/bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-p3}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
DEV_NAMESPACE="${DEV_NAMESPACE:-dev}"
APP_NAME="${APP_NAME:-playground}"
APP_PATH="${APP_PATH:-p3/confs/app}"
TARGET_REVISION="${TARGET_REVISION:-HEAD}"

if [ -z "${GIT_REPO_URL:-}" ]; then
  echo "GIT_REPO_URL is required."
  echo "Example:"
  echo "  GIT_REPO_URL=https://github.com/Ascriipt/iargence-maparigi-iot.git ./scripts/setup.sh"
  exit 1
fi

for bin in docker k3d kubectl curl sed; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing required command: $bin" >&2
    echo "Run ./scripts/install_tools.sh first, then retry." >&2
    exit 1
  fi
done

docker info >/dev/null

wait_for_deployment() {
  namespace="$1"
  deployment="$2"
  timeout="$3"

  end=$((SECONDS + timeout))
  until kubectl -n "$namespace" get deployment "$deployment" >/dev/null 2>&1; do
    if [ "$SECONDS" -ge "$end" ]; then
      echo "Timed out waiting for deployment/${deployment} in namespace ${namespace}" >&2
      kubectl -n "$ARGOCD_NAMESPACE" get application "$APP_NAME" -o wide >&2 || true
      kubectl -n "$ARGOCD_NAMESPACE" describe application "$APP_NAME" >&2 || true
      exit 1
    fi
    sleep 2
  done
}

if ! k3d cluster list "$CLUSTER_NAME" >/dev/null 2>&1; then
  k3d cluster create "$CLUSTER_NAME" \
    --api-port 6550 \
    -p "8888:80@loadbalancer" \
    --agents 1 \
    --k3s-arg "--disable-cloud-controller@server:*"
fi

kubectl config use-context "k3d-${CLUSTER_NAME}"

kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$DEV_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply --server-side --force-conflicts -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-server --timeout=300s
kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-repo-server --timeout=300s
kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-applicationset-controller --timeout=300s

tmp_application="$(mktemp)"
trap 'rm -f "$tmp_application"' EXIT

escape_sed() {
  printf '%s' "$1" | sed 's/[&|]/\\&/g'
}

sed \
  -e "s|__APP_NAME__|$(escape_sed "$APP_NAME")|g" \
  -e "s|__ARGOCD_NAMESPACE__|$(escape_sed "$ARGOCD_NAMESPACE")|g" \
  -e "s|__REPO_URL__|$(escape_sed "$GIT_REPO_URL")|g" \
  -e "s|__TARGET_REVISION__|$(escape_sed "$TARGET_REVISION")|g" \
  -e "s|__APP_PATH__|$(escape_sed "$APP_PATH")|g" \
  -e "s|__DEV_NAMESPACE__|$(escape_sed "$DEV_NAMESPACE")|g" \
  confs/argocd/application.yaml.tpl > "$tmp_application"

kubectl apply -f "$tmp_application"
wait_for_deployment "$DEV_NAMESPACE" "$APP_NAME" 300
kubectl -n "$DEV_NAMESPACE" rollout status deployment/"$APP_NAME" --timeout=300s

echo
echo "Part 3 is ready."
echo "Argo CD namespace: $ARGOCD_NAMESPACE"
echo "Application namespace: $DEV_NAMESPACE"
echo "Application URL: http://localhost:8888/"
echo
echo "Check the app:"
echo "  curl http://localhost:8888/"
echo
echo "Open Argo CD UI:"
echo "  kubectl -n $ARGOCD_NAMESPACE port-forward svc/argocd-server 8080:443"
echo
echo "Initial admin password:"
echo "  kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
