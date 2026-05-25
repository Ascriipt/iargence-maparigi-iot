# Colors
PURPLE := \033[38;5;141m
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLINK := \033[5m
NC := \033[0m

# Paths
P1_DIR := p1
P2_DIR := p2
P3_DIR := p3
P1_LOG := $(P1_DIR)/vagrant-up.log

.PHONY: p1 reset-p1 p1-tests reset-p2 p2-tests p3-tests clean-p1 clean-p2 clean-p3 clean

# P1 rules

p1: reset-p1
	@printf "$(PURPLE)$(BLINK)Starting p1 Vagrant environment...$(NC)\n"
	@log_file="$(P1_LOG)"; \
	status_file="/tmp/p1-vagrant-up.$$$$.status"; \
	rm -f "$$log_file" "$$status_file"; \
	(cd $(P1_DIR) && vagrant up > vagrant-up.log 2>&1; printf "%s" "$$?" > "$$status_file") & pid=$$!; \
	i=0; \
	while [ ! -s "$$status_file" ]; do \
		i=$$((i + 1)); \
		case $$((i % 4)) in \
			0) spinner='|' ;; \
			1) spinner='/' ;; \
			2) spinner='-' ;; \
			3) spinner='*' ;; \
		esac; \
		printf "\r$(YELLOW)[%s] vagrant up is running... log: %s$(NC)" "$$spinner" "$$log_file"; \
		sleep 1; \
	done; \
	wait $$pid; \
	status=$$(cat "$$status_file"); \
	rm -f "$$status_file"; \
	printf "\r\033[K"; \
	if [ "$$status" -eq 0 ]; then \
		printf "$(GREEN)Done. Vagrant output saved to %s$(NC)\n" "$$log_file"; \
	else \
		printf "$(RED)vagrant up failed. See %s$(NC)\n" "$$log_file"; \
	fi; \
	exit "$$status"

reset-p1:
	@printf "$(YELLOW)Resetting old p1 VMs and token...$(NC)\n"
	@(cd $(P1_DIR) && vagrant destroy -f >/dev/null 2>&1) || true
	@for vm in $$(VBoxManage list vms 2>/dev/null | awk -F'"' '/^"p1_hrobin(S|SW)_/ { print $$2 }'); do \
		printf "$(YELLOW)Removing old VM: %s$(NC)\n" "$$vm"; \
		VBoxManage controlvm "$$vm" poweroff >/dev/null 2>&1 || true; \
		VBoxManage unregistervm "$$vm" --delete >/dev/null 2>&1 || true; \
	done
	@if [ -f $(P1_DIR)/shared/token ]; then \
		rm -f $(P1_DIR)/shared/token; \
		printf "$(GREEN)Removed leftover token: $(P1_DIR)/shared/token$(NC)\n"; \
	else \
		printf "$(GREEN)No leftover token found.$(NC)\n"; \
	fi

