# PetClinic GitOps Project

A complete GitOps implementation of the Spring PetClinic application using Jenkins, ArgoCD, and Kubernetes.

## Quick Start
0. [Run PetClinic Locally](docs/-Run-PetClinic-Locally.md)
1. [Initial Setup](docs/00-START-HERE.md)
2. [Environment Setup](docs/01-initial-setup.md)
3. [Daily Usage](docs/02-daily-usage.md)

## Architecture
- **Application**: Spring Boot PetClinic (`app/`)
- **Deployment**: Helm Chart (`helm-chart/`)
- **Infrastructure**: K3D, Jenkins, ArgoCD (`infrastructure/`)
- **CI/CD**: Jenkins Pipeline (`ci/`)

## Documentation
See [docs/](docs/) directory for complete documentation.

## Development Workflow
```bash
# Setup environment
source .env.credentials
make check-env

# Start infrastructure
./infrastructure/k3d/k3d-setup.sh
./infrastructure/argocd/setup-argocd.sh

# Development workflow
# 1. Create feature branch
# 2. Make changes in app/
# 3. Create PR
# 4. Add 'preview' label for preview environment
# 5. Merge for production deployment