# Inception-of-Things: Bonus

This folder implements the bonus part of **Inception-of-Things**.

The subject asks for a local GitLab instance added to the Part 3 lab. Everything from Part 3 must still work, but the GitOps repository must live in the local GitLab instead of GitHub.

## Subject Requirements Covered

The PDF asks the bonus to provide:

- a local GitLab instance;
- GitLab configured to work with the cluster;
- a namespace named `gitlab`;
- the Part 3 Argo CD flow working with local GitLab;
- all bonus files inside a `bonus` folder at the repository root.

This implementation uses:

- K3d for the Kubernetes cluster;
- the official GitLab Helm chart;
- a `gitlab` namespace for GitLab;
- an `argocd` namespace for Argo CD;
- a `dev` namespace for the application;
- Wil's `wil42/playground` app, starting at `v1`;
- Argo CD syncing the app from the local GitLab repository.

## Evaluation Checklist

Evaluate this part only after p1, p2, and p3 pass perfectly, as required by the correction PDF.

| Correction check | Answer in this repo |
| --- | --- |
| Bonus configuration files are present | `scripts/`, `confs/gitlab/values.yaml`, `confs/argocd/application.yaml.tpl`, and `confs/app/deployment.yaml`. |
| GitLab works locally | `./scripts/setup.sh` installs GitLab with the official Helm chart in the `gitlab` namespace. |
| A GitLab repository can be created and used | Setup creates `root/iot-gitops` and pushes the v1 app manifests to it. |
| Part 3 flow still works | Argo CD still runs in `argocd`, the app still runs in `dev`, and the app still updates from v1 to v2. |
| Argo CD uses local GitLab, not GitHub | The Application repo URL points to `gitlab-webservice-default.gitlab.svc.cluster.local`. |
| Version change succeeds | `./scripts/update_app_to_v2.sh` commits and pushes the v2 manifest to local GitLab. |

Exact commands:

```sh
./scripts/install_tools.sh
./scripts/setup.sh
kubectl get ns
kubectl get pods -n gitlab
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get pods -n dev
kubectl get ingress -n dev
curl -H 'Host: playground.127.0.0.1.nip.io' http://localhost:8080/
```

GitLab proof:

```text
http://gitlab.127.0.0.1.nip.io:8080
username: root
password: RootPassword42!
repository: root/iot-gitops
```

Version change proof:

```sh
./scripts/update_app_to_v2.sh
kubectl -n dev rollout status deployment/playground
curl -H 'Host: playground.127.0.0.1.nip.io' http://localhost:8080/
```

Expected app outputs:

```json
{"status":"ok", "message": "v1"}
{"status":"ok", "message": "v2"}
```

## Files

- `scripts/install_tools.sh`: installs Docker, K3d, kubectl, Helm, Git, curl, and jq.
- `scripts/setup.sh`: creates the K3d cluster, installs GitLab, creates a local GitLab project, pushes the app manifests, installs Argo CD, and creates the Argo CD Application.
- `scripts/update_app_to_v2.sh`: pushes a GitLab commit changing the app from `v1` to `v2`.
- `scripts/cleanup.sh`: deletes the bonus K3d cluster.
- `confs/gitlab/values.yaml`: Helm values for local GitLab.
- `confs/argocd/application.yaml.tpl`: Argo CD Application template.
- `confs/app/deployment.yaml`: initial app manifests pushed to local GitLab.

## Configuration Files Explained

### `confs/gitlab/values.yaml`

This file customizes the official GitLab Helm chart for a small local lab cluster.

- `global.edition: ce` installs GitLab Community Edition.
- `global.ingress.class: nginx` tells GitLab to use the nginx Ingress controller installed by the GitLab chart.
- `global.ingress.configureCertmanager: false` disables cert-manager integration, which is unnecessary for this local HTTP setup.
- `global.hosts.domain: 127.0.0.1.nip.io` makes GitLab create local-friendly hostnames that resolve back to localhost through `nip.io`.
- `global.hosts.https: false` disables HTTPS for the GitLab web endpoints.
- `certmanager.install: false` avoids installing cert-manager.
- `gitlab-runner.install: false` avoids installing GitLab Runner because CI jobs are not required for the subject.
- `prometheus.install: false` avoids installing Prometheus to keep the bonus cluster lighter.
- `registry.enabled: false` disables the container registry because the app image is pulled from Docker Hub.
- `nginx-ingress.enabled: true` enables the nginx Ingress controller bundled with the GitLab chart.
- `nginx-ingress.controller.service.type: LoadBalancer` exposes nginx through the K3d load balancer, which is mapped to host port `8080` by the setup script.

### `confs/argocd/application.yaml.tpl`

This is a template for the Argo CD `Application` resource. In the bonus, `scripts/setup.sh` fills it with values pointing to the local GitLab repository instead of GitHub.

