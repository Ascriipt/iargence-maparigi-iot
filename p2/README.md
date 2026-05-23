# Inception-of-Things: Part 2

This folder is the `p2` mandatory part of the **Inception-of-Things** project.

The subject asks for one Vagrant virtual machine running K3s in server mode. Inside that K3s cluster, three simple web applications must be deployed and routed by the HTTP `Host` header.

In this implementation, the VM is:

- `maparigiS`: K3s server node, `192.168.56.110`

The hostname follows the subject rule: use a team login, then add `S` for the server.

## Subject Requirements Covered

The PDF asks Part 2 to provide:

- one virtual machine managed by Vagrant;
- a recent stable Linux distribution;
- K3s installed in server mode;
- the VM named with a team login followed by `S`;
- the VM reachable at `192.168.56.110`;
- three web applications running in K3s;
- routing based on the request `Host` header:
  - `app1.com` must display app1;
  - `app2.com` must display app2;
  - any other host must display app3 by default;
- app2 must run with 3 replicas;
- the Ingress must be shown during evaluation.

This project uses `ubuntu/jammy64`, VirtualBox, Vagrant shell provisioning, K3s, nginx containers, and the default K3s Traefik Ingress controller.

## Files

- `Vagrantfile`: defines the single VM, hostname, IP, resources, and provisioning script.
- `scripts/server.sh`: installs K3s, waits for the node, applies the Kubernetes manifests, and waits for rollouts.
- `confs/apps.yaml`: defines the ConfigMaps, Deployments, Services, and Ingress for the three applications.

## Configuration Files Explained

### `Vagrantfile`

This file describes the single VirtualBox VM used for Part 2.

- `Vagrant.configure("2")` selects Vagrant's version 2 configuration format.
- `config.vm.box = "ubuntu/jammy64"` uses Ubuntu 22.04 as the base image.
- `config.vm.define "maparigiS"` declares the VM name used by Vagrant commands.
- `server.vm.hostname = "maparigiS"` sets the hostname inside the VM.
- `server.vm.network "private_network", ip: "192.168.56.110"` gives the VM the static private IP required by the subject.
- `vb.memory = 2048` gives the VM enough RAM to run K3s, Traefik, and the application pods.
- `vb.cpus = 1` keeps the VM at one CPU.
- `server.vm.provision "shell", path: "scripts/server.sh"` runs the provisioning script that installs K3s and applies the manifests.

### `confs/apps.yaml`

This is the Kubernetes configuration for the three web applications and their routing.

The first three resources are ConfigMaps:

- `app1-content` contains an `index.html` page that displays `app1`.
- `app2-content` contains an `index.html` page that displays `app2`.
- `app3-content` contains an `index.html` page that displays `app3`.

Each ConfigMap is mounted into an nginx container at `/usr/share/nginx/html`, replacing nginx's default page with the required app page.

The next resources are one Deployment and one Service for each app:

- `app1` runs `nginx:1.25-alpine` with `replicas: 1`.
- `app2` runs `nginx:1.25-alpine` with `replicas: 3`, which is the required replicated application.
- `app3` runs `nginx:1.25-alpine` with `replicas: 1`.
- Each Deployment uses the label `app: appX`.
- Each Service selects the matching `app: appX` pods and exposes port `80`.

The final resource is the `webapps` Ingress:

- `defaultBackend` points to the `app3` Service, so app3 is the fallback backend.
- The `app1.com` host rule sends traffic to the `app1` Service.
- The `app2.com` host rule sends traffic to the `app2` Service.
- The `app3.com` host rule sends traffic to the `app3` Service.
- The last hostless rule also sends traffic to `app3`, which makes unknown hosts and direct IP access work reliably with Traefik.

## Scripts Explained

### `scripts/server.sh`

This script provisions the `maparigiS` VM, installs K3s, and deploys the three web apps.

- `set -euo pipefail` makes the script fail on command errors, unset variables, and failed pipeline commands.
- `SERVER_IP="192.168.56.110"` stores the static private IP from `Vagrantfile`.
- `FLANNEL_IFACE=$(ip -o addr show to "${SERVER_IP}/32" | awk '{print $2; exit}')` detects the private network interface dynamically.
- The empty-interface check exits early if the expected private IP is missing.
- `apt-get update -y` refreshes package metadata.
- `apt-get install -y curl` ensures the K3s install command can download the installer.
- `curl -sfL https://get.k3s.io | ... sh -` installs K3s in server mode.
- `--bind-address`, `--advertise-address`, and `--node-ip` make K3s use `192.168.56.110`.
- `--write-kubeconfig-mode=644` makes kubeconfig readable for non-root users.
- `--flannel-iface=${FLANNEL_IFACE}` makes Flannel use the correct private interface.
- The kubeconfig wait loop pauses until `/etc/rancher/k3s/k3s.yaml` exists.
- The `mkdir`, `cp`, and `chown` commands install kubeconfig for the `vagrant` user.
- `until kubectl get nodes` waits until the Kubernetes API responds.
- `kubectl wait --for=condition=Ready nodes --all --timeout=180s` waits for the K3s node to become Ready.
- `kubectl apply -f /vagrant/confs/apps.yaml` applies the ConfigMaps, Deployments, Services, and Ingress.
- The final `kubectl rollout status` commands wait for Traefik and all three app Deployments to finish rolling out before provisioning ends.

