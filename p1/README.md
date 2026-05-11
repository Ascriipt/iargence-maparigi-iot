# Part 1: K3s With One Server and One Worker

This part creates a small K3s cluster with two virtual machines:

- `hrobinS`: the K3s server node at `192.168.56.110`
- `hrobinSW`: the K3s worker node at `192.168.56.111`

The server starts the Kubernetes control plane. The worker joins that server and runs workloads as part of the same cluster.

## Files

- `vagrantfile`: defines the two virtual machines.
- `scripts/server.sh`: installs K3s in server mode.
- `scripts/worker.sh`: installs K3s in agent mode and joins the server.
- `shared/`: synced folder used to pass the K3s node token from the server VM to the worker VM.

## Main Concepts

### Vagrant

Vagrant is used to create reproducible virtual machines from a configuration file. Instead of manually creating machines in VirtualBox, the `vagrantfile` describes:

- which Linux image to use;
- the hostname of each VM;
- each private IP address;
- how much CPU and memory each VM gets;
- which provisioning script runs after boot.

In this project, the VMs use the `ubuntu/jammy64` box.

### VirtualBox Provider

The provider is the virtualization backend. Here, Vagrant uses VirtualBox. The block:

```ruby
server.vm.provider "virtualbox" do |vb|
  vb.memory = 1024
  vb.cpus = 1
end
```

sets the VM resources.

### Private Network

Each VM has a static private IP:

- server: `192.168.56.110`
- worker: `192.168.56.111`

These addresses let the VMs communicate with each other and let the host machine reach them directly.

### Synced Folder

The line:

```ruby
config.vm.synced_folder "./shared", "/vagrant_shared"
```

mounts the local `p1/shared` directory inside both VMs at `/vagrant_shared`.

This is used for a simple handoff:

1. the server creates a cluster token;
2. the server writes it to `/vagrant_shared/token`;
3. the worker waits until that file exists;
4. the worker reads the token and uses it to join the cluster.

### K3s

K3s is a lightweight Kubernetes distribution. It provides the Kubernetes API server, scheduler, controller manager, container runtime, networking, and useful defaults in a smaller package than standard Kubernetes.

K3s has two important modes here:

- server mode: runs the Kubernetes control plane;
- agent mode: joins an existing server and runs workloads.

### Server Node

The server script installs K3s with:

```sh
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="..." sh -
```

The important options are:

- `--bind-address=192.168.56.110`: makes K3s bind to the server private IP.
- `--advertise-address=192.168.56.110`: tells other nodes that this is the server address.
- `--node-ip=192.168.56.110`: registers the node with this IP inside Kubernetes.
- `--flannel-iface=eth1`: tells Flannel to use the private network interface for pod networking.

After installation, the server copies:

```sh
/var/lib/rancher/k3s/server/node-token
```

to the shared folder. That token is required by workers that want to join the cluster.

### Worker Node

The worker script waits for the token:

```sh
while [ ! -f /vagrant_shared/token ]; do
  sleep 2
done
```

Then it installs K3s in agent mode with:

```sh
K3S_URL=https://192.168.56.110:6443
K3S_TOKEN=$TOKEN
```

`K3S_URL` points to the Kubernetes API server on the server node. Port `6443` is the default Kubernetes API port.

`K3S_TOKEN` proves that the worker is allowed to join the cluster.

### Flannel

Flannel is the default network layer used by K3s. It creates the pod network, so pods can communicate even when they run on different nodes.

The option `--flannel-iface=eth1` is important in Vagrant because VMs often have multiple interfaces:

- one NAT interface for internet access;
- one private interface for host-only networking.

Using `eth1` makes the cluster use the private network instead of the NAT interface.

### kubeconfig

The server script copies:

```sh
/etc/rancher/k3s/k3s.yaml
```

to:

```sh
/home/vagrant/.kube/config
```

This file is the Kubernetes client configuration. It lets the `vagrant` user run `kubectl` without passing extra config options.

## How to Run

From the `p1` directory:

```sh
vagrant up
```

To connect to the server:

```sh
vagrant ssh hrobinS
```

To connect to the worker:

```sh
vagrant ssh hrobinSW
```

Inside the server VM, check the cluster:

```sh
kubectl get nodes -o wide
```

You should see two nodes: one server/control-plane node and one worker node.

## Useful Commands

Check running K3s services:

```sh
systemctl status k3s
systemctl status k3s-agent
```

Check nodes:

```sh
kubectl get nodes
```

Check system pods:

```sh
kubectl get pods -A
```

Destroy the VMs:

```sh
vagrant destroy -f
```

## Request Flow

Part 1 does not deploy custom applications. Its purpose is to prove that the cluster exists and that the worker successfully joined the server.

The flow is:

1. Vagrant creates the server VM.
2. The server installs K3s in server mode.
3. The server writes the join token into the synced folder.
4. Vagrant creates the worker VM.
5. The worker waits for the token.
6. The worker installs K3s in agent mode and joins the server.
7. `kubectl get nodes` on the server should show both machines.

## Evaluation Notes

The subject usually expects hostnames based on your login. If your login is `maparigi`, the names would normally be `maparigiS` and `maparigiSW`. This directory currently uses `hrobinS` and `hrobinSW`, so update the VM names and hostnames if needed before evaluation.