p1-tests:
	@printf "$(PURPLE)Running p1 tests...$(NC)\n"
	@run_cmd() { \
		cmd="$$1"; \
		printf "\n$(YELLOW)command ran : [%s]$(NC)\n" "$$cmd"; \
		output=$$(eval "$$cmd" 2>&1); \
		status=$$?; \
		if [ -n "$$output" ]; then printf "%s\n" "$$output"; else printf "(no output, exit status %d)\n" "$$status"; fi; \
		return "$$status"; \
	}; \
	pass() { printf "$(GREEN)%s$(NC)\n" "$$1"; }; \
	fail() { printf "$(RED)Error: %s$(NC)\n" "$$1"; exit 1; }; \
	run_cmd "test -f $(P1_DIR)/vagrantfile"; [ $$? -eq 0 ] || fail "$(P1_DIR)/vagrantfile not found."; \
	pass "Vagrantfile exists test [1/8] validated."; \
	cmd="grep -E 'config\\.vm\\.define|vm\\.hostname' $(P1_DIR)/vagrantfile"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | grep -q 'config.vm.define "hrobinS"' && \
	printf "%s\n" "$$output" | grep -q 'config.vm.define "hrobinSW"' && \
	printf "%s\n" "$$output" | grep -q 'server.vm.hostname = "hrobinS"' && \
	printf "%s\n" "$$output" | grep -q 'worker.vm.hostname = "hrobinSW"' || fail "expected hrobinS and hrobinSW definitions were not found."; \
	pass "Expected VM names and hostnames test [2/8] validated."; \
	cmd="grep -E '192\\.168\\.56\\.110|192\\.168\\.56\\.111' $(P1_DIR)/vagrantfile"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | grep -q '192.168.56.110' && \
	printf "%s\n" "$$output" | grep -q '192.168.56.111' || fail "expected static private IPs are missing from $(P1_DIR)/vagrantfile."; \
	pass "Static private IP configuration test [3/8] validated."; \
	cmd="cd $(P1_DIR) && vagrant status --machine-readable"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | awk -F, '$$2 ~ /^hrobinS(W)?$$/ && $$3 == "state" && $$4 == "running" { running++ } END { exit running == 2 ? 0 : 1 }' || fail "not all p1 VMs are running."; \
	pass "Both VMs running test [4/8] validated."; \
	cmd="cd $(P1_DIR) && vagrant ssh hrobinS -c hostname && vagrant ssh hrobinSW -c hostname"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | tr -d '\r' | grep -qx 'hrobinS' && \
	printf "%s\n" "$$output" | tr -d '\r' | grep -qx 'hrobinSW' || fail "SSH failed or VM hostnames are incorrect."; \
	pass "Passwordless SSH and hostname test [5/8] validated."; \
	cmd="cd $(P1_DIR) && vagrant ssh hrobinS -c 'ip -o addr show to 192.168.56.110/32' && vagrant ssh hrobinSW -c 'ip -o addr show to 192.168.56.111/32'"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | grep -q '192.168.56.110' && \
	printf "%s\n" "$$output" | grep -q '192.168.56.111' || fail "expected private IP is missing inside one of the VMs."; \
	pass "Private network interface IP test [6/8] validated."; \
	cmd="cd $(P1_DIR) && vagrant ssh hrobinS -c 'systemctl is-active k3s' && vagrant ssh hrobinSW -c 'systemctl is-active k3s-agent'"; run_cmd "$$cmd"; \
	[ "$$(printf "%s\n" "$$output" | grep -cx 'active')" -eq 2 ] || fail "k3s server or k3s-agent service is not active."; \
	pass "K3s server and agent services test [7/8] validated."; \
	cmd="cd $(P1_DIR) && vagrant ssh hrobinS -c 'kubectl get nodes -o wide --no-headers'"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | awk '$$1 == "hrobins" && $$2 == "Ready" && $$3 ~ /control-plane/ && $$6 == "192.168.56.110" { server = 1 } $$1 == "hrobinsw" && $$2 == "Ready" && $$6 == "192.168.56.111" { worker = 1 } END { exit server && worker ? 0 : 1 }' || fail "expected Ready K3s nodes were not found in the cluster."; \
	pass "Kubernetes cluster readiness test [8/8] validated."

# P2 rules

