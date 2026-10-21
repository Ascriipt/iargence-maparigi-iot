# Inception-of-Things

This repository contains the mandatory parts and bonus for the **Inception-of-Things** project.

The project is a progressive introduction to Kubernetes:

- `p1`: create a two-node K3s cluster with Vagrant.
- `p2`: deploy three web applications in one K3s VM and route them with Ingress.
- `p3`: create a K3d cluster and deploy an app with Argo CD from Git.
- `bonus`: replace the Part 3 GitHub dependency with a local GitLab instance.

Each folder has its own README with detailed run steps. This root README is a correction guide: it explains what the subject asks, what the code does, why each file exists, what the tricky parts are, and which commands to use during evaluation.

## Correction Scale Fast Map

Use this section as the short defense path for the correction PDF. Each part also has its own detailed checklist in its folder README.

| Scale question | Where to show it | Command or answer |
| --- | --- | --- |
| Basic operation of K3s | Key Concepts | K3s is lightweight Kubernetes. A server node runs the control plane; an agent joins it as a worker. |
| Basic operation of Vagrant | Key Concepts | Vagrant describes VMs as code and provisions them with shell scripts through VirtualBox. |
| Basic operation of K3d | Key Concepts | K3d runs K3s clusters as Docker containers, which is why Part 3 needs Docker. |
| Continuous integration and Argo CD | Key Concepts | CI builds/tests changes; Argo CD is GitOps CD that syncs Kubernetes state from Git. |
| Required folders | Repository Layout | `p1`, `p2`, and `p3` are present. `bonus` is present for the optional GitLab part. |
| Part 1 Vagrantfile | `p1/vagrantfile` | Two VMs: `iargenceS` and `iargenceSW`, IPs `192.168.56.110` and `192.168.56.111`. |
| Part 1 usage | `p1/README.md` | `vagrant up`, `vagrant ssh iargenceS`, `vagrant ssh iargenceSW`, `kubectl get nodes -o wide`. |
| Part 2 Vagrantfile | `p2/Vagrantfile` | One VM: `maparigiS`, IP `192.168.56.110`. |
| Part 2 apps | `p2/confs/apps.yaml` | `app1` has 1 replica, `app2` has 3 replicas, `app3` has 1 replica. |
| Part 2 Ingress | `p2/README.md` | Use `curl -H "Host: app1.com" http://192.168.56.110` and similar commands. |
| Part 3 namespaces | `p3/README.md` | `kubectl get ns` must show `argocd` and `dev`. |
| Part 3 Argo CD | `p3/confs/argocd/application.yaml.tpl` | Argo CD watches the Git repo path `p3/confs/app` and syncs the app into `dev`. |
| Part 3 Docker image | `p3/confs/app/deployment.yaml` | Uses `wil42/playground:v1`, then the demo changes it to `wil42/playground:v2`. |
| Bonus GitLab | `bonus/README.md` | Local GitLab runs in the `gitlab` namespace and replaces GitHub as Argo CD's Git source. |

The correction PDF text says to check for CentOS in p1 and p2. This repository currently uses the stable `ubuntu/jammy64` Vagrant box in both Vagrantfiles. If the evaluator applies that CentOS line strictly, the Vagrant boxes must be changed in code; the rest of the documented checks remain the same.

## Repository Layout

```text
p1/
  vagrantfile
  scripts/
    server.sh
    worker.sh
  shared/

p2/
  Vagrantfile
  scripts/
    server.sh
  confs/
    apps.yaml

p3/
  scripts/
    install_tools.sh
    setup.sh
    cleanup.sh
  confs/
    argocd/application.yaml.tpl
    app/deployment.yaml

bonus/
  scripts/
    install_tools.sh
    setup.sh
    update_app_to_v2.sh
    cleanup.sh
  confs/
    gitlab/values.yaml
    argocd/application.yaml.tpl
    app/deployment.yaml
```

## Key Concepts

