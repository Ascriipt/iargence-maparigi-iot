# Inception-of-Things: Part 1

This folder is the `p1` mandatory part of the **Inception-of-Things** project.

The subject asks for a small K3s cluster created with Vagrant. The cluster must use two virtual machines:

- one server/controller node;
- one worker/agent node.

In this implementation, the machines are:

- `hrobinS`: K3s server node, `192.168.56.110`
- `hrobinSW`: K3s worker node, `192.168.56.111`

The names follow the subject rule: use a team login, then add `S` for the server and `SW` for the server-worker. If the evaluated login needs to be different, update the VM names and hostnames in `vagrantfile`.

## Subject Requirements Covered

The PDF asks Part 1 to provide:

- two machines managed by Vagrant;
- a recent stable Linux distribution;
- minimal resources, usually 1 CPU and 512 MB or 1024 MB RAM;
- hostnames based on a team login, ending in `S` and `SW`;
- static private IPs:
  - server: `192.168.56.110`;
  - worker: `192.168.56.111`;
- passwordless SSH access through Vagrant;
- K3s installed in controller/server mode on the first machine;
- K3s installed in agent mode on the second machine;
- `kubectl` available for checking the cluster.

This project uses `ubuntu/jammy64`, VirtualBox, Vagrant shell provisioning, and K3s.

## Files

- `vagrantfile`: defines both VMs, their hostnames, IPs, resources, synced folder, and provisioning scripts.
- `scripts/server.sh`: installs and configures K3s on `hrobinS`.
- `scripts/worker.sh`: installs and configures the K3s agent on `hrobinSW`.
- `shared/`: synced folder mounted at `/vagrant_shared` inside both VMs. It is used to pass the server join token to the worker.

## Configuration Files Explained

### `vagrantfile`

This is the only hand-written configuration file for Part 1. It tells Vagrant how to create the two VirtualBox machines required by the subject.

- `Vagrant.configure("2")` selects Vagrant's version 2 configuration format.
- `config.vm.synced_folder "./shared", "/vagrant_shared"` mounts the local `shared` directory inside both VMs. The server writes the K3s join token there, and the worker reads it from the same location.
- `config.vm.define "hrobinS"` declares the server VM.
- `server.vm.box = "ubuntu/jammy64"` uses Ubuntu 22.04 as the base image for the server.
- `server.vm.hostname = "hrobinS"` sets the VM hostname expected by the subject naming rule.
- `server.vm.network "private_network", ip: "192.168.56.110"` gives the server its static private IP.
- `vb.memory = 2048` gives the server 2 GB of RAM. This is higher than the minimum because K3s was unstable at 1 GB in this environment.
- `vb.cpus = 1` keeps the server at one CPU.
- `server.vm.provision "shell", path: "scripts/server.sh"` runs the server install script during `vagrant up` or `vagrant provision`.
- `config.vm.define "hrobinSW"` declares the worker VM.
- `worker.vm.box = "ubuntu/jammy64"` uses the same Ubuntu base image for the worker.
- `worker.vm.hostname = "hrobinSW"` sets the worker hostname.
- `worker.vm.network "private_network", ip: "192.168.56.111"` gives the worker its static private IP.
- `vb.memory = 1024` gives the worker 1 GB of RAM.
- `vb.cpus = 1` keeps the worker at one CPU.
- `worker.vm.provision "shell", path: "scripts/worker.sh"` runs the worker install script, which joins the server node.

### `shared/token`

This file is not meant to be edited by hand. It is runtime state produced by `scripts/server.sh`.

The K3s server creates a node token under `/var/lib/rancher/k3s/server/node-token`. The provisioning script copies that token into the synced `shared` directory so the worker VM can read it from `/vagrant_shared/token` and join the cluster.

If the cluster is destroyed and recreated, this token can change. It belongs to the current local Vagrant environment, not to the project configuration.

## Scripts Explained

### `scripts/server.sh`

This script provisions the `hrobinS` VM as the K3s server node.

- `set -e` stops the script immediately if a command fails.
- `SERVER_IP="192.168.56.110"` stores the static private IP assigned in `vagrantfile`.
- `FLANNEL_IFACE=$(ip -o addr show to "${SERVER_IP}/32" | awk '{print $2; exit}')` finds the real Linux network interface that owns the server IP.
- The empty-interface check exits with a clear error if the private network is not configured correctly.
- `apt-get update -y` refreshes the package index before installing K3s dependencies through the K3s installer.
- `curl -sfL https://get.k3s.io | ... sh -` runs the official K3s installer in server mode.
- `--bind-address`, `--advertise-address`, and `--node-ip` force K3s to use `192.168.56.110` instead of another VM interface.
- `--write-kubeconfig-mode=644` makes the generated kubeconfig readable by the `vagrant` user.
- `--flannel-iface=${FLANNEL_IFACE}` tells Flannel to use the private network interface for pod networking.
- The first `while` loop waits until K3s has created both the node token and kubeconfig.
- The `until kubectl get nodes` loop waits until the Kubernetes API is usable.
- `cp /var/lib/rancher/k3s/server/node-token /vagrant_shared/token` shares the join token with the worker VM.
- The final `mkdir`, `cp`, and `chown` commands install kubeconfig for the `vagrant` user so `kubectl` works after SSH login.