p2-tests:
	@printf "$(PURPLE)Running p2 tests...$(NC)\n"
	@run_cmd() { \
		cmd="$$1"; \
		printf "\n$(YELLOW)command ran : [%s]$(NC)\n" "$$cmd"; \
		output=$$(eval "$$cmd" 2>&1); \
		status=$$?; \
		if [ -n "$$output" ]; then printf "%s\n" "$$output"; else printf "(no output, exit status %d)\n" "$$status"; fi; \
		return "$$status"; \
	}; \
	pass() { printf "$(GREEN)%s$(NC)\n" "$$1"; }; \
	fail() { printf "$(RED)Error: %s$(NC)\n" "$$1"; exit 1; }; \
	run_cmd "test -f $(P2_DIR)/Vagrantfile"; [ $$? -eq 0 ] || fail "$(P2_DIR)/Vagrantfile not found."; \
	pass "Vagrantfile exists test [1/8] validated."; \
	cmd="grep -E 'config\\.vm\\.define|vm\\.hostname|192\\.168\\.56\\.110' $(P2_DIR)/Vagrantfile"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | grep -q 'config.vm.define "maparigiS"' && \
	printf "%s\n" "$$output" | grep -q 'server.vm.hostname = "maparigiS"' && \
	printf "%s\n" "$$output" | grep -q '192.168.56.110' || fail "expected maparigiS hostname or static IP is missing."; \
	pass "VM name, hostname, and static IP test [2/8] validated."; \
	cmd="cd $(P2_DIR) && vagrant status --machine-readable"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | awk -F, '$$2 == "maparigiS" && $$3 == "state" && $$4 == "running" { found = 1 } END { exit found ? 0 : 1 }' || fail "maparigiS is not running."; \
	pass "VM running test [3/8] validated."; \
	cmd="cd $(P2_DIR) && vagrant ssh maparigiS -c 'hostname && ip -o addr show to 192.168.56.110/32 && systemctl is-active k3s'"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | tr -d '\r' | grep -qx 'maparigiS' && \
	printf "%s\n" "$$output" | grep -q '192.168.56.110' && \
	printf "%s\n" "$$output" | grep -qx 'active' || fail "hostname, private IP, or k3s service is incorrect."; \
	pass "Hostname, private IP, and K3s service test [4/8] validated."; \
	cmd="cd $(P2_DIR) && vagrant ssh maparigiS -c 'kubectl get nodes -o wide --no-headers'"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | awk '$$1 == "maparigis" && $$2 == "Ready" && $$3 ~ /control-plane/ && $$6 == "192.168.56.110" { found = 1 } END { exit found ? 0 : 1 }' || fail "maparigiS is not a Ready K3s control-plane node."; \
	pass "K3s node readiness test [5/8] validated."; \
	cmd="grep -E 'name: app[123]|replicas: 3|name: webapps|host: app[123]\\.com|defaultBackend' $(P2_DIR)/confs/apps.yaml"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | grep -q 'name: app1' && \
	printf "%s\n" "$$output" | grep -q 'name: app2' && \
	printf "%s\n" "$$output" | grep -q 'name: app3' && \
	printf "%s\n" "$$output" | grep -q 'replicas: 3' && \
	printf "%s\n" "$$output" | grep -q 'name: webapps' && \
	printf "%s\n" "$$output" | grep -q 'defaultBackend' || fail "app manifests, app2 replicas, or Ingress are missing."; \
	pass "Application manifests and app2 replica configuration test [6/8] validated."; \
	cmd="cd $(P2_DIR) && vagrant ssh maparigiS -c 'kubectl get deployments,services,ingress -o wide'"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | grep -q 'deployment.apps/app1' && \
	printf "%s\n" "$$output" | grep -q 'deployment.apps/app2.*3/3' && \
	printf "%s\n" "$$output" | grep -q 'deployment.apps/app3' && \
	printf "%s\n" "$$output" | grep -q 'ingress.networking.k8s.io/webapps' || fail "deployed apps, app2 3/3 replicas, or webapps Ingress are missing."; \
	pass "Kubernetes app resources test [7/8] validated."; \
	cmd="cd $(P2_DIR) && vagrant ssh maparigiS -c 'curl -s -H \"Host: app1.com\" http://192.168.56.110; printf \"\\n\"; curl -s -H \"Host: app2.com\" http://192.168.56.110; printf \"\\n\"; curl -s -H \"Host: unknown.com\" http://192.168.56.110; printf \"\\n\"; curl -s http://192.168.56.110'"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | awk 'BEGIN { ok1 = ok2 = ok3 = ok4 = 0 } /app1/ { ok1 = 1 } /app2/ { ok2 = 1 } /app3/ { if (ok3) ok4 = 1; else ok3 = 1 } END { exit ok1 && ok2 && ok3 && ok4 ? 0 : 1 }' || fail "Ingress host routing did not return app1, app2, app3, app3."; \
	pass "Ingress Host routing test [8/8] validated."

# P3 rules