**Vagrant** creates repeatable virtual machines from code. In `p1` and `p2`, Vagrant starts Ubuntu VMs, assigns static private IPs, and runs provisioning scripts.

**VirtualBox** is the Vagrant provider used to run the VMs.

**Docker** runs containers. A container packages an application with the files it needs to run. In `p3` and `bonus`, Docker is also used by K3d to run an entire Kubernetes cluster as Docker containers.

**Kubernetes**, often shortened to K8s, is a system for running containerized applications. Instead of manually starting containers one by one, you describe the desired state in YAML files: how many copies should run, which image to use, which port to expose, and how traffic should reach the app. Kubernetes then tries to keep the real state matching that desired state.

**Cluster** means the whole Kubernetes environment. It contains the machines or containers that run Kubernetes itself and the application workloads.

**Node** means one machine that belongs to the cluster. In `p1`, `iargenceS` and `iargenceSW` are two nodes. In `p2`, `maparigiS` is one node. In `p3` and `bonus`, K3d creates Docker containers that behave like Kubernetes nodes.

**Control plane** is the brain of the cluster. It exposes the Kubernetes API, stores cluster state, schedules workloads, and manages controllers. In K3s, the server node runs the control plane.

**Worker** is a node that runs application workloads. In `p1`, `iargenceSW` is the worker. K3s server nodes can also run workloads, which is why `p2` can run apps on its single server VM.

**K3s** is a lightweight Kubernetes distribution. It gives you a real Kubernetes cluster with fewer moving parts than a full upstream Kubernetes installation. In `p1`, one VM runs K3s server mode and one VM runs K3s agent mode. In `p2`, one VM runs K3s server mode and also runs the application pods.

**K3s server mode** starts the control plane. This is used by `p1/scripts/server.sh` and `p2/scripts/server.sh`.

**K3s agent mode** joins an existing K3s server as a worker. This is used by `p1/scripts/worker.sh`.

**K3d** runs K3s clusters inside Docker containers. It is used in `p3` and `bonus` because the subject asks to move away from Vagrant for Part 3.

**kubectl** is the Kubernetes CLI used to check nodes, pods, deployments, services, Ingresses, and Argo CD resources.

**YAML manifests** are configuration files that describe Kubernetes resources. Examples in this repo are `p2/confs/apps.yaml`, `p3/confs/app/deployment.yaml`, and `bonus/confs/app/deployment.yaml`.

**Pod** is the smallest runnable unit in Kubernetes. A pod usually contains one container. In `p2`, each app pod runs one nginx container.

**Deployment** tells Kubernetes how many pods should exist and which container image they should run. If a pod dies, the Deployment creates a replacement. In `p2`, `app2` has `replicas: 3`, so Kubernetes keeps three app2 pods running.

**Replica** means one copy of a pod. Three replicas means three running copies of the same app.

**Service** gives a stable internal network address for pods. Pods can be destroyed and recreated with new IPs, so other components talk to the Service instead of directly to individual pods.

**ConfigMap** stores configuration or small files inside Kubernetes. In `p2`, each app has a ConfigMap containing its `index.html`, which nginx serves as the web page.

**Ingress** routes HTTP traffic from outside the cluster to internal Services. In `p2`, it routes `app1.com` to app1, `app2.com` to app2, and all other hosts to app3.

**Ingress controller** is the real running component that implements Ingress rules. K3s installs Traefik by default, so Traefik handles the HTTP routing in `p2`. The bonus uses GitLab's nginx Ingress controller instead.

**Host header** is the HTTP value that says which domain the client requested. `curl -H "Host: app1.com" http://192.168.56.110` connects to the VM IP but asks for `app1.com`, letting the Ingress choose app1.

**Namespace** is a Kubernetes grouping mechanism. It keeps resources separated. Part 3 requires `argocd` for Argo CD and `dev` for the app. The bonus also requires `gitlab`.

**Argo CD** is the GitOps controller used in `p3` and `bonus`. It watches a Git repository and applies Kubernetes manifests into the cluster.

