# Inception-of-Things: Part 3

This folder is the `p3` mandatory part of the **Inception-of-Things** project.

The subject asks for a K3d cluster, Argo CD, and one application deployed through GitOps. Unlike Parts 1 and 2, this part does not use Vagrant for the Kubernetes cluster. K3d runs K3s inside Docker containers.

## Subject Requirements Covered

The PDF asks Part 3 to provide:

- K3d installed on the machine;
- Docker available for K3d;
- a script that installs the required tools during defense;
- a Kubernetes cluster created with K3d;
- two namespaces:
  - `argocd` for Argo CD;
  - `dev` for the application;
- one application deployed in `dev`;
- Argo CD configured to deploy the application from a public GitHub repository;
- the application version controlled from Git;
- a demonstration where changing the manifest from `v1` to `v2` updates the running app.

This implementation uses Wil's subject-provided application:

```text
wil42/playground:v1
wil42/playground:v2
```

The application listens on port `8888`.

## Evaluation Checklist

Use this path during defense to answer the Part 3 correction questions.

| Correction check | Answer in this repo |
| --- | --- |
| Configuration files are present in `p3` | `scripts/`, `confs/argocd/application.yaml.tpl`, and `confs/app/deployment.yaml`. |
| Infrastructure can be started | Run `./scripts/install_tools.sh`, then `GIT_REPO_URL=https://github.com/Ascriipt/iargence-maparigi-iot.git ./scripts/setup.sh`. |
| K3d has at least `argocd` and `dev` namespaces | `kubectl get ns`. |
| At least one pod exists in `dev` | `kubectl get pods -n dev`. |
| Required services are running | Check `kubectl get pods -n argocd` and `kubectl get pods -n dev`. |
| Argo CD is installed and configured | `kubectl get applications -n argocd` shows the `playground` Application. |
| Argo CD UI is accessible | Port-forward `svc/argocd-server` and log in as `admin`. |
| GitHub repository contains a team login in its name | Use a public URL like `https://github.com/<login>/<login>-iot.git` for `GIT_REPO_URL`. |
| Docker image is used from DockerHub | `p3/confs/app/deployment.yaml` uses `wil42/playground:v1`. The update demo uses `wil42/playground:v2`. |
| v1 application is accessible | `curl http://localhost:8888/` returns the v1 JSON message. |
| v2 update works through Git and Argo CD | Change the image to `v2`, commit, push, sync if needed, then curl again. |

Exact commands:

```sh
kubectl get ns
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get pods -n dev
kubectl get ingress -n dev
curl http://localhost:8888/
```

Argo CD UI:

```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

Open `https://localhost:8080`, use username `admin`, and use the password from the command above.

Version change proof from the repository root:

```sh
sed -i 's|wil42/playground:v1|wil42/playground:v2|g' p3/confs/app/deployment.yaml
git add p3/confs/app/deployment.yaml
git commit -m "Update playground to v2"
git push
kubectl -n dev rollout status deployment/playground
curl http://localhost:8888/
```

Expected outputs:

```json
{"status":"ok", "message": "v1"}
{"status":"ok", "message": "v2"}
```

If Argo CD does not sync automatically during the defense, use the Argo CD UI to manually sync the `playground` Application, then rerun the rollout and curl checks.

Namespace explanation for the evaluator: a namespace is a logical Kubernetes grouping such as `argocd` or `dev`; a pod is the actual running workload created by the Deployment.

## Files

- `scripts/install_tools.sh`: installs Docker, K3d, and kubectl on an Ubuntu VM.
- `scripts/setup.sh`: creates the K3d cluster, installs Argo CD, creates namespaces, and applies the Argo CD Application.
- `scripts/cleanup.sh`: deletes the K3d cluster.
- `confs/argocd/application.yaml.tpl`: Argo CD Application template.
- `confs/app/deployment.yaml`: Kubernetes manifests for the app in the `dev` namespace.

## Configuration Files Explained

### `confs/argocd/application.yaml.tpl`

This is a template for the Argo CD `Application` resource. `scripts/setup.sh` replaces the placeholder values before applying it to the cluster.