- `metadata.name: __APP_NAME__` is replaced with the Argo CD application name.
- `metadata.namespace: __ARGOCD_NAMESPACE__` is replaced with the Argo CD namespace, normally `argocd`.
- `spec.project: default` uses Argo CD's default project.
- `spec.source.repoURL: __REPO_URL__` is replaced with the internal GitLab repository URL.
- `spec.source.targetRevision: __TARGET_REVISION__` is replaced with the branch or revision to track.
- `spec.source.path: __APP_PATH__` is replaced with the manifest path inside the GitLab repository.
- `spec.destination.server: https://kubernetes.default.svc` deploys into the same cluster where Argo CD is running.
- `spec.destination.namespace: __DEV_NAMESPACE__` is replaced with the application namespace, normally `dev`.
- `syncPolicy.automated.prune: true` lets Argo CD remove resources that disappear from Git.
- `syncPolicy.automated.selfHeal: true` lets Argo CD repair cluster drift from the Git version.
- `syncOptions: CreateNamespace=true` lets Argo CD create the destination namespace when needed.

### `confs/app/deployment.yaml`

This is the initial Kubernetes application configuration that `scripts/setup.sh` pushes into local GitLab.

- The `Deployment` named `playground` runs one replica of `wil42/playground:v1`.
- The container exposes port `8888`.
- The Deployment and pod template use the label `app: playground`.
- The `Service` named `playground` selects the `app: playground` pod and exposes port `8888`.
- The `Ingress` named `playground` uses `ingressClassName: nginx`, so it is handled by the nginx Ingress controller installed with GitLab.
- The Ingress host is `playground.127.0.0.1.nip.io`, which resolves to localhost and is exposed through host port `8080`.
- The Ingress routes `/` to the `playground` Service on port `8888`.

The version update demonstration changes this file in the GitLab repository from `wil42/playground:v1` to `wil42/playground:v2`. Argo CD then syncs the new image into the `dev` namespace.

## Scripts Explained

### `scripts/install_tools.sh`

This script installs the local tools needed for the bonus on an Ubuntu machine.

- `set -euo pipefail` makes the script fail on command errors, unset variables, and failed pipeline commands.
- The `SUDO` block lets the script work as root or as a normal user with `sudo`.
- `apt-get update -y` refreshes package metadata.
- `apt-get install -y ca-certificates curl git gnupg jq lsb-release docker.io` installs Docker plus the CLI tools used by the setup.
- `systemctl enable docker` and `systemctl start docker` enable and start Docker.
- The Docker group check adds the current user to the `docker` group if needed.
- The `kubectl`, `k3d`, and `helm` blocks install each tool only if it is missing.
- The final version commands print the installed Docker, K3d, kubectl, and Helm versions.

### `scripts/setup.sh`

This is the main bonus setup script. It creates the K3d cluster, installs GitLab, creates the local GitOps repository, installs Argo CD, and syncs the app from GitLab.

- The variables at the top define overridable defaults for the cluster, namespaces, GitLab host, HTTP port, root password, token, project name, app name, manifest path, and Git branch.
- The dependency loop checks for `docker`, `k3d`, `kubectl`, `helm`, `git`, `curl`, and `sed`.
- `docker info` verifies Docker is running and accessible.
- The `k3d cluster create` block creates `iot-bonus` only if it does not already exist.
- `--api-port 6552` exposes the Kubernetes API on a predictable host port.
- `-p "${GITLAB_HTTP_PORT}:80@loadbalancer"` maps the cluster HTTP load balancer to host port `8080` by default.
- `--agents 1` creates one K3d agent node.
- `--k3s-arg "--disable=traefik@server:0"` disables K3s Traefik because GitLab's chart installs nginx Ingress.
- The namespace commands create `gitlab`, `argocd`, and `dev` idempotently.
- The `gitlab-root-password` secret stores the GitLab root password for the Helm chart.
- `helm repo add` and `helm repo update` configure the official GitLab chart repository.
- `helm upgrade --install gitlab gitlab/gitlab ...` installs or updates GitLab using `confs/gitlab/values.yaml` plus runtime values.
- `wait_deployments` waits for GitLab deployments matching a label selector, and exits clearly if none are found.
- The script waits for GitLab `webservice`, `sidekiq`, and `toolbox` deployments.
- The `gitlab-rails runner` command inside the toolbox pod creates a root personal access token and a public `root/iot-gitops` project if needed.
- `mktemp -d` creates a temporary local Git repository.
- The script copies `confs/app/*.yaml` into the temporary repository under `APP_PATH`.
- The Git commands initialize the repository, create the `main` branch, commit the v1 app manifests, add the local GitLab remote, and force-push the initial state.
- Argo CD is installed into the `argocd` namespace from the official stable manifest.
- The Argo CD rollout checks wait for the server, repo server, and ApplicationSet controller.
- `internal_repo_url` points Argo CD at GitLab's in-cluster service address, so syncing does not depend on external DNS.
- The `sed` command renders `confs/argocd/application.yaml.tpl` with the local GitLab repository and namespace values.
- `kubectl apply -f "$tmp_application"` creates the Argo CD Application.
- The final rollout check waits until the synced app Deployment is available in `dev`.
- The ending `echo` lines print the GitLab URL, app URL, Argo CD port-forward command, and password command.