**GitOps** means Git is the source of truth. Instead of manually applying every change with `kubectl apply`, you push a change to Git and Argo CD syncs the cluster to match it.

**GitLab bonus** means running a local GitLab instance in the cluster and using it as the Git source for Argo CD.

## Important Tricky Part: Network Interfaces

The subject examples mention old interface names such as `eth0` and `eth1`, but modern Ubuntu boxes use predictable names such as `enp0s8`.

Hard-coding:

```sh
--flannel-iface=eth1
```

caused K3s to fail because the interface did not exist.

The scripts now detect the correct interface from the static private IP:

```sh
FLANNEL_IFACE=$(ip -o addr show to "${SERVER_IP}/32" | awk '{print $2; exit}')
```

This is used in:

- `p1/scripts/server.sh`
- `p1/scripts/worker.sh`
- `p2/scripts/server.sh`

That makes the setup work with the real interface name, for example `enp0s8`.

## Part 1: K3s and Vagrant

### What the Subject Asks

Part 1 asks for:

- two Vagrant machines;
- a stable Linux Vagrant box. The correction PDF text says CentOS; this repo currently uses `ubuntu/jammy64`;
- low resources, usually 1 CPU and 512 MB or 1024 MB RAM;
- hostnames based on a team login:
  - server ends with `S`;
  - worker ends with `SW`;
- server IP: `192.168.56.110`;
- worker IP: `192.168.56.111`;
- passwordless SSH through Vagrant;
- K3s server mode on the first machine;
- K3s agent mode on the second machine;
- `kubectl` available to verify the cluster.

### How the Code Answers

`p1/vagrantfile` defines two VMs:

- `iargenceS` at `192.168.56.110`;
- `iargenceSW` at `192.168.56.111`.

`p1/scripts/server.sh` installs K3s server mode. It binds and advertises the server on `192.168.56.110`, detects the Flannel interface, waits for K3s to become usable, and writes the node token into `/vagrant_shared/token`.

`p1/scripts/worker.sh` waits for that shared token, installs K3s agent mode, and joins the server at:

```text
https://192.168.56.110:6443
```

`p1/shared/` is mounted into both machines and is used only to pass the server join token to the worker.

### Run and Correct

From `p1`:

```sh
vagrant up
```

Check VM state:

```sh
vagrant status
```

Check nodes:

```sh
vagrant ssh iargenceS -c 'kubectl get nodes -o wide'
```

Expected result:

```text
iargences    Ready    control-plane   192.168.56.110
iargencesw   Ready    <none>          192.168.56.111
```

Check K3s services:

```sh
vagrant ssh iargenceS -c 'sudo systemctl status k3s --no-pager'
vagrant ssh iargenceSW -c 'sudo systemctl status k3s-agent --no-pager'
```

Stop or delete:

```sh
vagrant halt
vagrant destroy -f
```

## Part 2: K3s and Three Applications

### What the Subject Asks

Part 2 asks for:

- one Vagrant VM;
- a stable Linux Vagrant box. The correction PDF text says CentOS; this repo currently uses `ubuntu/jammy64`;
- K3s installed in server mode;
- VM name based on login plus `S`;
- VM IP: `192.168.56.110`;
- three web applications running in K3s;
- routing based on the HTTP `Host` header:
  - `app1.com` displays app1;
  - `app2.com` displays app2;
  - all other hosts display app3 by default;
- app2 must have 3 replicas;
- the Ingress must be shown during defense.

### How the Code Answers

`p2/Vagrantfile` defines one VM:

- `maparigiS` at `192.168.56.110`.

`p2/scripts/server.sh` installs K3s server mode, detects the private interface, waits for the node to be ready, applies the manifests, and waits for the deployments.

`p2/confs/apps.yaml` defines:

- ConfigMaps containing simple `index.html` pages;
- Deployments for `app1`, `app2`, and `app3`;
- Services for each app;
- an Ingress named `webapps`.

`app2` has:

