# NAGP Kubernetes Deployment

This repository provides a complete setup to deploy a Spring Boot microservice and PostgreSQL database on Google Kubernetes Engine (GKE). It follows Kubernetes best practices for resource isolation, service exposure, secret management, and CI/CD updates.

---

# Architecture Overview

- **Namespace:** `nagp-ns`
- **Secrets & ConfigMap:** Manage DB credentials and app config
- **Database Tier:** PostgreSQL (StatefulSet with PVC)
- **API Tier:** Spring Boot microservice
- **Ingress:** NGINX-based public access

---

# Project Structure

```bash
.
├── deploy-kubernetes-cluster-and-all-resources.sh  # Full GKE + App setup
├── new-update-deployment-pipeline.sh               # Only update microservice pipeline
├── nagp-namespace.yaml                             # Namespace
├── configmap/
│   └── nagp-configmap.yaml                         # common config variables
├── nagp-secret/
│   └── nagp-secret.yaml                            # application secrets (base64)
├── postgres/
│   ├── postgres-headless-service.yaml              # Postgres Service definition
│   └── postgres-statefulstate.yaml                 # StatefulSet + PVC
├── user-service/
│   ├── user-deployment.yaml                        # user-app Spring Boot app deployment (template)
│   └── user-service.yaml                           # user-app-service definition
└── ingress/
    └── nagp-ingress.yaml                           # Ingress config
```

---

##  Deployment Options

### Option 1: Full GKE Setup

```bash
chmod +x deploy-kubernetes-cluster-and-all-resources.sh
./deploy-kubernetes-cluster-and-all-resources.sh
```

Prompts:

- GCP Project ID
- Compute zone (default: `us-central1-a`)
- Namespace (default: `nagp-ns`)
- Cluster name (default: `agp-demo-default-cluster`)

### Option 2: Update Spring Boot App Only

```bash
chmod +x new-update-deployment-pipeline.sh
./new-update-deployment-pipeline.sh
```

---

## Features & Internals

### Docker Image Handling

- Docker image is tagged with `goutampaul/nagp-demo-user-service:<commit_id>`
- Also tagged as `latest`
- Login/logout handled inside script

### YAML Image Substitution

- `CONTAINER_IMAGE` placeholder in user-service/user-deployment.yaml
- Replaced using:

```bash
sed -i "s@CONTAINER_IMAGE@${IMAGE_TAG}@g" user-service/user-deployment.yaml
```

### Rollout Wait Logic

```bash
kubectl rollout status deployment/user-app-deployment -n nagp-ns
kubectl wait --for=condition=ready pod -l app=user-app -n nagp-ns --timeout=60s
```

---

## Post Deployment

```bash
kubectl get all -n nagp-ns
kubectl get ingress -n nagp-ns
```

Use the host from ingress to access your API.

---

## Prerequisites

- GitHub active account
- Maven installed
- Docker installed & authenticated with DockerHub
- Google Cloud active account
- Google Cloud SDK (`gcloud`) setup
- Kubernetes CLI (`kubectl`) installed

---