### `scripts/update_app_to_v2.sh`

This script performs the bonus version update demo by committing a change to the local GitLab repository.

- The variables at the top define the GitLab domain, host, port, token, project, and app manifest path.
- `mktemp -d` creates a temporary clone directory, and `trap` removes it on exit.
- `git clone` clones the local GitLab project using the root token.
- `sed -i 's|wil42/playground:v1|wil42/playground:v2|g' ...` changes the app image tag in the GitLab copy of `deployment.yaml`.
- The Git config commands set a local commit identity for the temporary clone.
- The script stages `deployment.yaml`, commits the version change, and allows the commit command to be a no-op if the file was already at v2.
- `git push origin main` pushes the change to local GitLab.
- The final message reminds that Argo CD should sync the GitLab change into the `dev` namespace.

### `scripts/cleanup.sh`

This script deletes the bonus K3d cluster.

- `CLUSTER_NAME="${CLUSTER_NAME:-iot-bonus}"` uses `iot-bonus` by default but allows overriding it.
- The cluster existence check avoids failing when there is nothing to delete.
- `k3d cluster delete "$CLUSTER_NAME"` removes the cluster when it exists.

## How It Works

The setup creates a K3d cluster named `iot-bonus`.

Traefik is disabled because the official GitLab chart installs its own nginx Ingress controller. Host port `8080` is mapped to the cluster load balancer port `80`.

GitLab is installed in the `gitlab` namespace with the official Helm chart:

```sh
helm upgrade --install gitlab gitlab/gitlab ...
```

The script creates:

- a root password secret;
- a root personal access token;
- a local GitLab project named `root/iot-gitops`;
- a first commit containing the app manifests.

Argo CD is installed in the `argocd` namespace. Its Application points to the GitLab service inside the cluster:

```text
gitlab-webservice-default.gitlab.svc.cluster.local
```

That means Argo CD syncs from local GitLab without depending on GitHub.

## How to Run

From the `bonus` directory:

```sh
./scripts/install_tools.sh
```

If the script adds your user to the `docker` group, log out and log back in.

Then run:

```sh
./scripts/setup.sh
```

GitLab is heavy. The first run can take several minutes because many containers need to start.

## URLs

GitLab:

```text
http://gitlab.127.0.0.1.nip.io:8080
```

Application:

```text
http://playground.127.0.0.1.nip.io:8080
```

You can also test the app with:

```sh
curl -H 'Host: playground.127.0.0.1.nip.io' http://localhost:8080/
```

Expected initial output:

```json
{"status":"ok", "message": "v1"}
```

## Credentials

GitLab username:

```text
root
```

Default GitLab password:

```text
RootPassword42!
```

You can override it:

```sh
GITLAB_ROOT_PASSWORD='AnotherPassword42!' ./scripts/setup.sh
```

## How to Verify

Check namespaces:

```sh
kubectl get ns
```

Expected namespaces include:

```text
gitlab
argocd
dev
```

Check GitLab:

```sh
kubectl get pods -n gitlab
```

Check Argo CD:

```sh
kubectl get pods -n argocd
kubectl get applications -n argocd
```

Check the app:

```sh
kubectl get pods -n dev
kubectl get ingress -n dev
curl -H 'Host: playground.127.0.0.1.nip.io' http://localhost:8080/
```

## Argo CD UI

Forward Argo CD:

```sh
kubectl -n argocd port-forward svc/argocd-server 8081:443
```

Open:

```text
https://localhost:8081
```

Username:

```text
admin
```

Password:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## Version Update Demo

To prove that GitLab drives the deployment, push a change to the local GitLab repository:

```sh
./scripts/update_app_to_v2.sh
```

That script changes:

```text
wil42/playground:v1
```

to:

```text
wil42/playground:v2
```

Argo CD should detect the GitLab commit and sync the app into `dev`.

Verify:

```sh
curl -H 'Host: playground.127.0.0.1.nip.io' http://localhost:8080/
```

Expected output after sync:

```json
{"status":"ok", "message": "v2"}
```

## Cleanup

Delete the cluster:

```sh
./scripts/cleanup.sh
```

## Evaluation Note

The subject says the bonus is evaluated only if all mandatory parts are flawless. This folder assumes Part 3 concepts are already working, then replaces the public GitHub dependency with a local GitLab instance running in the same lab.
