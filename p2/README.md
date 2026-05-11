# Part 2: K3s With Three Web Applications

This part creates one virtual machine running K3s in server mode, then deploys three web applications into that K3s cluster.

The VM is:

- `maparigiS` at `192.168.56.110`

The three apps are routed by the HTTP `Host` header:

- `app1.com` displays `app1`
- `app2.com` displays `app2`
- any other host displays `app3`

Application 2 has 3 replicas, as required by the subject.

## Files

- `Vagrantfile`: defines the single VM.
- `scripts/server.sh`: installs K3s and applies the Kubernetes manifests.
- `confs/apps.yaml`: defines the ConfigMaps, Deployments, Services, and Ingress.

## Main Concepts

### Vagrant

Vagrant creates the VM from code. The `Vagrantfile` says:

- use Ubuntu Jammy;
- create one VM named `maparigiS`;
- set its hostname to `maparigiS`;
- assign the private IP `192.168.56.110`;
- give it CPU and memory;
- run `scripts/server.sh` during provisioning.

### K3s Server Mode

K3s is installed in server mode because this part only needs one machine. The server node runs the Kubernetes control plane and can also run application pods.

The install command uses:

```sh
INSTALL_K3S_EXEC="--bind-address=192.168.56.110 \
  --advertise-address=192.168.56.110 \
  --node-ip=192.168.56.110 \
  --flannel-iface=eth1"
```

Those options make K3s use the VM private network address.

### Kubernetes

Kubernetes runs applications as containers and manages their networking, scaling, and routing.

This part uses these Kubernetes resources:

- ConfigMap
- Deployment
- Service
- Ingress

They are all declared in `confs/apps.yaml`.

### ConfigMap

A ConfigMap stores configuration data as Kubernetes objects.

Here, each app has a ConfigMap containing a simple `index.html`:

- `app1-content`
- `app2-content`
- `app3-content`

Each nginx container mounts its ConfigMap at:

```sh
/usr/share/nginx/html
```

That is the default directory nginx serves static files from. Because the ConfigMap contains `index.html`, each app shows a different page without needing custom Docker images.

### Deployment

A Deployment tells Kubernetes how to run and maintain pods.

Each app has one Deployment:

- `app1`
- `app2`
- `app3`

The Deployment defines:

- which container image to use;
- how many replicas should exist;
- which labels identify the pods;
- which volume should be mounted.

For `app2`, the manifest contains:

```yaml
replicas: 3
```

This means Kubernetes should keep three `app2` pods running. If one dies, Kubernetes creates another one.

### Pod

A pod is the smallest deployable unit in Kubernetes. In this setup, each pod contains one nginx container.

For `app2`, the Deployment creates three separate pods. The Service for `app2` can send traffic to any of them.

### Labels and Selectors

Labels are key-value pairs attached to Kubernetes objects. Selectors use those labels to find matching objects.

Example:

```yaml
labels:
  app: app2
```

The `app2` Service has:

```yaml
selector:
  app: app2
```

That means the Service sends traffic to pods labeled `app: app2`.

### Service

Pods can be replaced at any time, so their IP addresses are not stable. A Service provides a stable internal network name and IP for a group of pods.

This project has one Service per app:

- `app1`
- `app2`
- `app3`

Each Service listens on port `80` and forwards to the nginx container port `80`.

### Ingress

An Ingress exposes HTTP routes from outside the cluster to Services inside the cluster.

This project has one Ingress named `webapps`.

It contains two explicit host rules:

```yaml
- host: app1.com
```

routes to the `app1` Service.

```yaml
- host: app2.com
```

routes to the `app2` Service.

The Ingress also has:

```yaml
defaultBackend:
  service:
    name: app3
```

That means requests that do not match `app1.com` or `app2.com` go to `app3`.

### Traefik

K3s installs Traefik by default. Traefik is the Ingress controller.

The Ingress resource is only a routing rule. Traefik is the running component that reads that rule and handles real HTTP requests on port `80`.

The request path is:

1. browser or `curl` sends request to `192.168.56.110`;
2. Traefik receives the HTTP request;
3. Traefik checks the `Host` header;
4. Traefik selects the matching Ingress rule;
5. Traefik forwards the request to the correct Service;
6. the Service forwards the request to one matching pod;
7. nginx returns the app page.

### Host Header

The subject asks for different behavior depending on the `HOST` used when making a request to the same IP.

In HTTP, the `Host` header tells the server which domain name the client requested. For example:

```sh
curl -H "Host: app1.com" http://192.168.56.110
```

This connects to `192.168.56.110`, but the HTTP request says the desired host is `app1.com`.

The Ingress uses that value to choose the app.

### `/etc/hosts`

Browsers usually do not let you manually set the `Host` header. To test in a browser, map the test domains to the VM IP on your host machine:

```txt
192.168.56.110 app1.com
192.168.56.110 app2.com
```

Then opening `http://app1.com` reaches `192.168.56.110` with `Host: app1.com`.

Opening `http://app2.com` reaches the same IP with `Host: app2.com`.

Opening `http://192.168.56.110` should use the default backend and display `app3`.

## How Provisioning Works

When you run `vagrant up`, Vagrant starts the VM and runs `scripts/server.sh`.

The script:

1. updates apt packages;
2. installs `curl`;
3. installs K3s in server mode;
4. copies the kubeconfig to `/home/vagrant/.kube/config`;
5. waits until the node is ready;
6. applies `confs/apps.yaml`;
7. waits for the app deployments to roll out.

The line:

```sh
kubectl apply -f /vagrant/confs/apps.yaml
```

works because Vagrant automatically mounts the project directory inside the VM at `/vagrant`.

## How to Run

From the `p2` directory:

```sh
vagrant up
```

SSH into the VM:

```sh
vagrant ssh maparigiS
```

Check the node:

```sh
kubectl get nodes -o wide
```

Check the apps:

```sh
kubectl get pods
kubectl get deployments
kubectl get services
kubectl get ingress
```

You should see:

- one ready node;
- one `app1` pod;
- three `app2` pods;
- one `app3` pod;
- one Ingress named `webapps`.

## How to Test

From your host machine:

```sh
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110
```

Expected results:

- the first command returns a page containing `app1`;
- the second command returns a page containing `app2`;
- the third command returns a page containing `app3`.

You can also test app2 replicas inside the VM:

```sh
kubectl get pods -l app=app2
```

It should show 3 running pods.

## Useful Commands

Reapply the manifests after editing them:

```sh
kubectl apply -f /vagrant/confs/apps.yaml
```

Describe the Ingress:

```sh
kubectl describe ingress webapps
```

Check Traefik:

```sh
kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik
```

See all resources:

```sh
kubectl get all
```

Destroy the VM:

```sh
vagrant destroy -f
```

## Evaluation Checklist

- The VM name is `maparigiS`.
- The VM IP is `192.168.56.110`.
- K3s runs in server mode.
- `app1.com` displays `app1`.
- `app2.com` displays `app2`.
- unknown hosts or direct IP access display `app3`.
- `app2` has 3 replicas.
