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
GITLAB_CHART_VERSION="${GITLAB_CHART_VERSION:-8.11.8}"
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
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--disable-cloud-controller@server:*"
fi

# Ensure Bitnami and MinIO images exist locally and are imported into k3d
docker pull bitnamilegacy/postgresql:14.8.0 >/dev/null 2>&1 || true
docker pull bitnamilegacy/redis:7.2.4-debian-12-r9 >/dev/null 2>&1 || true
docker pull bitnamilegacy/minio:latest >/dev/null 2>&1 || true
docker pull bitnamilegacy/minio-client:latest >/dev/null 2>&1 || true

docker tag bitnamilegacy/postgresql:14.8.0 bitnami/postgresql:14.8.0 2>/dev/null || true
docker tag bitnamilegacy/redis:7.2.4-debian-12-r9 bitnami/redis:7.2.4-debian-12-r9 2>/dev/null || true

printf 'FROM bitnamilegacy/minio:latest\nENTRYPOINT ["/opt/bitnami/minio/bin/minio"]\n' | docker build -t minio/minio:RELEASE.2017-12-28T01-21-00Z - >/dev/null 2>&1 || true

cat << 'EOF' > /tmp/mc_wrapper.sh
#!/bin/sh
if [ "$1" = "config" ] && [ "$2" = "host" ] && [ "$3" = "add" ]; then
    shift 3
    exec /opt/bitnami/minio-client/bin/mc alias set "$@"
elif [ "$1" = "policy" ]; then
    shift 1
    policy="$1"
    target="$2"
    if [ "$policy" = "none" ]; then
        exit 0
    fi
    exec /opt/bitnami/minio-client/bin/mc anonymous set "$policy" "$target"
fi
exec /opt/bitnami/minio-client/bin/mc "$@"
EOF
chmod +x /tmp/mc_wrapper.sh
rm -rf /tmp/mc_build && mkdir -p /tmp/mc_build && cp /tmp/mc_wrapper.sh /tmp/mc_build/mc
printf 'FROM bitnamilegacy/minio-client:latest\nUSER 0\nCOPY mc /usr/bin/mc\nRUN chmod 755 /usr/bin/mc\nUSER 1001\nENTRYPOINT ["/usr/bin/mc"]\n' > /tmp/mc_build/Dockerfile
docker build -t minio/mc:RELEASE.2018-07-13T00-53-22Z /tmp/mc_build >/dev/null 2>&1 || true

k3d image import \
  bitnami/postgresql:14.8.0 \
  bitnami/redis:7.2.4-debian-12-r9 \
  minio/minio:RELEASE.2017-12-28T01-21-00Z \
  minio/mc:RELEASE.2018-07-13T00-53-22Z \
  -c "$CLUSTER_NAME" >/dev/null 2>&1 || true

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
  --version "$GITLAB_CHART_VERSION" \
  --namespace "$GITLAB_NAMESPACE" \
  --timeout 20m \
  --values confs/gitlab/values.yaml \
  --set global.hosts.domain="$GITLAB_DOMAIN" \
  --set global.hosts.https=false \
  --set global.ingress.tls.enabled=false \
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

kubectl -n "$GITLAB_NAMESPACE" exec "$toolbox_pod" -- bash -c '
  if ! gitlab-rails runner "exit(User.find_by_username(\"root\") ? 0 : 1)" >/dev/null 2>&1; then
    env -u GITLAB_ROOT_PASSWORD gitlab-rake db:seed_fu
  fi
'

kubectl -n "$GITLAB_NAMESPACE" exec "$toolbox_pod" -- env IOT_TOKEN="$GITLAB_TOKEN" IOT_PROJECT="$GITLAB_PROJECT" GITLAB_ROOT_PASSWORD="$GITLAB_ROOT_PASSWORD" gitlab-rails runner '
user = User.find_by_username("root")
raise "root user not found" unless user

user.password = ENV.fetch("GITLAB_ROOT_PASSWORD", "RootPassword42!")
user.password_confirmation = ENV.fetch("GITLAB_ROOT_PASSWORD", "RootPassword42!")
user.save(validate: false)

token = user.personal_access_tokens.find_by(name: "iot-local-token")
token&.destroy
token = user.personal_access_tokens.create!(
  name: "iot-local-token",
  scopes: [:api, :read_repository, :write_repository],
  expires_at: 1.year.from_now
)
token.set_token(ENV.fetch("IOT_TOKEN"))
token.save!

ApplicationSetting.current.update!(default_branch_protection: 0) rescue nil
path = "root/#{ENV.fetch("IOT_PROJECT")}"
project = Project.find_by_full_path(path)
unless project
  result = Projects::CreateService.new(user, {
    name: ENV.fetch("IOT_PROJECT"),
    path: ENV.fetch("IOT_PROJECT"),
    namespace_id: user.namespace.id,
    visibility_level: Gitlab::VisibilityLevel::PUBLIC
  }).execute
  raise result[:message].to_s unless result[:status] == :success
  project = result[:project]
end
branch = project.protected_branches.find_by(name: "main") || project.protected_branches.new(name: "main")
branch.allow_force_push = true
branch.save!
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