### `scripts/worker.sh`

This script provisions the `hrobinSW` VM as a K3s agent node.

- `set -e` stops the script on the first failure.
- `WORKER_IP="192.168.56.111"` stores the worker's static private IP.
- `FLANNEL_IFACE=...` detects the worker's private network interface from that IP.
- The empty-interface check prevents installing K3s with a bad Flannel interface.
- `apt-get update -y` refreshes package metadata.
- The `while [ ! -f /vagrant_shared/token ]` loop waits until the server has written its join token.
- `TOKEN=$(cat /vagrant_shared/token)` reads the token produced by the server.
- The K3s installer runs in agent mode because `K3S_URL=https://192.168.56.110:6443` points it at the server API.
- `K3S_TOKEN=$TOKEN` authenticates the worker to the server.
- `INSTALL_K3S_EXEC="--node-ip=${WORKER_IP} --flannel-iface=${FLANNEL_IFACE}"` pins the worker to its private IP and matching network interface.

## How the Cluster Is Built

Vagrant starts `hrobinS` first. That VM gets the static private IP `192.168.56.110`.

The server provisioning script:

1. Finds the network interface that owns `192.168.56.110`.
2. Installs K3s in server mode.
3. Binds and advertises K3s on `192.168.56.110`.
4. Configures Flannel to use the private network interface.
5. Waits until K3s has created the node token and kubeconfig.
6. Waits until `kubectl get nodes` works.
7. Copies the join token to `/vagrant_shared/token`.
8. Copies the kubeconfig to `/home/vagrant/.kube/config`.

Then Vagrant starts `hrobinSW`. That VM gets the static private IP `192.168.56.111`.

The worker provisioning script:

1. Finds the network interface that owns `192.168.56.111`.
2. Waits until `/vagrant_shared/token` exists.
3. Reads the server token.
4. Installs K3s in agent mode.
5. Joins the server at `https://192.168.56.110:6443`.

When everything is correct, the server sees both nodes in the same Kubernetes cluster.

## Correction Notes

The first version failed because it hard-coded the private network interface as `eth1`:

```sh
--flannel-iface=eth1
```

On this `ubuntu/jammy64` box, the private interface is actually named `enp0s8`. Modern Linux distributions often use predictable interface names instead of older names like `eth0` and `eth1`.

K3s failed with an error like:

```text
unable to find interface eth1
```

The fix is to discover the correct interface from the VM's static private IP:

```sh
FLANNEL_IFACE=$(ip -o addr show to "${SERVER_IP}/32" | awk '{print $2; exit}')
```

The worker does the same lookup with `WORKER_IP`.

This matches the warning in the subject PDF: do not assume old interface names; inspect the VM network configuration and adapt the commands to the real interface names.

The server VM was also increased to `2048` MB RAM. The subject recommends minimal resources, but K3s was unstable at `1024` MB in this environment while the worker was joining. The worker remains at `1024` MB.

## How to Run

From the `p1` directory:

```sh
vagrant up
```

Connect to the server:

```sh
vagrant ssh hrobinS
```

Connect to the worker:

```sh
vagrant ssh hrobinSW
```

## How to Verify

From inside the server VM:

```sh
kubectl get nodes -o wide
```

Expected result:

```text
NAME       STATUS   ROLES           INTERNAL-IP
hrobins    Ready    control-plane   192.168.56.110
hrobinsw   Ready    <none>          192.168.56.111
```

The exact age, version, kernel, and runtime columns can be different.

You can also run the check from the host:

```sh
vagrant ssh hrobinS -c 'kubectl get nodes -o wide'
```

## Useful Commands

Check the Vagrant machines:

```sh
vagrant status
```

Check the server K3s service:

```sh
vagrant ssh hrobinS -c 'sudo systemctl status k3s --no-pager'
```

Check the worker K3s service:

```sh
vagrant ssh hrobinSW -c 'sudo systemctl status k3s-agent --no-pager'
```

Check the VM interfaces:

```sh
vagrant ssh hrobinS -c 'ip a'
vagrant ssh hrobinSW -c 'ip a'
```

Check all Kubernetes pods:

```sh
vagrant ssh hrobinS -c 'kubectl get pods -A'
```

Destroy the environment:

```sh
vagrant destroy -f
```

## Current Verified State

After the corrections, both VMs were running and both nodes were visible from the server:

```text
hrobins    Ready    control-plane   192.168.56.110
hrobinsw   Ready    <none>          192.168.56.111
```

That satisfies the purpose of Part 1: prove that a K3s server and a K3s worker can be created with Vagrant and joined into one Kubernetes cluster.

## Submission Context

The PDF expects the mandatory work to be organized at the repository root as:

- `p1`
- `p2`
- `p3`

This README documents only `p1`. The goal of this part is not to deploy applications yet. That comes later in the subject:

- Part 2: one K3s VM with three simple applications and Ingress routing.
- Part 3: K3d with Argo CD and a GitHub-driven deployment.

For this folder, the important evaluation point is that `vagrant up` creates the two machines and that `kubectl get nodes` shows the server and worker as `Ready`.
