# ArgoCD Setup Guide

## Prerequisites

### 1. Setup Credentials

```bash
# 1. Create your credentials file from template
cp .env.credentials.template .env.credentials

# 2. Edit with your actual credentials
nano .env.credentials  # or your preferred editor

# 3. Load credentials into your shell
source .env.credentials

# 4. Verify credentials are loaded
make check-env
```

### 2. Install ArgoCD

```bash
cd argo-cd

helm search repo argo/argo-cd --versions -l | more

helm install dev-argo-cd argo/argo-cd \
--create-namespace \
--version 8.2.5 \
-n argo-cd \
-f argo-helm-values.yaml
```

### 3. Install ArgoCD CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

```


## Setup ArgoCD to be able to talk to Git repos


```bash
# Ensure credentials are loaded
source .env.credentials

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/dev-argo-cd-argocd-server -n argo-cd

# Port forward for CLI access
kubectl port-forward -n argo-cd svc/dev-argo-cd-argocd-server 8880:8080 &

# Login to ArgoCD
argocd login localhost:8880 --username admin --password admin --insecure

# Add repositories
argocd repo add https://github.com/vjkancherla/PetClinic-ArgoCD-ApplicationSets.git --type git
argocd repo add https://github.com/vjkancherla/PetClinic-ArgoCD-ApplicationSets-Deploy.git \
  --type git \
  --username $GITHUB_USERNAME \
  --password $GITHUB_TOKEN

# Create GitHub token secret
kubectl create secret generic github-token \
  --from-literal=token=$GITHUB_TOKEN \
  -n argo-cd

# Deploy applications from PetClinic-ArgoCD-ApplicationSets-Deploy repo
kubectl apply -f petclinic-project.yaml
kubectl apply -f environments-app.yaml
kubectl apply -f applicationsets-app.yaml
```

## Verify Setup

### Check Applications in ArgoCD UI:
- `petclinic-environments` - Should show production application
- `petclinic-applicationsets` - Should show PR preview ApplicationSet
- `petclinic-production` - Should show production deployment

### Test PR Preview Workflow:
1. Create a PR in the source repository
2. Add `preview` label to the PR
3. Check ArgoCD UI for new application: `petclinic-pr-{number}-{hash}`
4. Remove `preview` label to cleanup

### Monitor Jenkins Integration:
1. Merge to main branch should trigger Jenkins
2. Jenkins updates `environments/production/petclinic.yaml`
3. ArgoCD detects change and syncs production

## GitHub Personal Access Token Requirements

Your GitHub PAT needs these permissions:
- `repo` - Full repository access
- `read:org` - Read organization data (for ApplicationSets)
- `read:user` - Read user profile data

## Troubleshooting

### Repository Connection Issues:
Check via ArgoCD UI: Settings > Repositories
- Verify both repositories show "Successful" connection status
- If failed, re-enter credentials or check GitHub PAT permissions

### ApplicationSet Not Detecting PRs:
Check via ArgoCD UI: Applications > ApplicationSets
- Verify `petclinic-pr-previews` ApplicationSet exists
- Check the GitHub token secret exists: `kubectl get secret github-token -n argo-cd`

### Application Sync Issues:
Via ArgoCD UI: Applications
- Click on application name to view details
- Use "Sync" button to force synchronization
- Check "Events" tab for error details