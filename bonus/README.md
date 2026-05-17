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

## Files

- `scripts/install_tools.sh`: installs Docker, K3d, kubectl, Helm, Git, curl, and jq.
- `scripts/setup.sh`: creates the K3d cluster, installs GitLab, creates a local GitLab project, pushes the app manifests, installs Argo CD, and creates the Argo CD Application.
- `scripts/update_app_to_v2.sh`: pushes a GitLab commit changing the app from `v1` to `v2`.
- `scripts/cleanup.sh`: deletes the bonus K3d cluster.
- `confs/gitlab/values.yaml`: Helm values for local GitLab.
- `confs/argocd/application.yaml.tpl`: Argo CD Application template.
- `confs/app/deployment.yaml`: initial app manifests pushed to local GitLab.

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
