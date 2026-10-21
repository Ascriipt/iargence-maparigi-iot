# Provider configuration
export VAGRANT_DEFAULT_PROVIDER := libvirt

# Github repository URL for p3 setup
GIT_REPO_URL = "https://github.com/Ascriipt/iargence-maparigi-iot.git"

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
BONUS_DIR := bonus
P1_LOG := $(P1_DIR)/vagrant-up.log
P2_LOG := $(P2_DIR)/vagrant-up.log
P3_LOG := $(P3_DIR)/setup.log
BONUS_LOG := $(BONUS_DIR)/setup.log

.PHONY: p1 reset-p1 p1-tests p2 reset-p2 p2-tests p3 p3-tests bonus bonus-tests clean-p1 clean-p2 clean-p3 clean-bonus clean

# P1 rules

p1: reset-p1
	@mkdir -p $(P1_DIR)/shared
	@chmod 777 $(P1_DIR)/shared
	@printf "$(PURPLE)$(BLINK)Starting p1 Vagrant environment...$(NC)\n"
	@log_file="$(P1_LOG)"; \
	status_file="/tmp/p1-vagrant-up.$$$$.status"; \
	rm -f "$$log_file" "$$status_file"; \
	(cd $(P1_DIR) && vagrant up --no-parallel > vagrant-up.log 2>&1; printf "%s" "$$?" > "$$status_file") & pid=$$!; \
	i=0; \
	while [ ! -s "$$status_file" ]; do \
		i=$$((i + 1)); \
		case $$((i % 4)) in \
			0) spinner='|' ;; \
			1) spinner='/' ;; \
			2) spinner='-' ;; \
			3) spinner='\'  ;; \
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
	@if command -v virsh >/dev/null 2>&1; then \
		for domain in $$(virsh -c qemu:///system list --all --name 2>/dev/null | grep -E 'p1_iargence(S|SW)'); do \
			printf "$(YELLOW)Removing libvirt domain: %s$(NC)\n" "$$domain"; \
			virsh -c qemu:///system destroy "$$domain" >/dev/null 2>&1 || true; \
			virsh -c qemu:///system undefine "$$domain" --remove-all-storage >/dev/null 2>&1 || true; \
		done; \
	fi
	@if [ -f $(P1_DIR)/shared/token ]; then \
		rm -f $(P1_DIR)/shared/token; \
		printf "$(GREEN)Removed leftover token: $(P1_DIR)/shared/token$(NC)\n"; \
	else \
		printf "$(GREEN)No leftover token found.$(NC)\n"; \
	fi
	@mkdir -p $(P1_DIR)/shared
	@chmod 777 $(P1_DIR)/shared

p1-tests:
	@printf "$(PURPLE)Running p1 tests...$(NC)\n"
	@run_cmd() { \
		cmd="$$1"; \
		printf "\n$(YELLOW)command ran : [%s]$(NC)\n" "$$cmd"; \
		output=$$(eval "$$cmd" 2>&1); \
		status=$$?; \
		if [ -n "$$output" ]; then printf "%s\n" "$$output"; else printf "(no output)\n"; fi; \
		printf "$(GREEN)exit status : [%d]$(NC)\n" "$$status"; \
		return 0; \
	}; \
	run_cmd "grep -E 'config\\.vm\\.define|vm\\.hostname|192\\.168\\.56\\.110|192\\.168\\.56\\.111' $(P1_DIR)/vagrantfile"; \
	run_cmd "cd $(P1_DIR) && vagrant status"; \
	run_cmd "cd $(P1_DIR) && vagrant ssh iargenceS -c 'hostname; ip -br addr; systemctl is-active k3s' && vagrant ssh iargenceSW -c 'hostname; ip -br addr; systemctl is-active k3s-agent'"; \
	run_cmd "cd $(P1_DIR) && vagrant ssh iargenceS -c 'kubectl get nodes -o wide'"; \
	run_cmd "cd $(P1_DIR) && vagrant ssh iargenceS -c 'kubectl get pods -A -o wide'"

# P2 rules

p2: reset-p2
	@printf "$(PURPLE)$(BLINK)Starting p2 Vagrant environment...$(NC)\n"
	@log_file="$(P2_LOG)"; \
	status_file="/tmp/p2-vagrant-up.$$$$.status"; \
	rm -f "$$log_file" "$$status_file"; \
	(cd $(P2_DIR) && vagrant up > vagrant-up.log 2>&1; printf "%s" "$$?" > "$$status_file") & pid=$$!; \
	i=0; \
	while [ ! -s "$$status_file" ]; do \
		i=$$((i + 1)); \
		case $$((i % 4)) in \
			0) spinner='|' ;; \
			1) spinner='/' ;; \
			2) spinner='-' ;; \
			3) spinner='\'  ;; \
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