## How the Cluster Is Built

Vagrant starts `maparigiS` with the static private IP `192.168.56.110`.

The provisioning script:

1. Installs `curl`.
2. Finds the network interface that owns `192.168.56.110`.
3. Installs K3s in server mode.
4. Binds and advertises K3s on `192.168.56.110`.
5. Configures Flannel to use the private network interface.
6. Copies the kubeconfig to `/home/vagrant/.kube/config`.
7. Waits until the node is ready.
8. Applies `/vagrant/confs/apps.yaml`.
9. Waits for Traefik and the three app deployments to roll out.

The project directory is mounted inside the VM at `/vagrant`, which is why the script can apply:

```sh
kubectl apply -f /vagrant/confs/apps.yaml
```

## Applications

Each application uses nginx and serves a different `index.html` from a ConfigMap.

- `app1-content` serves a page containing `app1`.
- `app2-content` serves a page containing `app2`.
- `app3-content` serves a page containing `app3`.

There is one Deployment and one Service per app:

- `app1`: 1 replica;
- `app2`: 3 replicas, as required by the subject;
- `app3`: 1 replica.

The app2 replica count is declared in `confs/apps.yaml`:

```yaml
replicas: 3
```

## Ingress Routing

K3s installs Traefik by default. Traefik reads the Kubernetes Ingress and handles HTTP traffic on port `80`.

The Ingress is named `webapps`.

It routes:

- `Host: app1.com` to the `app1` Service;
- `Host: app2.com` to the `app2` Service;
- `Host: app3.com` to the `app3` Service;
- any other host, including direct IP access, to `app3`.

The final catch-all route is important for the subject requirement that app3 is selected by default.

## Correction Notes

The first run failed for the same reason as Part 1: the provisioning script hard-coded the Flannel interface as `eth1`.

On this `ubuntu/jammy64` VM, the private interface is named `enp0s8`, not `eth1`. K3s failed during startup because it could not find the requested interface.

The fix is to detect the interface from the static private IP:

```sh
SERVER_IP="192.168.56.110"
FLANNEL_IFACE=$(ip -o addr show to "${SERVER_IP}/32" | awk '{print $2; exit}')
```

Then K3s is installed with:

```sh
--flannel-iface=${FLANNEL_IFACE}
```

This follows the subject PDF warning that modern Linux distributions use predictable interface names such as `enp0s8` instead of old `eth0` or `eth1` names.

The Ingress was also corrected. The default backend existed, but Traefik returned `404` for unknown hosts. A hostless catch-all rule was added so that unknown hosts and direct IP access route to app3 reliably.

## How to Run

From the `p2` directory:

```sh
vagrant up
```

If the VM already exists and only the scripts/manifests changed:

```sh
vagrant provision maparigiS
```

Connect to the VM:

```sh
vagrant ssh maparigiS
```

## How to Verify

Check the node:

```sh
vagrant ssh maparigiS -c 'kubectl get nodes -o wide'
```

Expected shape:

```text
NAME        STATUS   ROLES           INTERNAL-IP
maparigis   Ready    control-plane   192.168.56.110
```

Check the deployed resources:

```sh
vagrant ssh maparigiS -c 'kubectl get pods,deployments,services,ingress -o wide'
```

You should see:

- one Ready node;
- one running app1 pod;
- three running app2 pods;
- one running app3 pod;
- one Ingress named `webapps`.

## How to Test Routing

From the VM:

```sh
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl -H "Host: unknown.com" http://192.168.56.110
curl http://192.168.56.110
```

Expected results:

- `app1.com` returns a page containing `app1`;
- `app2.com` returns a page containing `app2`;
- an unknown host returns a page containing `app3`;
- direct IP access returns a page containing `app3`.

To test from a browser on the host, add these entries to the host `/etc/hosts` file:

```text
192.168.56.110 app1.com
192.168.56.110 app2.com
```

Then open:

- `http://app1.com`
- `http://app2.com`
- `http://192.168.56.110`

## Useful Commands

Check VM state:

```sh
vagrant status
```

Check K3s:

```sh
vagrant ssh maparigiS -c 'sudo systemctl status k3s --no-pager'
```

Check Traefik:

```sh
vagrant ssh maparigiS -c 'kubectl -n kube-system get pods,svc,deployments -o wide'
```

Describe the Ingress:

```sh
vagrant ssh maparigiS -c 'kubectl describe ingress webapps'
```

Reapply the manifests after editing them:

```sh
vagrant ssh maparigiS -c 'kubectl apply -f /vagrant/confs/apps.yaml'
```

Destroy the VM:

```sh
vagrant destroy -f
```

## Current Verified State

After the corrections:

- `maparigiS` is `Ready`;
- `app1` is `1/1`;
- `app2` is `3/3`;
- `app3` is `1/1`;
- `app1.com` returns app1;
- `app2.com` returns app2;
- unknown hosts and direct IP access return app3.

That satisfies the purpose of Part 2: run three simple applications in K3s and route traffic to them with Ingress according to the request host.

## Submission Context

The PDF expects the mandatory work to be organized at the repository root as:

- `p1`
- `p2`
- `p3`

This README documents only `p2`.

Part 1 proves a two-node K3s cluster with Vagrant. Part 2 uses one K3s server and focuses on application deployment, replicas, Services, and Ingress routing. Part 3 moves to K3d and Argo CD.