- `apiVersion: argoproj.io/v1alpha1` and `kind: Application` define an Argo CD application object.
- `metadata.name: __APP_NAME__` is replaced with the Argo CD application name.
- `metadata.namespace: __ARGOCD_NAMESPACE__` is replaced with the namespace where Argo CD is installed, normally `argocd`.
- `spec.project: default` attaches the application to Argo CD's default project.
- `spec.source.repoURL: __REPO_URL__` is replaced with the public GitHub repository URL.
- `spec.source.targetRevision: __TARGET_REVISION__` is replaced with the Git branch or revision to track, normally `HEAD` or `main`.
- `spec.source.path: __APP_PATH__` is replaced with the manifest directory, normally `p3/confs/app`.
- `spec.destination.server: https://kubernetes.default.svc` tells Argo CD to deploy into the same cluster where Argo CD is running.
- `spec.destination.namespace: __DEV_NAMESPACE__` is replaced with the app namespace, normally `dev`.
- `syncPolicy.automated.prune: true` lets Argo CD delete cluster resources that were removed from Git.
- `syncPolicy.automated.selfHeal: true` lets Argo CD restore resources if they drift from the Git version.
- `syncOptions: CreateNamespace=true` lets Argo CD create the destination namespace if needed.

### `confs/app/deployment.yaml`

This is the Kubernetes configuration that Argo CD syncs into the `dev` namespace.

- The `Deployment` named `playground` runs one replica of `wil42/playground:v1`.
- The container exposes port `8888`, which is the port used by Wil's playground app.
- The Deployment and pod template both use the label `app: playground`.
- The `Service` named `playground` selects pods with `app: playground` and exposes port `8888` to other Kubernetes resources.
- The `Ingress` named `playground` sends HTTP requests for `/` to the `playground` Service on port `8888`.

The version update demonstration is controlled by this file. Changing the image from `wil42/playground:v1` to `wil42/playground:v2`, then committing and pushing the change, gives Argo CD a new desired state to sync.

## Scripts Explained

### `scripts/install_tools.sh`

This script installs the local tools needed for Part 3 on an Ubuntu machine.

- `set -euo pipefail` makes the script fail on errors, unset variables, and failed pipeline commands.
- The `SUDO` block lets the script run either as root or as a normal user with `sudo`.
- `apt-get update -y` refreshes package metadata.
- `apt-get install -y ca-certificates curl gnupg lsb-release docker.io` installs Docker and basic download/verification tools.
- `systemctl enable docker` and `systemctl start docker` make Docker available immediately and after reboot.
- The Docker group check adds the current user to `docker` if needed, then warns that a logout/login is required.
- The `kubectl` block downloads the latest stable Linux AMD64 client only if `kubectl` is not already installed.
- The `k3d` block installs K3d only if it is missing.
- The final version commands print the installed Docker, K3d, and kubectl versions.

### `scripts/setup.sh`

This script creates the K3d cluster, installs Argo CD, and registers the GitOps application.

- The variables at the top define overridable defaults: cluster name, namespaces, app name, manifest path, and target Git revision.
- `GIT_REPO_URL` is required because Part 3 must sync from a public GitHub repository.
- The dependency loop checks that `docker`, `k3d`, `kubectl`, `curl`, and `sed` are available.
- `docker info` verifies that Docker is running and accessible.
- The `k3d cluster create` block creates `iot-p3` only if it does not already exist.
- `--api-port 6550` exposes the Kubernetes API on a predictable host port.
- `-p "8888:80@loadbalancer"` maps host port `8888` to the cluster load balancer's HTTP port.
- `--agents 1` creates one K3d agent node.
- `kubectl config use-context "k3d-${CLUSTER_NAME}"` selects the new cluster.
- The namespace commands create `argocd` and `dev` idempotently.
- `kubectl apply ... argoproj/argo-cd/stable/...` installs Argo CD from the official manifest.
- The rollout checks wait until the main Argo CD components are ready.
- `mktemp` creates a temporary rendered Application manifest, and `trap` removes it at exit.
- `escape_sed` protects replacement values before inserting them into the template.
- The `sed` command replaces the placeholders in `confs/argocd/application.yaml.tpl`.
- `kubectl apply -f "$tmp_application"` creates the Argo CD Application.
- The final rollout check waits until the synced `playground` Deployment is available in `dev`.
- The ending `echo` lines print the app URL, Argo CD port-forward command, and admin password command.

