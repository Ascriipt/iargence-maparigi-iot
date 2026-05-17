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

## Files

- `scripts/install_tools.sh`: installs Docker, K3d, and kubectl on an Ubuntu VM.
- `scripts/setup.sh`: creates the K3d cluster, installs Argo CD, creates namespaces, and applies the Argo CD Application.
- `scripts/cleanup.sh`: deletes the K3d cluster.
- `confs/argocd/application.yaml.tpl`: Argo CD Application template.
- `confs/app/deployment.yaml`: Kubernetes manifests for the app in the `dev` namespace.

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