```yaml
replicas: 3
```

The Ingress has explicit host rules for `app1.com`, `app2.com`, and `app3.com`, plus a hostless catch-all rule so unknown hosts and direct IP access go to app3.

### Run and Correct

From `p2`:

```sh
vagrant up
```

If the VM already exists after editing scripts or manifests:

```sh
vagrant provision maparigiS
```

Check node and resources:

```sh
vagrant ssh maparigiS -c 'kubectl get nodes -o wide'
vagrant ssh maparigiS -c 'kubectl get pods,deployments,services,ingress -o wide'
```

Expected deployment state:

```text
app1   1/1
app2   3/3
app3   1/1
```

Test routing:

```sh
vagrant ssh maparigiS -c 'curl -H "Host: app1.com" http://192.168.56.110'
vagrant ssh maparigiS -c 'curl -H "Host: app2.com" http://192.168.56.110'
vagrant ssh maparigiS -c 'curl -H "Host: unknown.com" http://192.168.56.110'
vagrant ssh maparigiS -c 'curl http://192.168.56.110'
```

Expected pages contain:

```text
app1
app2
app3
app3
```

Show the Ingress:

```sh
vagrant ssh maparigiS -c 'kubectl describe ingress webapps'
```

Destroy:

```sh
vagrant destroy -f
```

## Part 3: K3d and Argo CD

### What the Subject Asks

Part 3 asks for:

- K3d installed on the machine;
- Docker available, because K3d runs K3s in Docker;
- a script that installs required tools during defense;
- a K3d cluster;
- two namespaces:
  - `argocd`;
  - `dev`;
- Argo CD installed in `argocd`;
- one application deployed in `dev`;
- the app deployed automatically by Argo CD from a public GitHub repository;
- the app must have two versions;
- updating the Git repository from v1 to v2 must update the running app.

### How the Code Answers

`p3/scripts/install_tools.sh` installs Docker, K3d, and kubectl.

`p3/scripts/setup.sh` creates a K3d cluster named `iot-p3`, installs Argo CD, creates `argocd` and `dev`, and applies an Argo CD Application.

`p3/confs/argocd/application.yaml.tpl` is a template. The setup script fills in the public GitHub URL with `GIT_REPO_URL`.

`p3/confs/app/deployment.yaml` deploys Wil's subject-provided app:

```text
wil42/playground:v1
```

The app exposes port `8888`. K3d maps host port `8888` to the cluster load balancer, so it can be tested with:

```sh
curl http://localhost:8888/
```

### Run and Correct

First push this repository to a public GitHub repository. The subject requires the repository name to contain a team login.

From `p3`:

```sh
./scripts/install_tools.sh
```

If your user was added to the `docker` group, log out and log back in.

Then:

```sh
GIT_REPO_URL=https://github.com/<login>/<repo>.git ./scripts/setup.sh
```

Check namespaces:

```sh
kubectl get ns
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
curl http://localhost:8888/
```

Expected initial output:

```json
{"status":"ok", "message": "v1"}
```

### Version Update Demo

Edit:

```text
p3/confs/app/deployment.yaml
```

Change:

```text
wil42/playground:v1
```

to:

```text
wil42/playground:v2
```

Commit and push:

```sh
git add p3/confs/app/deployment.yaml
git commit -m "Update playground to v2"
git push
```

Argo CD should sync the change. Verify:

```sh
curl http://localhost:8888/
```

Expected output:

```json
{"status":"ok", "message": "v2"}
```

Open Argo CD:

