## GitOps Workflow Requirements

### 1. Pull Request Workflow (Preview Environments)
- Developer creates a Pull Request in the source repository
- Jenkins Multi-Branch pipeline is triggered automatically for PR builds
- CI pipeline performs basic tasks:
  - Code checkout
  - Maven compile, test and package
  - Build Docker image with Kaniko using tag: `pr-{number}-{commit}`
  - Publish image to Docker Hub
- **Optional Preview Deployment:**
  - Developer adds `preview` label to PR if preview environment is needed
  - ArgoCD ApplicationSet detects labeled PR and automatically deploys to namespace: `petclinic-pr-{number}`
  - Preview environment is automatically cleaned up when PR is closed or label is removed

### 2. Production Deployment Workflow (Main Branch)
- Code is merged to main branch
- Jenkins Multi-Branch pipeline is triggered automatically
- CI pipeline performs:
  - Code checkout
  - Maven compile, test and package
  - Build Docker image with Kaniko using tag: `main-{build}-{commit}`
  - Publish image to Docker Hub
  - **GitOps Update:** Update ArgoCD Application spec in deploy repository with new image tag
- ArgoCD monitors the deploy repository (not Docker Hub) and automatically syncs production deployment

### 3. ArgoCD Configuration
- **Source Repository:** Contains application code and Helm charts
- **Deploy Repository:** Contains ArgoCD Application specs and ApplicationSets
- **App-of-Apps Pattern:** Bootstrap applications manage environments and ApplicationSets
- **Repository Structure:**
  ```
  environments/
    production/
      petclinic.yaml
  applicationsets/
    petclinic-pr-previews.yaml
  ```
### 5. Authentication & Access
- GitHub Personal Access Token for repository access
- Docker Hub credentials for image publishing
- ArgoCD configured with repository credentials for GitOps operations
- Jenkins uses GitHub credentials for updating deploy repository

### 6. Environment Management
- **Production:** `petclinic-production` namespace, managed via `environments/production/petclinic.yaml`
- **PR Previews:** Dynamic namespaces `petclinic-pr-{number}`, managed via ApplicationSet
- **Access:** Applications accessed via `kubectl port-forward` (no ingress controller)

### 7. Automation Level
- **Fully Automated:** Production deployments on main branch merge
- **On-Demand:** PR preview environments via label-based control
- **Self-Cleaning:** Preview environments automatically removed when PR closed