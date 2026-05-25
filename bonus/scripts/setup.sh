#!/bin/bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-bonus}"
GITLAB_NAMESPACE="${GITLAB_NAMESPACE:-gitlab}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
DEV_NAMESPACE="${DEV_NAMESPACE:-dev}"
GITLAB_DOMAIN="${GITLAB_DOMAIN:-127.0.0.1.nip.io}"
GITLAB_HOST="${GITLAB_HOST:-gitlab.${GITLAB_DOMAIN}}"
GITLAB_HTTP_PORT="${GITLAB_HTTP_PORT:-8080}"
GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-RootPassword42!}"
GITLAB_TOKEN="${GITLAB_TOKEN:-iot-local-token-42}"
GITLAB_PROJECT="${GITLAB_PROJECT:-iot-gitops}"
APP_NAME="${APP_NAME:-playground}"
APP_PATH="${APP_PATH:-confs/app}"
TARGET_REVISION="${TARGET_REVISION:-main}"

for bin in docker k3d kubectl helm git curl sed; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing required command: $bin" >&2
    echo "Run ./scripts/install_tools.sh first, then retry." >&2
    exit 1
  fi
done

docker info >/dev/null

wait_for_deployment() {
  local namespace="$1"
  local deployment="$2"
  local timeout="$3"
  local end

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
    --api-port 6552 \
    -p "${GITLAB_HTTP_PORT}:80@loadbalancer" \
    --agents 1 \
    --k3s-arg "--disable=traefik@server:0"
fi

kubectl config use-context "k3d-${CLUSTER_NAME}"

kubectl create namespace "$GITLAB_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$DEV_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$GITLAB_NAMESPACE" create secret generic gitlab-root-password \
  --from-literal=password="$GITLAB_ROOT_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add gitlab https://charts.gitlab.io
helm repo update

helm upgrade --install gitlab gitlab/gitlab \
  --namespace "$GITLAB_NAMESPACE" \
  --timeout 20m \
  --values confs/gitlab/values.yaml \
  --set global.hosts.domain="$GITLAB_DOMAIN" \
  --set global.hosts.https=false \
  --set global.initialRootPassword.secret=gitlab-root-password \
  --set global.initialRootPassword.key=password

wait_deployments() {
  local selector="$1"
  local deployments

  deployments="$(kubectl -n "$GITLAB_NAMESPACE" get deployments -l "$selector" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
  if [ -z "$deployments" ]; then
    echo "No deployments found for selector $selector" >&2
    exit 1
  fi

  while IFS= read -r deployment; do
    [ -n "$deployment" ] || continue
    kubectl -n "$GITLAB_NAMESPACE" rollout status deployment/"$deployment" --timeout=900s
  done <<< "$deployments"
}

wait_deployments "app=webservice"
wait_deployments "app=sidekiq"
wait_deployments "app=toolbox"

toolbox_pod="$(kubectl -n "$GITLAB_NAMESPACE" get pod -l app=toolbox -o jsonpath='{.items[0].metadata.name}')"

kubectl -n "$GITLAB_NAMESPACE" exec "$toolbox_pod" -- env IOT_TOKEN="$GITLAB_TOKEN" IOT_PROJECT="$GITLAB_PROJECT" gitlab-rails runner '
user = User.find_by_username("root")
raise "root user not found" unless user

token = user.personal_access_tokens.find_by(name: "iot-local-token")
token&.destroy
token = user.personal_access_tokens.create!(
  name: "iot-local-token",
  scopes: [:api, :read_repository, :write_repository],
  expires_at: 1.year.from_now
)
token.set_token(ENV.fetch("IOT_TOKEN"))
token.save!

path = "root/#{ENV.fetch("IOT_PROJECT")}"
unless Project.find_by_full_path(path)
  result = Projects::CreateService.new(user, {
    name: ENV.fetch("IOT_PROJECT"),
    path: ENV.fetch("IOT_PROJECT"),
    namespace_id: user.namespace.id,
    visibility_level: Gitlab::VisibilityLevel::PUBLIC
  }).execute
  raise result[:message].to_s unless result[:status] == :success
end
'

tmp_repo="$(mktemp -d)"
trap 'rm -rf "$tmp_repo"' EXIT

mkdir -p "$tmp_repo/$APP_PATH"
cp confs/app/*.yaml "$tmp_repo/$APP_PATH/"

git -C "$tmp_repo" init
git -C "$tmp_repo" config user.email "iot@example.local"
git -C "$tmp_repo" config user.name "IoT Bonus"
git -C "$tmp_repo" checkout -b main
git -C "$tmp_repo" add .
git -C "$tmp_repo" commit -m "Initial playground v1"
git -C "$tmp_repo" remote add origin "http://root:${GITLAB_TOKEN}@${GITLAB_HOST}:${GITLAB_HTTP_PORT}/root/${GITLAB_PROJECT}.git"
git -C "$tmp_repo" push -f origin main

kubectl apply --server-side --force-conflicts -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-server --timeout=300s
kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-repo-server --timeout=300s
kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-applicationset-controller --timeout=300s

tmp_application="$(mktemp)"
trap 'rm -rf "$tmp_repo" "$tmp_application"' EXIT

escape_sed() {
  printf '%s' "$1" | sed 's/[&|]/\\&/g'
}

internal_repo_url="http://root:${GITLAB_TOKEN}@gitlab-webservice-default.${GITLAB_NAMESPACE}.svc.cluster.local:8181/root/${GITLAB_PROJECT}.git"

sed \
  -e "s|__APP_NAME__|$(escape_sed "$APP_NAME")|g" \
  -e "s|__ARGOCD_NAMESPACE__|$(escape_sed "$ARGOCD_NAMESPACE")|g" \
  -e "s|__REPO_URL__|$(escape_sed "$internal_repo_url")|g" \
  -e "s|__TARGET_REVISION__|$(escape_sed "$TARGET_REVISION")|g" \
  -e "s|__APP_PATH__|$(escape_sed "$APP_PATH")|g" \
  -e "s|__DEV_NAMESPACE__|$(escape_sed "$DEV_NAMESPACE")|g" \
  confs/argocd/application.yaml.tpl > "$tmp_application"

kubectl apply -f "$tmp_application"
wait_for_deployment "$DEV_NAMESPACE" "$APP_NAME" 300
kubectl -n "$DEV_NAMESPACE" rollout status deployment/"$APP_NAME" --timeout=300s

echo
echo "Bonus environment is ready."
echo "GitLab: http://${GITLAB_HOST}:${GITLAB_HTTP_PORT}"
echo "GitLab root password: ${GITLAB_ROOT_PASSWORD}"
echo "GitLab project: http://${GITLAB_HOST}:${GITLAB_HTTP_PORT}/root/${GITLAB_PROJECT}"
echo "App URL: http://playground.${GITLAB_DOMAIN}:${GITLAB_HTTP_PORT}/"
echo
echo "Check the app:"
echo "  curl -H 'Host: playground.${GITLAB_DOMAIN}' http://localhost:${GITLAB_HTTP_PORT}/"
echo
echo "Open Argo CD UI:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8081:443"
echo
echo "Argo CD admin password:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
