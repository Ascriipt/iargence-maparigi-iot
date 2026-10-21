# Guide Complet de Correction / Soutenance — Inception-of-Things (IoT)

Ce guide pas à pas regroupe **toutes les commandes**, les **résultats attendus**, les **démonstrations pratiques** et les **explications théoriques** indispensables pour réussir la soutenance d'Inception-of-Things.

---

## 0. Préparation & Accès à l'environnement

Toutes les parties (P1, P2, P3 et Bonus) tournent dans la **VM parente Debian 12** (`iot-parent`) configurée avec KVM/Libvirt et Docker natif pour s'affranchir des restrictions de VirtualBox sur les machines 42.

### 0.1 Connexion depuis le poste 42 hôte
Ouvrez un terminal sur votre machine 42 et lancez :
```bash
./host/enter_vm.sh
# Ou directement : ssh -p 22222 vagrant@127.0.0.1 (mot de passe si demandé : vagrant)
```
Une fois dans la VM parente, placez-vous dans le répertoire du projet :
```bash
cd ~/IOT
```

### 0.2 Remise à zéro complète (Reset clean avant correction)
Pour tout remettre à zéro avant de débuter l'évaluation (détruit toutes les VMs et clusters enfants, nettoie les logs) :
```bash
make clean
```

### 0.3 Synchronisation rapide (si modifications sur l'hôte)
Si vous modifiez des fichiers sur l'hôte 42, vous pouvez synchroniser la VM en un clic depuis l'hôte :
```bash
./host/sync_project.sh
```

---

## 1. Partie 1 — Cluster K3s Multi-nœuds (Server & Worker)

### Objectif du sujet
- Deux machines virtuelles créées via Vagrant.
- Nœud serveur nommé avec votre login terminant par `S` (ex. `iargenceS`), IP `192.168.56.110`.
- Nœud worker nommé avec votre login terminant par `SW` (ex. `iargenceSW`), IP `192.168.56.111`.
- K3s installé en mode serveur sur la 1ère VM, et en mode agent sur la 2ème VM.
- Les deux nœuds doivent être visibles en statut `Ready`.

---

### Commandes à exécuter pendant la soutenance

#### Étape 1 : Nettoyage préalable (sécurité)
```bash
make clean-p1
```

#### Étape 2 : Lancement de la Partie 1
```bash
make p1
```
*(Cela démarre `iargenceS` et `iargenceSW` via Vagrant et provisionne K3s).*

#### Étape 3 : Vérification automatisée
```bash
make p1-tests
```
*(Tous les tests doivent afficher `exit status : [0]`)*.

#### Étape 4 : Démonstration manuelle demandée par l'évaluateur
1. **Montrer l'état des VMs Vagrant** :
   ```bash
   cd ~/IOT/p1
   vagrant status
   ```
   *Résultat attendu : Les deux VMs `iargenceS` et `iargenceSW` sont en statut `running`.*

2. **Afficher les nœuds du cluster K3s depuis le serveur** :
   ```bash
   vagrant ssh iargenceS -c "kubectl get nodes -o wide"
   ```
   *Résultat attendu :*
   ```text
   NAME       STATUS   ROLES                  AGE     VERSION        INTERNAL-IP
   iargences    Ready    control-plane,master   ...     v1.31...       192.168.56.110
   iargencesw   Ready    <none>                 ...     v1.31...       192.168.56.111
   ```

3. **Montrer les services systemd K3s sur chaque machine** :
   ```bash
   # Sur le serveur : k3s (control-plane)
   vagrant ssh iargenceS -c "sudo systemctl status k3s --no-pager"

   # Sur le worker : k3s-agent
   vagrant ssh iargenceSW -c "sudo systemctl status k3s-agent --no-pager"
   ```