### `scripts/cleanup.sh`

This script deletes the Part 3 K3d cluster.

- `CLUSTER_NAME="${CLUSTER_NAME:-iot-p3}"` uses `iot-p3` by default but allows overriding it.
- The `if k3d cluster list "$CLUSTER_NAME"` check detects whether the cluster exists.
- `k3d cluster delete "$CLUSTER_NAME"` removes the cluster when it exists.
- If the cluster is absent, the script prints a message instead of failing.

## Repository Requirement

Argo CD must sync from an online GitHub repository. Before evaluation, push this repository to GitHub. The subject says the public repository name must contain the login of a team member.

The setup script needs that GitHub URL:

```sh
GIT_REPO_URL=https://github.com/<login>/<repo>.git ./scripts/setup.sh
```

By default, Argo CD reads the app manifests from:

```text
p3/confs/app
```

If your GitHub repository uses a different path, override it:

```sh
GIT_REPO_URL=https://github.com/<login>/<repo>.git APP_PATH=some/other/path ./scripts/setup.sh
```

## How It Works

The setup script creates a K3d cluster named `iot-p3`.

It maps host port `8888` to the cluster load balancer port `80`:

```sh
-p "8888:80@loadbalancer"
```

That means the app can be tested from the host with:

```sh
curl http://localhost:8888/
```

Then the script installs Argo CD into the `argocd` namespace and creates the `dev` namespace.

The Argo CD Application points to the public GitHub repository and watches `p3/confs/app`. When Argo CD syncs, it applies the app Deployment, Service, and Ingress into `dev`.

## How to Run

From the `p3` directory, install the tools if needed:

```sh
./scripts/install_tools.sh
```

If the script adds your user to the `docker` group, log out and log back in before continuing.

Then create the cluster and install the project:

```sh
GIT_REPO_URL=https://github.com/<login>/<repo>.git ./scripts/setup.sh
```

## How to Verify

Check namespaces:

```sh
kubectl get ns
```

Expected namespaces include:

```text
argocd
dev
```

Check the app:

```sh
kubectl get pods -n dev
kubectl get deployments -n dev
kubectl get ingress -n dev
```

Test the running application:

```sh
curl http://localhost:8888/
```

Expected output for the initial version:

```json
{"status":"ok", "message": "v1"}
```

## Argo CD UI

Forward the Argo CD server:

```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open:

```text
https://localhost:8080
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

The app starts with:

```yaml
image: wil42/playground:v1
```

To demonstrate Argo CD syncing a new version, edit:

```text
p3/confs/app/deployment.yaml
```

Replace:

```text
wil42/playground:v1
```

with:

```text
wil42/playground:v2
```

Commit and push the change to the public GitHub repository:

```sh
git add p3/confs/app/deployment.yaml
git commit -m "Update playground to v2"
git push
```

Argo CD should detect the Git change and sync it. After the rollout:

```sh
curl http://localhost:8888/
```

Expected output:

```json
{"status":"ok", "message": "v2"}
```

## Useful Commands

List K3d clusters:

```sh
k3d cluster list
```

Check Argo CD resources:

```sh
kubectl get pods -n argocd
kubectl get applications -n argocd
```

Watch the app rollout:

```sh
kubectl -n dev rollout status deployment/playground
```

Delete the cluster:

```sh
./scripts/cleanup.sh
```

## Submission Context

The PDF expects the mandatory work to be organized at the repository root as:

- `p1`
- `p2`
- `p3`

This README documents only `p3`.

Part 1 proves a two-node K3s cluster with Vagrant. Part 2 deploys three apps in one K3s VM and routes them with Ingress. Part 3 replaces Vagrant-based Kubernetes with K3d and adds Argo CD GitOps deployment from GitHub.
