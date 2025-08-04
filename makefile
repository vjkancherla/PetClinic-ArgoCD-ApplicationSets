# K3D Development Environment Automation
# Usage: make <target>

include .env.credentials

# Set defaults if variables not defined
CLUSTER_NAME ?= mycluster
NAMESPACE ?= jenkins
VOLUME_NAME ?= k3d-data

.PHONY: help setup teardown teardown-keep-volume teardown-keep-all status clean check-env kubeconfig

# Default target
help:
	@echo "K3D Development Environment Automation"
	@echo ""
	@echo "Available targets:"
	@echo "  setup              - Full K3D and Jenkins setup"
	@echo "  teardown           - Complete teardown"
	@echo "  teardown-keep-vol  - Teardown but keep data volume"
	@echo "  teardown-keep-all  - Teardown but keep volume and images"
	@echo "  kubeconfig         - Generate/update k3d-kubeconfig file"
	@echo "  status             - Show current status"
	@echo "  clean              - Remove generated files"
	@echo "  check-env          - Check if credentials are loaded"
	@echo "  help               - Show this help"
	@echo ""
	@echo "IMPORTANT: Load credentials first:"
	@echo "  source .env.credentials"

check-env:
	@if [ -z "${DOCKER_USERNAME}" ] || [ -z "${DOCKER_PASSWORD}" ] || [ -z "${DOCKER_EMAIL}" ] || [ -z "${GITHUB_USERNAME}" ] || [ -z "${GITHUB_TOKEN}" ]; then \
		echo "❌ Credentials not loaded!"; \
		echo "Please run: source .env.credentials"; \
		echo ""; \
		echo "If .env.credentials doesn't exist:"; \
		echo "1. cp .env.credentials.template .env.credentials"; \
		echo "2. Edit .env.credentials with your values"; \
		echo "3. source .env.credentials"; \
		echo ""; \
		echo "Required credentials:"; \
		echo "  - DOCKER_USERNAME, DOCKER_PASSWORD, DOCKER_EMAIL"; \
		echo "  - GITHUB_USERNAME, GITHUB_TOKEN"; \
		exit 1; \
	else \
		echo "✅ Credentials loaded successfully"; \
		echo "Docker User: ${DOCKER_USERNAME}"; \
		echo "GitHub User: ${GITHUB_USERNAME}"; \
		echo "GitHub Token: ${GITHUB_TOKEN:0:4}...${GITHUB_TOKEN: -4}"; \
		echo "Cluster: ${CLUSTER_NAME}"; \
		echo "Namespace: ${NAMESPACE}"; \
	fi

# Setup targets
setup: check-env
	@chmod +x infrastructure/k3d/k3d-setup.sh
	./infrastructure/k3d/k3d-setup.sh

setup-argocd: check-env
	@echo "ArgoCD setup script has been removed."
	@echo "Please refer to infrastructure/argocd/README.md for manual setup instructions."

# Teardown targets
teardown:
	@chmod +x infrastructure/k3d/k3d-teardown.sh
	./infrastructure/k3d/k3d-teardown.sh

teardown-keep-vol:
	@chmod +x infrastructure/k3d/k3d-teardown.sh
	./infrastructure/k3d/k3d-teardown.sh --keep-volume

teardown-keep-all:
	@chmod +x infrastructure/k3d/k3d-teardown.sh
	./infrastructure/k3d/k3d-teardown.sh --keep-volume

# Kubeconfig generation
kubeconfig:
	@echo "Generating k3d kubeconfig..."
	@if ! k3d cluster list | grep -q "$(CLUSTER_NAME)"; then \
		echo "❌ Error: Cluster $(CLUSTER_NAME) not found"; \
		echo "Available clusters:"; \
		k3d cluster list; \
		exit 1; \
	fi; \
	K3D_IP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' k3d-$(CLUSTER_NAME)-server-0); \
	if [ -z "$$K3D_IP" ]; then \
		echo "❌ Error: Failed to get K3D server IP"; \
		echo "Tried to inspect: k3d-$(CLUSTER_NAME)-server-0"; \
		echo "Running containers:"; \
		docker ps --format '{{.Names}}'; \
		exit 1; \
	fi; \
	echo "K3d Server IP: $$K3D_IP"; \
	if [ ! -f ~/.kube/config ]; then \
		echo "❌ Error: ~/.kube/config not found"; \
		exit 1; \
	fi; \
	cp ~/.kube/config k3d-kubeconfig; \
	if [[ "$(shell uname)" == "Darwin" ]]; then \
		sed -i '' "s|server: .*|server: https://$$K3D_IP:6443|g" k3d-kubeconfig; \
	else \
		sed -i "s|server: .*|server: https://$$K3D_IP:6443|g" k3d-kubeconfig; \
	fi; \
	echo "✅ Generated k3d-kubeconfig successfully"; \
	echo "📁 File location: ./k3d-kubeconfig"; \
	echo "💡 Remember to update Jenkins credentials with this file"

# Status and utility targets
status:
	@echo "=== K3D Clusters ==="
	@k3d cluster list || echo "No k3d clusters found"
	@echo ""
	@echo "=== Docker Volumes ==="
	@docker volume ls | grep k3d-data || echo "No k3d-data volume found"
	@echo ""
	@echo "=== Jenkins Service ==="
	@if [ -f infrastructure/jenkins/docker-compose.yml ] || [ -f infrastructure/jenkins/docker-compose.yaml ]; then \
		cd infrastructure/jenkins && docker compose ps; \
	else \
		echo "No docker-compose file found in infrastructure/jenkins/"; \
	fi
	@echo ""
	@echo "=== ArgoCD Status ==="
	@kubectl get pods -n argo-cd 2>/dev/null || echo "ArgoCD not installed or not accessible"
	@echo ""
	@echo "=== ArgoCD Applications ==="
	@kubectl get applications -n argo-cd 2>/dev/null || echo "No ArgoCD applications found"
	@echo ""
	@echo "=== Kubernetes Context ==="
	@kubectl config current-context || echo "No kubernetes context set"

clean:
	@echo "Cleaning up generated files..."
	@rm -f k3d-kubeconfig
	@echo "✅ Removed k3d-kubeconfig"
	@echo "Done"