4. **Montrer comment le worker rejoint le serveur** :
   Montrez à l'évaluateur le dossier partagé et les scripts :
   * [p1/scripts/server.sh](file:///home/iargence/IOT/p1/scripts/server.sh) : écrit le token du nœud serveur dans `/vagrant_shared/token`.
   * [p1/scripts/worker.sh](file:///home/iargence/IOT/p1/scripts/worker.sh) : lit le token et lance l'installation avec `K3S_URL=https://192.168.56.110:6443` et `K3S_TOKEN`.

#### Étape 5 : Nettoyer avant la partie 2
```bash
cd ~/IOT
make clean-p1
```

---

## 2. Partie 2 — K3s & Routage Ingress de 3 Applications

### Objectif du sujet
- Une seule VM nommée `<login>S` (ex. `maparigiS`), IP `192.168.56.110`.
- 3 applications web déployées dans K3s.
- `app2` doit avoir **3 réplicas** (les autres 1 réplica).
- Routage Ingress par en-tête `Host` :
  - `Host: app1.com` $\rightarrow$ application 1
  - `Host: app2.com` $\rightarrow$ application 2
  - N'importe quel autre nom de domaine ou l'accès direct par IP $\rightarrow$ application 3 (default / catch-all).

---

### Commandes à exécuter pendant la soutenance

#### Étape 1 : Nettoyage préalable
```bash
make clean-p2
```

#### Étape 2 : Lancement de la Partie 2
```bash
make p2
```

#### Étape 3 : Vérification automatisée
```bash
make p2-tests
```

#### Étape 4 : Démonstration manuelle pas à pas
1. **Montrer la VM et les ressources Kubernetes** :
   ```bash
   cd ~/IOT/p2
   vagrant ssh maparigiS -c "kubectl get nodes -o wide"
   vagrant ssh maparigiS -c "kubectl get pods,deployments,services,ingress -o wide"
   ```
   *Résultat attendu :*
   * `deployment.apps/app1` : 1/1
   * `deployment.apps/app2` : 3/3 (bien insister sur les **3 réplicas**)
   * `deployment.apps/app3` : 1/1
   * `ingress.networking.k8s.io/webapps` présent.

2. **Tester les redirections Ingress avec `curl`** :
   ```bash
   # Test app1 :
   vagrant ssh maparigiS -c 'curl -s -H "Host: app1.com" http://192.168.56.110'
   # Doit afficher : Hello from App 1

   # Test app2 (3 réplicas) :
   vagrant ssh maparigiS -c 'curl -s -H "Host: app2.com" http://192.168.56.110'
   # Doit afficher : Hello from App 2

   # Test app3 (domaine spécifique) :
   vagrant ssh maparigiS -c 'curl -s -H "Host: app3.com" http://192.168.56.110'
   # Doit afficher : Hello from App 3

   # Test catch-all (domaine inconnu -> app3 par défaut) :
   vagrant ssh maparigiS -c 'curl -s -H "Host: random.local" http://192.168.56.110'
   # Doit afficher : Hello from App 3

   # Test catch-all (accès IP sans Host -> app3 par défaut) :
   vagrant ssh maparigiS -c 'curl -s http://192.168.56.110'
   # Doit afficher : Hello from App 3
   ```

3. **Montrer le fichier YAML et expliquer le Ingress** :
   Ouvrez ou affichez [p2/confs/apps.yaml](file:///home/iargence/IOT/p2/confs/apps.yaml) :
   * Montrez la règle spécifique pour `app1.com`.
   * Montrez la règle spécifique pour `app2.com`.
   * Montrez la règle `backend` par défaut (sans `host`) qui capture tout le reste pour rediriger vers `app3`.

#### Étape 5 : Nettoyer avant la partie 3
```bash
cd ~/IOT
make clean-p2
```

---

## 3. Partie 3 — K3d & GitOps Continu avec Argo CD

### Objectif du sujet
- K3d utilisé (cluster K3s sous forme de conteneurs Docker).
- Deux namespaces : `argocd` et `dev`.
- Argo CD déployé dans `argocd`.
- L'application `playground` déployée dans `dev` de manière automatisée par Argo CD depuis un dépôt public GitHub.
- Modification du fichier dans GitHub (passage de `v1` à `v2`) $\rightarrow$ Argo CD synchronise automatiquement et `curl` affiche `v2`.

---

### Commandes à exécuter pendant la soutenance

#### Étape 1 : Nettoyage préalable
```bash
make clean-p3
```

#### Étape 2 : Lancement de la Partie 3
```bash
make p3
```

#### Étape 3 : Vérification automatisée
```bash
make p3-tests
```

#### Étape 4 : Démonstration manuelle pas à pas
1. **Vérifier le cluster K3d et les namespaces requis** :
   ```bash
   k3d cluster list iot-p3
   kubectl get ns
   ```
   *Vérifier la présence impérative de `argocd` et `dev`.*

2. **Vérifier les pods d'Argo CD et de l'application** :
   ```bash
   kubectl get pods -n argocd
   kubectl get pods -n dev
   kubectl get applications -n argocd
   ```
   *L'application `playground` doit être en statut `Synced` et `Healthy`.*

3. **Tester la version initiale (v1)** :
   * Depuis la VM parente :
     ```bash
     curl -s http://localhost:8888/
     ```
   * Depuis le navigateur ou terminal du poste 42 hôte :
     ```bash
     curl -s http://localhost:8888/
     ```
   *Résultat attendu :*
   ```json
   {"status":"ok", "message": "v1"}
   ```

4. **Démonstration de mise à jour GitOps (passage de v1 à v2)** :
   Expliquez que le dépôt Git est la *source de vérité* (*Source of Truth*).
   * Modifiez l'image dans le dépôt Git (dans `p3/confs/app/deployment.yaml`) pour remplacer `wil42/playground:v1` par `wil42/playground:v2`.
   * Poussez le commit sur votre dépôt GitHub :
     ```bash
     git add p3/confs/app/deployment.yaml
     git commit -m "feat: upgrade playground to v2"
     git push
     ```
   * Attendez qu'Argo CD détecte le changement (ou forcez le refresh si l'évaluateur est pressé : `kubectl -n argocd annotate application playground argocd.argoproj.io/refresh=normal --overwrite`).
   * Testez à nouveau :
     ```bash
     curl -s http://localhost:8888/
     ```
   *Résultat attendu :*
   ```json
   {"status":"ok", "message": "v2"}
   ```

5. **Interface Web d'Argo CD (bonus visuel)** :
   * Récupérer le mot de passe admin :
     ```bash
     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
     ```
   * Lancer le port-forward vers l'hôte :
     ```bash
     kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443
     ```
   * Ouvrir dans le navigateur hôte 42 : `https://localhost:8080` (identifiant `admin`, mot de passe récupéré ci-dessus).

#### Étape 5 : Nettoyer avant le bonus
```bash
make clean-p3
```

---

## 4. Partie Bonus — GitLab Local & Argo CD (100% Autonome)

### Objectif du sujet
- Remplacer la dépendance externe à GitHub par un **GitLab officiel local** installé dans le cluster.
- Namespace `gitlab` dédié.
- GitLab CE déployé avec Helm (PostgreSQL, Redis, MinIO, Gitaly, Webservice).
- Dépôt GitOps local `root/iot-gitops`.
- Argo CD synchronise l'application `playground` depuis ce GitLab interne.
- Modification locale de l'image (v1 $\rightarrow$ v2) avec `git push` sur GitLab local $\rightarrow$ Argo CD met à jour l'application.

---

### Commandes à exécuter pendant la soutenance

#### Étape 1 : Nettoyage préalable (sécurité)
```bash
make clean-bonus
```

#### Étape 2 : Lancement du Bonus
```bash
make bonus
```
*(L'installation dure environ 2 minutes, un spinner interactif affiche la progression).*

#### Étape 3 : Vérification automatisée
```bash
make bonus-tests
```
*Tous les tests doivent afficher `exit status : [0]`.*

#### Étape 4 : Démonstration détaillée pour l'évaluateur
1. **Montrer les namespaces** :
   ```bash
   kubectl get ns
   ```
   *Doit afficher : `gitlab`, `argocd`, `dev`.*

2. **Montrer tous les pods GitLab et Argo CD en état de marche** :
   ```bash
   kubectl get pods -n gitlab
   kubectl get pods -n argocd
   kubectl get pods,ingress -n dev
   ```

3. **Tester la réponse de l'application en v1** :
   * Depuis la VM parente :
     ```bash
     curl -s -H "Host: playground.127.0.0.1.nip.io" http://localhost:8080/
     ```
   * Depuis le poste 42 hôte :
     ```bash
     curl -s -H "Host: playground.127.0.0.1.nip.io" http://127.0.0.1:8080/
     ```
   *Résultat attendu :*
   ```json
   {"status":"ok", "message": "v1"}
   ```

4. **Accéder à l'interface Web de GitLab** :
   Ouvrez le navigateur du poste hôte 42 :
   * URL : **[http://gitlab.127.0.0.1.nip.io:8080](http://gitlab.127.0.0.1.nip.io:8080)**
   * Identifiant : `root`
   * Mot de passe : `RootPassword42!`
   * Montrez le dépôt du projet : **`root/iot-gitops`** contenant le fichier `confs/app/deployment.yaml`.

5. **Démonstration du cycle GitOps (passage de v1 à v2 sans Internet)** :
   Exécutez le script de mise à jour fourni :
   ```bash
   cd ~/IOT/bonus
   ./scripts/update_app_to_v2.sh
   ```
   *Expliquez à l'évaluateur que ce script :*
   - Clone le projet depuis le GitLab local (`http://gitlab.127.0.0.1.nip.io:8080/root/iot-gitops.git`).
   - Modifie l'image en `wil42/playground:v2`.
   - Effectue un `git commit` et un `git push` sur la branche `main` de GitLab local.
   - Argo CD détecte le nouveau commit et applique le rollout.

   *Vérifier la nouvelle version déployée :*
   ```bash
   kubectl -n dev rollout status deployment/playground --timeout=60s
   curl -s -H "Host: playground.127.0.0.1.nip.io" http://localhost:8080/
   ```
   *Résultat attendu :*
   ```json
   {"status":"ok", "message": "v2"}
   ```

#### Étape 5 : Nettoyage final
```bash
cd ~/IOT
make clean-bonus
```

---

## 5. Aide-Mémoire Théorique : Les Questions Fréquentes des Évaluateurs

| Question Évaluateur | Réponse Claire et Synthétique |
| :--- | :--- |
| **Quelle est la différence entre Kubernetes (K8s) et K3s ?** | K3s est une distribution Kubernetes certifiée et allégée créée par Rancher. Elle remplace etcd par SQLite (par défaut), regroupe tous les binaires dans un seul exécutable léger (<100 Mo), supprime les drivers cloud tiers inutiles, et embarque Traefik, Flannel, CoreDNS et containerd. Elle consomme beaucoup moins de RAM (~512 Mo). |
| **Quelle est la différence entre le nœud Server et le nœud Agent ?** | Le **Server** fait tourner le *Control Plane* (kube-apiserver, kube-scheduler, kube-controller-manager, SQLite/etcd) et gère l'état du cluster. L'**Agent** (worker) ne contient que l'agent de nœud (*kubelet*, *kube-proxy*, runtime de conteneurs) et sert uniquement à exécuter les Pods applicatifs. |
| **Comment le Worker s'authentifie-t-il auprès du Server ?** | Le serveur génère un secret partagé appelé `node-token` (stocké dans `/var/lib/rancher/k3s/server/node-token`). Lors de l'installation du worker (`k3s-agent`), on passe ce token via `K3S_TOKEN` ainsi que l'URL du serveur `K3S_URL=https://<SERVER_IP>:6443`. |
| **Qu'est-ce qu'un CNI et quel est celui de K3s ?** | *Container Network Interface*. C'est le plugin qui gère l'adressage IP et la communication inter-pods à travers tous les nœuds du cluster. Par défaut, K3s utilise **Flannel** avec le protocole VXLAN (port UDP 8472). |
| **Qu'est-ce qu'un Ingress et un Ingress Controller ?** | L'**Ingress** est une ressource Kubernetes (fichier YAML) décrivant des règles de routage HTTP/HTTPS (routes, chemins, noms d'hôtes). L'**Ingress Controller** est le démon logiciel (ex. **Traefik** en P2, **NGINX Ingress** dans le bonus) qui écoute le trafic réseau réel et implémente ces règles de routage en redirigeant vers les bons Services. |
| **Pourquoi K3d pour la Partie 3 au lieu de Vagrant ?** | K3d permet de créer des clusters K3s multi-nœuds en quelques secondes en lançant chaque nœud Kubernetes sous la forme d'un **conteneur Docker**, évitant ainsi le coût et la lenteur de création d'une machine virtuelle complète. |
| **Qu'est-ce que le GitOps et que fait Argo CD ?** | GitOps est une pratique où **Git est l'unique source de vérité** pour l'infrastructure et les applications. **Argo CD** est un contrôleur Kubernetes qui tourne en continu, compare l'état réel du cluster avec les fichiers déclarés dans le dépôt Git, et applique automatiquement les changements dès qu'un commit est poussé. |
| **Qu'est-ce que le domaine `.nip.io` ?** | C'est un service DNS générique joker (*wildcard*) qui résout automatiquement n'importe quel sous-domaine vers l'adresse IP contenue dans le nom. Ex. `gitlab.127.0.0.1.nip.io` résout directement vers `127.0.0.1`, ce qui permet d'utiliser des sous-domaines Ingress sans avoir à modifier `/etc/hosts`. |

---

## 6. Synthèse des Commandes Rapides (Cheat Sheet)

```bash
# Se connecter à la VM depuis le poste 42 hôte :
./host/enter_vm.sh
cd ~/IOT

# Partie 1 :
make p1
make p1-tests
make clean-p1

# Partie 2 :
make p2
make p2-tests
make clean-p2

# Partie 3 :
make p3
make p3-tests
make clean-p3

# Bonus :
make bonus
make bonus-tests
make clean-bonus
```