```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Then browse to:

```text
https://localhost:8080
```

Get the password:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

Cleanup:

```sh
./scripts/cleanup.sh
```

## Bonus: Local GitLab

### What the Subject Asks

The bonus asks for:

- a local GitLab instance;
- the latest official GitLab version;
- GitLab running locally;
- GitLab configured to work with the cluster;
- a namespace named `gitlab`;
- everything from Part 3 working with local GitLab instead of GitHub;
- bonus files inside a `bonus` folder.

The subject also says the bonus is evaluated only if all mandatory parts are flawless.

### How the Code Answers

`bonus/scripts/install_tools.sh` installs Docker, K3d, kubectl, Helm, Git, curl, and jq.

`bonus/scripts/setup.sh` creates a K3d cluster named `iot-bonus`, disables Traefik, installs GitLab with the official GitLab Helm chart in the `gitlab` namespace, creates a local GitLab project, pushes the app manifests to it, installs Argo CD, and points Argo CD to the local GitLab service.

`bonus/confs/gitlab/values.yaml` configures the official chart for local use.

`bonus/confs/app/deployment.yaml` starts with:

```text
wil42/playground:v1
```

`bonus/scripts/update_app_to_v2.sh` clones the local GitLab project, changes the image to `v2`, commits, and pushes. Argo CD should then sync the new version.

### Run and Correct

From `bonus`:

```sh
./scripts/install_tools.sh
```

If your user was added to the `docker` group, log out and log back in.

Then:

```sh
./scripts/setup.sh
```

GitLab is heavy. The first start can take several minutes.

GitLab URL:

```text
http://gitlab.127.0.0.1.nip.io:8080
```

Application URL:

```text
http://playground.127.0.0.1.nip.io:8080
```

Check namespaces:

```sh
kubectl get ns
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
curl -H 'Host: playground.127.0.0.1.nip.io' http://localhost:8080/
```

Expected initial output:

```json
{"status":"ok", "message": "v1"}
```

Demo the update:

```sh
./scripts/update_app_to_v2.sh
```

After Argo CD syncs:

```sh
curl -H 'Host: playground.127.0.0.1.nip.io' http://localhost:8080/
```

Expected output:

```json
{"status":"ok", "message": "v2"}
```

Cleanup:

```sh
./scripts/cleanup.sh
```

## Global Correction Commands

Check all local shell scripts for syntax:

```sh
bash -n p1/scripts/server.sh
bash -n p1/scripts/worker.sh
bash -n p2/scripts/server.sh
bash -n p3/scripts/install_tools.sh
bash -n p3/scripts/setup.sh
bash -n p3/scripts/cleanup.sh
bash -n bonus/scripts/install_tools.sh
bash -n bonus/scripts/setup.sh
bash -n bonus/scripts/update_app_to_v2.sh
bash -n bonus/scripts/cleanup.sh
```

Check YAML syntax if Python with PyYAML is available:

```sh
python3 -c 'import yaml, pathlib; [list(yaml.safe_load_all(p.read_text())) for p in pathlib.Path(".").rglob("*.yaml")]; print("yaml ok")'
```

Check Vagrant state:

```sh
cd p1 && vagrant status
cd ../p2 && vagrant status
```

Check K3d clusters:

```sh
k3d cluster list
```

Check current Kubernetes context:

```sh
kubectl config current-context
kubectl get ns
```

## Common Problems

If K3s fails with `unable to find interface eth1`, the script is using the wrong network interface. Use:

```sh
ip -br addr
```

inside the VM to find the real interface. The current scripts already detect the interface from the static private IP.

If `kubectl` gives permission errors on K3s kubeconfig, make sure K3s is installed with:

```sh
--write-kubeconfig-mode=644
```

If p2 routing returns `404` for unknown hosts, check that the Ingress has the hostless catch-all rule to app3.

If p3 or bonus Argo CD does not sync, check:

```sh
kubectl get applications -n argocd
kubectl describe application -n argocd playground
kubectl get pods -n argocd
```

If Docker commands fail after installing Docker, log out and log back in so the new `docker` group membership takes effect.

## Cleanup Everything

Destroy Vagrant VMs:

```sh
cd p1 && vagrant destroy -f
cd ../p2 && vagrant destroy -f
```

Delete K3d clusters:

```sh
cd ../p3 && ./scripts/cleanup.sh
cd ../bonus && ./scripts/cleanup.sh
```
