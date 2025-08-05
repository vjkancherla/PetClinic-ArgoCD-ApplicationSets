# PetClinic GitOps Project - Complete Setup Guide

This guide provides step-by-step instructions to set up a complete GitOps pipeline using Jenkins, ArgoCD, and Kubernetes (K3d) running locally on your machine using Docker.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Infrastructure Setup](#infrastructure-setup)
4. [Service Deployment](#service-deployment)
5. [Jenkins Configuration](#jenkins-configuration)
6. [ArgoCD Configuration](#argocd-configuration)
7. [Pipeline Creation](#pipeline-creation)
8. [PR Preview Workflow Details](#pr-preview-workflow-details)
9. [Verification](#verification)
10. [Troubleshooting](#troubleshooting)

## Overview

This GitOps project demonstrates a complete CI/CD pipeline with:
- **Jenkins Master** running on Docker
- **Dynamic Kubernetes Agents** on K3d cluster
- **ArgoCD** for GitOps deployments and PR preview environments
- **Container building** with Kaniko
- **Multi-branch pipeline** support
- **Two-label system** for preventing race conditions in PR previews

## Prerequisites

Ensure you have the following installed:
- Docker Desktop
- `kubectl` CLI tool
- `k3d` CLI tool (v5.0.0+ recommended)
- `argocd` CLI tool
- Git
- A DockerHub account and personal access token
- A GitHub account and personal access token

## Repository Structure

```
PetClinic-ArgoCD-ApplicationSets/
├── app/                    # Spring Boot application (pom.xml, Dockerfile, src/)
├── helm-chart/             # Kubernetes deployment manifests
├── infrastructure/         # DevOps infrastructure
│   ├── k3d/               # K3d cluster setup
│   ├── jenkins/           # Jenkins configuration
│   └── argocd/            # ArgoCD setup
├── ci/                    # CI/CD pipeline (Jenkinsfile)
├── docs/                  # Documentation
└── scripts/               # Utility scripts
```

## AUTOMATION

The document details all the manual steps required to setup and run the project. This is good for learning.
However, to speed things up, automation scripts have been created:
- [infrastructure/k3d/k3d-setup.sh](infrastructure/k3d/k3d-setup.sh)
- [infrastructure/k3d/k3d-teardown.sh](infrastructure/k3d/k3d-teardown.sh)
- [infrastructure/argocd/setup-argocd.sh](infrastructure/argocd/setup-argocd.sh)
- [makefile](makefile)

Please refer to the following documents on how to run the automation:
- [docs/01-initial-setup.md](docs/01-initial-setup.md)
- [docs/02-daily-usage.md](docs/02-daily-usage.md)

The automated steps are:
- create docker volume - k3d-data
- start k3d, with volume mapped
- create jenkins namespace
- create K8s PV and PVCs for caching artifacts
- create a K8s secret to be consumed by Kaniko
- prep k3d-kube-config file (for jenkins-to-K3d connectivity)
- start docker services using docker compose
- install and configure ArgoCD with GitOps applications

## Infrastructure Setup

### Step 0: Credentials Setup

⚠️ IMPORTANT: Credential Management
All services require proper authentication. We use a centralized credential management approach:

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

Required credentials:
- **Docker Hub**: Username, password/token, email
- **GitHub**: Username, personal access token

### Step 1: Create K3d Cluster and Network

⚠️ IMPORTANT: Understanding K3d Volumes Architecture
The Jenkins K8s Agent Pods need persistent storage to cache Maven, Kaniko artifacts for performance. Since our Jenkins K8s Agent Pods run on K3D (which runs on Docker), we need a specific storage setup:
Storage Flow: Jenkins Agent Pod → K8s PV (hostPath) → K3d Agent Node → Docker Volume → Local Machine
Why Docker Volumes vs Bind Mounts?

✅ Docker Volumes: Faster I/O performance, better for caching
❌ Bind Mounts: Slower performance, especially on macOS/Windows

This is why we create Docker volumes first, then mount them to K3d agent nodes.

#### 1.1 Create Docker Volume for K3d Data
For better performance, use Docker volumes instead of bind mounts:
```bash
docker volume create k3d-data
```

#### 1.2 Create K3d Cluster
```bash
k3d cluster create mycluster \
  --servers 1 \
  --agents 1 \
  --subnet 172.19.0.0/16 \
  --volume k3d-data:/mnt/data@agent:0 \
  --api-port 6443
```

#### 1.3 Get K3d Server IP and Prepare Kubeconfig
```bash
# Get K3d server IP
K3D_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' k3d-mycluster-server-0)
echo "K3d Server IP: $K3D_IP"

# Prepare kubeconfig for Jenkins
cp ~/.kube/config k3d-kubeconfig
sed -i '' "s|server: .*|server: https://${K3D_IP}:6443|g" k3d-kubeconfig
```

### Step 1.1: Create Jenkins Namespace and Resources

#### Create Jenkins Namespace
```bash
kubectl create ns jenkins
```

### Step 1.2: Create Persistent Volumes and Claims

Create the required PVs and PVCs for Jenkins agent pods:

```bash
# Create Persistent Volumes
kubectl apply -f infrastructure/k3d/k3d-persistence-store.yaml
```

### Step 1.3: Create Kubernetes Secret for DockerHub

Create a secret for Kaniko to push images to DockerHub:
```bash
kubectl create secret -n jenkins docker-registry docker-credentials \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=$DOCKER_USERNAME \
  --docker-password=$DOCKER_PASSWORD \
  --docker-email=$DOCKER_EMAIL
```

## Service Deployment

### Step 2: Create Docker Volumes for Jenkins

```bash
# Create Docker volumes for data persistence
docker volume create jenkins-data
```

### Step 3: Deploy Jenkins

See [infrastructure/jenkins/docker-compose.yaml](infrastructure/jenkins/docker-compose.yaml)

Start the services:
```bash
cd infrastructure/jenkins
docker-compose up -d
```

## Jenkins Configuration

### Step 4: Install Required Jenkins Plugins

Access Jenkins at `http://localhost:8080` and login with:
- Username: `user`
- Password: `bitnami`

Install the following plugins via **Manage Jenkins → Manage Plugins**:

**Essential Plugins:**
- build-timeout:1.38
- build-timestamp
- git-client:6.1.3
- git:5.7.0
- github:1.43.0
- GitHub Branch Source Plugin Version 1834
- kubernetes-client-api:6.10.0-251.v556f5f100500
- kubernetes-credentials:192.v4d5b_1c429d17
- kubernetes:4340.v345364d31a_2a_
- pipeline:608.v67378e9d3db_1
- Pipeline: SCM Step:437.v05a_f66b_e5ef8
- Pipeline: Job:1520.v56d65e3b_4566
- Pipeline: Basic Steps:1079.vce64b_a_929c5a_
- Pipeline: Stage Step:322.vecffa_99f371c
- Pipeline: Multibranch:806.vb_b_688f609ee9
- pipeline-build-step:567.vea_ce550ece97
- pipeline-input-step:517.vf8e782ee645c
- Pipeline: Declarative:2.2255.v56a_15e805f12

**Utility Plugins:**
- ws-cleanup:0.48

### Step 5: Create Jenkins Credentials

Navigate to **Dashboard → Manage Jenkins → Security → Manage Credentials → System → Global credentials**

#### 5.1 Create KubeConfig Credential
- **Kind**: Secret File
- **Secret**: Upload the k3d-kubeconfig file from Step 1.3
- **ID**: `k3d-kubeconfig`
- **Description**: KubConfig File to access K3d Cluster

#### 5.2 Create GitHub Credentials
- **Kind**: Username with password
- **Username**: Your GitHub username (from $GITHUB_USERNAME)
- **Password**: Your GitHub personal access token (from $GITHUB_TOKEN)
- **ID**: `github-credentials`
- **Description**: GitHub access credentials

### Step 6: Configure Agent Security Settings

Navigate to **Manage Jenkins → Security → Agents**:
- Set **TCP port for inbound agents** to: **Fixed (50000)**

### Step 7: Configure Kubernetes Cloud

Navigate to **Dashboard → Manage Jenkins → Manage Nodes and Clouds → Configure Clouds**

1. Click **Add a new cloud** → **Kubernetes**
2. Configure the following:
   - **Name**: `k3d-mycluster`
   - **Kubernetes URL**: Leave empty
   - **Disable HTTPS certificate check**: ✅ Enabled
   - **Credentials**: Select your stored `k3d-kubeconfig` credential
   - **Jenkins URL**: `http://THE-MACBOOK-IPAddress:8080` (find with `ifconfig` or `ipconfig`)
   - **Jenkins tunnel**: `THE-MACBOOK-IPAddress:50000`

3. Click **Test Connection** to verify
4. Save the configuration

⚠️ **Important**: Use your machine's actual IP address, not `localhost`. If Jenkins agents fail to connect, see the [Jenkins Agent Connection Troubleshooting](#jenkins-agent-connection-issues) section below.

## ArgoCD Configuration

### Step 8: Install and Configure ArgoCD

For detailed ArgoCD installation and configuration instructions, see:
**[docs/07-argocd-install.md](docs/07-argocd-install.md)**

Quick setup using automation:
```bash
# Ensure credentials are loaded
source .env.credentials

# Run ArgoCD setup script
cd infrastructure/argocd
./setup-argocd.sh
```

This will:
- Install ArgoCD using Helm
- Configure repository access for GitOps
- Set up applications and ApplicationSets
- Create GitHub token secret for PR detection

Access ArgoCD at `http://localhost:9080` with:
- Username: `admin`
- Password: `admin`

## Pipeline Creation

### Step 9: Create Jenkins Agent Pod Template

See [infrastructure/jenkins/jenkins-agent-pod-template.yaml](infrastructure/jenkins/jenkins-agent-pod-template.yaml)

### Step 10: Create Multibranch Pipeline

1. On Jenkins dashboard, click **New Item**
2. Enter name: `PetClinic-GitOps`
3. Select **Multibranch Pipeline**
4. Configure:
   - **Display Name**: Leave empty
   - **Branch Sources**: 
     - Add **GitHub**
     - **Credentials**: Select `github-credentials`
     - **Repository HTTPS URL**: `https://github.com/vjkancherla/PetClinic-ArgoCD-ApplicationSets.git`
     - **Behaviors**:
       - **Discover branches**: `Exclude branches that are also filed as PRs`
       - **Discover pull requests from origin**: `Merging the pull request with the current target branch revision`
       - **Discover pull requests from forks** (Optional): `Merging the pull request with the current target branch revision`
         - **Trust**: `From users with Admin or Write permission`
   - **Build Configuration**: by Jenkinsfile (located at `ci/Jenkinsfile`)
5. Save the configuration

### Jenkins Multibranch Pipeline Discovery Configuration

Configure these behaviors to build only main branch and PRs:

1. **Discover branches**
   - Strategy: `Exclude branches that are also filed as PRs`

2. **Discover pull requests from origin**  
   - Strategy: `Merging the pull request with the current target branch revision`

3. **Discover pull requests from forks** (Optional)
   - Strategy: `Merging the pull request with the current target branch revision`
   - Trust: `From users with Admin or Write permission`

This prevents feature branches from being built directly while ensuring all PRs are detected.

## PR Preview Workflow Details

### Two-Label System for Race Condition Prevention

To prevent image availability issues, we use a two-label coordination system:

1. **Developer adds `preview` label** - Indicates desire for preview environment
2. **Jenkins adds `image-ready` label** - Signals that image is built and pushed
3. **ApplicationSet requires BOTH labels** - Ensures image exists before deployment

### Timeline:
- T+0: PR created, developer adds `preview` label
- T+3-5min: Jenkins builds image and adds `image-ready` label  
- T+5-6min: ArgoCD ApplicationSet detects both labels and deploys
- T+6-8min: Preview environment ready

### Benefits:
- ✅ Eliminates "ImagePullBackOff" errors
- ✅ Guaranteed image availability before deployment
- ✅ Developer-controlled preview requests
- ✅ Automatic cleanup when PR closed

### Workflow Steps:

#### Creating a Preview Environment
1. Create feature branch and make changes
2. Push branch and create Pull Request
3. Add `preview` label to PR
4. Jenkins will build and add `image-ready` label automatically
5. ArgoCD will deploy to `petclinic-pr-{number}` namespace
6. Access via: `kubectl port-forward svc/petclinic 8080:80 -n petclinic-pr-{number}`

#### Cleaning Up Preview Environment  
1. Remove `preview` label from PR, OR
2. Close/merge the PR
3. ArgoCD will automatically remove the application and namespace

#### Production Deployment
1. Merge PR to main branch
2. Jenkins automatically builds and updates ArgoCD application
3. ArgoCD syncs changes to production within 3 minutes
4. Monitor: `kubectl get pods -n petclinic-production -w`

## Verification

### Step 11: Test the Setup

#### 11.1 Test Kubernetes Connectivity
Create a simple test pipeline in Jenkins:

```groovy
pipeline {
  agent {
    kubernetes {
      yamlFile "infrastructure/jenkins/jenkins-agent-pod-template.yaml"
    }
  }
  stages {
    stage('Test') {
      steps {
        container('maven') {
          sh 'mvn -version'
        }
      }
    }
  }
}
```

#### 11.2 Test GitOps Workflow

**Production Deployment:**
1. Make changes to application code in `app/src/`
2. Push to main branch
3. Jenkins automatically builds and updates ArgoCD application spec
4. ArgoCD automatically syncs the new deployment

**PR Preview Environment:**
1. Create feature branch and make changes
2. Create Pull Request
3. Add `preview` label to PR
4. Jenkins builds image with PR-specific tag
5. Jenkins adds `image-ready` label after successful build
6. ArgoCD ApplicationSet creates preview environment
7. Remove label or close PR to cleanup

#### 11.3 Verify Services
Check that all services are running:
```bash
# Check K3d cluster
kubectl get nodes

# Check Jenkins container
docker ps | grep jenkins

# Check ArgoCD
kubectl get pods -n argo-cd

# Check persistent volumes
kubectl get pv,pvc -n jenkins

# Check ArgoCD applications
kubectl get applications -n argo-cd
```

#### 11.4 Access Applications
```bash
# Access production application
kubectl port-forward svc/petclinic 8080:80 -n petclinic-production
# Open http://localhost:8080

# Access preview application (if PR with preview label exists)
kubectl port-forward svc/petclinic 8081:80 -n petclinic-pr-123
# Open http://localhost:8081
```

## Troubleshooting

### Common Issues

#### Jenkins Agent Connection Issues
- Verify the Jenkins URL and tunnel configuration use your machine's IP, not localhost
- Check that port 50000 is accessible
- Ensure the K3d network allows communication

**IMPORTANT: Jenkins Agent Connection Troubleshooting**

If Kubernetes Jenkins agents fail to connect to the Jenkins master, this is usually due to incorrect Jenkins URL or tunnel settings in the Kubernetes cloud configuration.

**Symptoms:**
- Jenkins agents show "connection refused" errors
- Pods start but fail to connect to Jenkins
- Agent pods remain in pending or error state

**Troubleshooting Steps:**
1. **Check Jenkins Cloud Configuration:**
   - Go to Jenkins → Manage Jenkins → Manage Nodes and Clouds → Configure Clouds
   - Verify **Jenkins URL** uses your machine's actual IP (not localhost)
   - Verify **Jenkins tunnel** uses your machine's IP with port 50000
   - Example: `http://192.168.1.100:8080` and `192.168.1.100:50000`

2. **Test Network Connectivity:**
   Create a netshoot pod in the Jenkins namespace to test connectivity:
   ```bash
   # Create test pod
   kubectl run netshoot --image=nicolaka/netshoot -it --rm --restart=Never -n jenkins -- /bin/bash
   
   # Inside the pod, test Jenkins connectivity:
   curl -I http://YOUR-MACHINE-IP:8080
   telnet YOUR-MACHINE-IP 50000
   
   # Check DNS resolution
   nslookup YOUR-MACHINE-IP
   ```

3. **Find Your Machine's IP:**
   ```bash
   # macOS/Linux
   ifconfig | grep inet
   
   # Or use specific interface
   ifconfig en0 | grep inet  # macOS WiFi
   ifconfig eth0 | grep inet # Linux Ethernet
   
   # Windows
   ipconfig
   ```

4. **Verify Jenkins is Accessible:**
   ```bash
   # Test from outside the cluster
   curl -I http://YOUR-MACHINE-IP:8080
   
   # Should return Jenkins headers, not connection refused
   ```

**Common Fixes:**
- Update Jenkins URL from `http://localhost:8080` to `http://YOUR-ACTUAL-IP:8080`
- Update Jenkins tunnel from `localhost:50000` to `YOUR-ACTUAL-IP:50000`
- Ensure Docker Desktop allows external connections
- Check firewall settings on your machine

#### ArgoCD GitOps Issues
- Verify repositories are connected in ArgoCD UI
- Check GitHub token permissions (repo, read:org, read:user)
- Ensure ApplicationSet detects PRs with `preview` label

#### Persistent Volume Issues
- Ensure K3d agent node has the required mount paths
- Verify PV and PVC are bound correctly
- Check that the node selector matches the agent node name

#### Network Connectivity
```bash
# Test network connectivity
docker network inspect k3d-mycluster

# Check container IPs
docker inspect jenkins-docker | grep IPAddress
```

### Useful Commands

```bash
# Restart services
cd infrastructure/jenkins && docker-compose restart

# View logs
docker logs jenkins-docker

# Check ArgoCD applications
kubectl get applications -n argo-cd

# Reset K3d cluster
k3d cluster delete mycluster
# Then follow setup steps again

# Check Jenkins agent pods
kubectl get pods -n jenkins
kubectl logs -f <pod-name> -n jenkins

# Access ArgoCD UI
kubectl port-forward -n argo-cd svc/dev-argo-cd-argocd-server 9080:80
```

For more detailed troubleshooting, see [docs/10-troubleshooting-guide.md](docs/10-troubleshooting-guide.md).