p3-tests:
	@printf "$(PURPLE)Running p3 tests...$(NC)\n"
	@run_cmd() { \
		cmd="$$1"; \
		printf "\n$(YELLOW)command ran : [%s]$(NC)\n" "$$cmd"; \
		output=$$(eval "$$cmd" 2>&1); \
		status=$$?; \
		if [ -n "$$output" ]; then printf "%s\n" "$$output"; else printf "(no output, exit status %d)\n" "$$status"; fi; \
		return "$$status"; \
	}; \
	pass() { printf "$(GREEN)%s$(NC)\n" "$$1"; }; \
	fail() { printf "$(RED)Error: %s$(NC)\n" "$$1"; exit 1; }; \
	cmd="test -f $(P3_DIR)/scripts/install_tools.sh && test -f $(P3_DIR)/scripts/setup.sh && test -f $(P3_DIR)/confs/argocd/application.yaml.tpl && test -f $(P3_DIR)/confs/app/deployment.yaml"; run_cmd "$$cmd"; \
	[ $$? -eq 0 ] || fail "required p3 scripts or configuration files are missing."; \
	pass "Required p3 files test [1/8] validated."; \
	cmd="command -v docker && command -v k3d && command -v kubectl"; run_cmd "$$cmd"; \
	[ $$? -eq 0 ] || fail "docker, k3d, or kubectl is missing."; \
	pass "Required local tools test [2/8] validated."; \
	cmd="docker info >/dev/null && k3d cluster list iot-p3"; run_cmd "$$cmd"; \
	[ $$? -eq 0 ] || fail "Docker is unavailable or k3d cluster iot-p3 does not exist."; \
	pass "Docker and k3d cluster test [3/8] validated."; \
	cmd="kubectl get ns argocd dev"; run_cmd "$$cmd"; \
	[ $$? -eq 0 ] || fail "argocd and dev namespaces are not both present."; \
	pass "Required namespaces test [4/8] validated."; \
	cmd="kubectl get applications -n argocd playground -o wide"; run_cmd "$$cmd"; \
	[ $$? -eq 0 ] || fail "Argo CD Application playground is not present."; \
	pass "Argo CD Application test [5/8] validated."; \
	cmd="kubectl -n dev get deployment,service,ingress,pods -o wide"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | grep -q 'deployment.apps/playground' && \
	printf "%s\n" "$$output" | grep -q 'service/playground' && \
	printf "%s\n" "$$output" | grep -q 'ingress.networking.k8s.io/playground' && \
	printf "%s\n" "$$output" | grep -q 'pod/playground' || fail "playground deployment, service, ingress, or pod is missing."; \
	pass "Dev namespace workload resources test [6/8] validated."; \
	cmd="kubectl -n dev rollout status deployment/playground --timeout=30s"; run_cmd "$$cmd"; \
	[ $$? -eq 0 ] || fail "playground deployment is not rolled out."; \
	pass "Playground rollout test [7/8] validated."; \
	cmd="grep -E 'wil42/playground:v[12]' $(P3_DIR)/confs/app/deployment.yaml && curl -s http://localhost:8888/"; run_cmd "$$cmd"; \
	printf "%s\n" "$$output" | grep -q 'wil42/playground:v' && \
	printf "%s\n" "$$output" | grep -q '"status":"ok"' && \
	printf "%s\n" "$$output" | grep -Eq '"message": ?"v[12]"' || fail "manifest image or localhost:8888 app response is not valid."; \
	pass "Docker image and application endpoint test [8/8] validated."

clean-p1: reset-p1
	@printf "$(RED)$(BLINK)Cleaning up p1 Vagrant logs and config files...$(NC)\n"
	@items=$$(find $(P1_DIR) -maxdepth 1 \( -name '.vagrant' -o -name '*.log' \) -print; find $(P1_DIR)/shared -mindepth 1 -maxdepth 1 -print 2>/dev/null); \
	total=$$(printf "%s\n" "$$items" | sed '/^$$/d' | wc -l); i=0; \
	if [ "$$total" -eq 0 ]; then \
		printf "Nothing to clean.\n"; \
		exit 0; \
	fi; \
	for item in $$items; do \
		i=$$((i+1)); \
		printf "\r[%d/%d] Cleaning %s..." "$$i" "$$total" "$$item"; \
		rm -rf "$$item"; \
		sleep 0.1; \
	done; \
	printf "\n$(GREEN)$(BLINK)Done.$(NC)\n"

reset-p2:
	@printf "$(YELLOW)Resetting old p2 VMs...$(NC)\n"
	@(cd $(P2_DIR) && vagrant destroy -f >/dev/null 2>&1) || true
	@for vm in $$(VBoxManage list vms 2>/dev/null | awk -F'"' '/^"p2_maparigiS_/ { print $$2 }'); do \
		printf "$(YELLOW)Removing old VM: %s$(NC)\n" "$$vm"; \
		VBoxManage controlvm "$$vm" poweroff >/dev/null 2>&1 || true; \
		VBoxManage unregistervm "$$vm" --delete >/dev/null 2>&1 || true; \
	done

clean-p2: reset-p2
	@printf "$(RED)$(BLINK)Cleaning up p2 Vagrant logs and config files...$(NC)\n"
	@rm -rf $(P2_DIR)/.vagrant $(P2_DIR)/*.log
	@printf "$(GREEN)$(BLINK)Done.$(NC)\n"

clean-p3:
	@printf "$(RED)$(BLINK)Cleaning up p3 K3d cluster...$(NC)\n"
	@(cd $(P3_DIR) && ./scripts/cleanup.sh) || true
	@printf "$(GREEN)$(BLINK)Done.$(NC)\n"

clean: clean-p1 clean-p2 clean-p3