p2-tests:
	@printf "$(PURPLE)Running p2 tests...$(NC)\n"
	@run_cmd() { \
		cmd="$$1"; \
		printf "\n$(YELLOW)command ran : [%s]$(NC)\n" "$$cmd"; \
		output=$$(eval "$$cmd" 2>&1); \
		status=$$?; \
		if [ -n "$$output" ]; then printf "%s\n" "$$output"; else printf "(no output)\n"; fi; \
		printf "$(GREEN)exit status : [%d]$(NC)\n" "$$status"; \
		return 0; \
	}; \
	run_cmd "grep -E 'config\\.vm\\.define|vm\\.hostname|192\\.168\\.56\\.110' $(P2_DIR)/Vagrantfile"; \
	run_cmd "grep -E 'name: app[123]|replicas: 3|name: webapps|host: app[123]\\.com|defaultBackend' $(P2_DIR)/confs/apps.yaml"; \
	run_cmd "cd $(P2_DIR) && vagrant status"; \
	run_cmd "cd $(P2_DIR) && vagrant ssh maparigiS -c 'hostname && ip -br addr && systemctl is-active k3s'"; \
	run_cmd "cd $(P2_DIR) && vagrant ssh maparigiS -c 'kubectl get nodes -o wide'"; \
	run_cmd "cd $(P2_DIR) && vagrant ssh maparigiS -c 'kubectl get pods,deployments,services,ingress -o wide'"; \
	run_cmd "cd $(P2_DIR) && vagrant ssh maparigiS -c 'curl -s -H \"Host: app1.com\" http://192.168.56.110; printf \"\\n\"; curl -s -H \"Host: app2.com\" http://192.168.56.110; printf \"\\n\"; curl -s -H \"Host: unknown.com\" http://192.168.56.110; printf \"\\n\"; curl -s http://192.168.56.110'"

# P3 rules

p3:
	@printf "$(PURPLE)$(BLINK)Starting p3 K3d/Argo CD setup...$(NC)\n"
	@log_file="$(P3_LOG)"; \
	status_file="/tmp/p3-setup.$$$$.status"; \
	rm -f "$$log_file" "$$status_file"; \
	(cd $(P3_DIR) && GIT_REPO_URL="$(GIT_REPO_URL)" ./scripts/setup.sh > setup.log 2>&1; printf "%s" "$$?" > "$$status_file") & pid=$$!; \
	i=0; \
	while [ ! -s "$$status_file" ]; do \
		i=$$((i + 1)); \
		case $$((i % 4)) in \
			0) spinner='|' ;; \
			1) spinner='/' ;; \
			2) spinner='-' ;; \
			3) spinner='\'  ;; \
		esac; \
		printf "\r$(YELLOW)[%s] p3 setup is running... log: %s$(NC)" "$$spinner" "$$log_file"; \
		sleep 1; \
	done; \
	wait $$pid; \
	status=$$(cat "$$status_file"); \
	rm -f "$$status_file"; \
	printf "\r\033[K"; \
	if [ "$$status" -eq 0 ]; then \
		printf "$(GREEN)Done. p3 setup output saved to %s$(NC)\n" "$$log_file"; \
	else \
		printf "$(RED)p3 setup failed. See %s$(NC)\n" "$$log_file"; \
	fi; \
	exit "$$status"

p3-tests:
	@printf "$(PURPLE)Running p3 tests...$(NC)\n"
	@run_cmd() { \
		cmd="$$1"; \
		printf "\n$(YELLOW)command ran : [%s]$(NC)\n" "$$cmd"; \
		output=$$(eval "$$cmd" 2>&1); \
		status=$$?; \
		if [ -n "$$output" ]; then printf "%s\n" "$$output"; else printf "(no output)\n"; fi; \
		printf "$(GREEN)exit status : [%d]$(NC)\n" "$$status"; \
		return 0; \
	}; \
	run_cmd "test -f $(P3_DIR)/scripts/install_tools.sh && test -f $(P3_DIR)/scripts/setup.sh && test -f $(P3_DIR)/confs/argocd/application.yaml.tpl && test -f $(P3_DIR)/confs/app/deployment.yaml"; \
	run_cmd "command -v docker && command -v k3d && command -v kubectl"; \
	run_cmd "docker info >/dev/null && k3d cluster list iot-p3"; \
	run_cmd "kubectl get ns && kubectl get pods,applications -n argocd -o wide"; \
	run_cmd "kubectl get pods,deployments,services,ingress -n dev -o wide"; \
	run_cmd "kubectl -n dev rollout status deployment/playground --timeout=30s"; \
	run_cmd "kubectl -n dev get deployment playground -o jsonpath='{.spec.template.spec.containers[0].image}'; printf '\\n'; curl -s http://localhost:8888/"

# Bonus rules

bonus:
	@printf "$(PURPLE)$(BLINK)Starting bonus GitLab/Argo CD setup...$(NC)\n"
	@log_file="$(BONUS_LOG)"; \
	status_file="/tmp/bonus-setup.$$$$.status"; \
	rm -f "$$log_file" "$$status_file"; \
	(cd $(BONUS_DIR) && ./scripts/setup.sh > setup.log 2>&1; printf "%s" "$$?" > "$$status_file") & pid=$$!; \
	i=0; \
	while [ ! -s "$$status_file" ]; do \
		i=$$((i + 1)); \
		case $$((i % 4)) in \
			0) spinner='|' ;; \
			1) spinner='/' ;; \
			2) spinner='-' ;; \
			3) spinner='\'  ;; \
		esac; \
		printf "\r$(YELLOW)[%s] bonus setup is running... log: %s$(NC)" "$$spinner" "$$log_file"; \
		sleep 1; \
	done; \
	wait $$pid; \
	status=$$(cat "$$status_file"); \
	rm -f "$$status_file"; \
	printf "\r\033[K"; \
	if [ "$$status" -eq 0 ]; then \
		printf "$(GREEN)Done. bonus setup output saved to %s$(NC)\n" "$$log_file"; \
	else \
		printf "$(RED)bonus setup failed. See %s$(NC)\n" "$$log_file"; \
	fi; \
	exit "$$status"

bonus-tests:
	@printf "$(PURPLE)Running bonus tests...$(NC)\n"
	@run_cmd() { \
		cmd="$$1"; \
		printf "\n$(YELLOW)command ran : [%s]$(NC)\n" "$$cmd"; \
		output=$$(eval "$$cmd" 2>&1); \
		status=$$?; \
		if [ -n "$$output" ]; then printf "%s\n" "$$output"; else printf "(no output)\n"; fi; \
		printf "$(GREEN)exit status : [%d]$(NC)\n" "$$status"; \
		return 0; \
	}; \
	run_cmd "test -f $(BONUS_DIR)/scripts/install_tools.sh && test -f $(BONUS_DIR)/scripts/setup.sh && test -f $(BONUS_DIR)/confs/gitlab/values.yaml && test -f $(BONUS_DIR)/confs/argocd/application.yaml.tpl && test -f $(BONUS_DIR)/confs/app/deployment.yaml"; \
	run_cmd "command -v docker && command -v k3d && command -v kubectl && command -v helm"; \
	run_cmd "docker info >/dev/null && k3d cluster list iot-bonus"; \
	run_cmd "kubectl get ns"; \
	run_cmd "kubectl get pods -n gitlab -o wide"; \
	run_cmd "kubectl get pods,applications -n argocd -o wide"; \
	run_cmd "kubectl get pods,deployments,services,ingress -n dev -o wide"; \
	run_cmd "kubectl -n dev rollout status deployment/playground --timeout=30s"; \
	run_cmd "curl -s -H 'Host: playground.127.0.0.1.nip.io' http://localhost:8080/"

clean-bonus:
	@printf "$(RED)$(BLINK)Cleaning up bonus K3d cluster...$(NC)\n"
	@(cd $(BONUS_DIR) && ./scripts/cleanup.sh) || true
	@rm -f $(BONUS_LOG)
	@printf "$(GREEN)$(BLINK)Done.$(NC)\n"

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
	@if command -v virsh >/dev/null 2>&1; then \
		for domain in $$(virsh -c qemu:///system list --all --name 2>/dev/null | grep -E 'p2_maparigiS'); do \
			printf "$(YELLOW)Removing libvirt domain: %s$(NC)\n" "$$domain"; \
			virsh -c qemu:///system destroy "$$domain" >/dev/null 2>&1 || true; \
			virsh -c qemu:///system undefine "$$domain" --remove-all-storage >/dev/null 2>&1 || true; \
		done; \
	fi

clean-p2: reset-p2
	@printf "$(RED)$(BLINK)Cleaning up p2 Vagrant logs and config files...$(NC)\n"
	@rm -rf $(P2_DIR)/.vagrant $(P2_DIR)/*.log
	@printf "$(GREEN)$(BLINK)Done.$(NC)\n"

clean-p3:
	@printf "$(RED)$(BLINK)Cleaning up p3 K3d cluster...$(NC)\n"
	@(cd $(P3_DIR) && ./scripts/cleanup.sh) || true
	@rm -f $(P3_LOG)
	@printf "$(GREEN)$(BLINK)Done.$(NC)\n"

clean: clean-p1 clean-p2 clean-p3 clean-bonus
