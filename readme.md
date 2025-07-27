# NAGP Kubernetes Deployment

This repository provides a complete setup to deploy a Spring Boot microservice and PostgreSQL database on Google Kubernetes Engine (GKE). It follows Kubernetes best practices for resource isolation, service exposure, secret management, and CI/CD updates.

---

##  Repositories and API Spec
- **Kubernetes Code Repo:** https://github.com/gautam753/nagp-k8s-deployment.git
- **User-service Code Repo:** https://github.com/gautam753/nagp-demo-user-service.git
- **Docker Hub Repo:** https://hub.docker.com/repository/docker/goutampaul/nagp-demo-user-service/general
- **API Spec (Use Swagger UI):** http://nagp-demo.example.com/v1/user-service/swagger-ui/index.html

---

## Architecture Overview

- **Namespace:** `nagp-ns`
    - Logical partitioning in Kubernetes to isolate and manage all resources related to this deployment (Pods, Services, Secrets, etc.).


- **Secrets & ConfigMap:**
    - `Secrets` store sensitive data such as database credentials in base64-encoded form. `ConfigMap` manages non-sensitive configuration like environment variables for the Spring Boot app.


- **Database Tier:** PostgreSQL
    - Deployed using a `StatefulSet` which guarantees the order and uniqueness of Pod names and uses `PersistentVolumeClaims (PVC)` for durable storage of database data.


- **API Tier:** Spring Boot Microservice
    - Deployed as a `Deployment` object for high availability and version control. Communicates with the database using credentials managed by Secrets and parameters from ConfigMap.


- **Ingress:** NGINX-based Public Access
    - Routes external HTTP/S traffic to the Spring Boot application using hostname-based routing and provides a single entry point for the app with an external IP address.

---

# Project Structure

```bash
.
├── readme.md
├── helper-doc.md
├── deploy-kubernetes-cluster-and-all-resources.sh  # Full GKE + App setup
├── new-update-deployment-pipeline.sh               # Only update microservice pipeline
├── nagp-namespace.yaml                             # Namespace
├── configmap/
│   └── nagp-configmap.yaml                         # Common config variables
├── nagp-secret/
│   └── nagp-secret.yaml                            # Application secrets (base64)
├── postgres/
│   ├── postgres-headless-service.yaml              # Postgres Service definition
│   └── postgres-statefulstate.yaml                 # StatefulSet + PVC
├── user-service/
│   ├── user-deployment.yaml                        # User-app Spring Boot app deployment (template)
│   └── user-service.yaml                           # User-app-service definition
└── ingress/
    └── nagp-ingress.yaml                           # Ingress config
```

---

##  Deployment Options
- **Kubernetes Code Repo:** https://github.com/gautam753/nagp-k8s-deployment.git
- **User-service Code Repo:** https://github.com/gautam753/nagp-demo-user-service.git
- **Docker Hub Repo:** https://hub.docker.com/repository/docker/goutampaul/nagp-demo-user-service/general
- **API Spec (Use Swagger UI):** http://nagp-demo.example.com/v1/user-service/swagger-ui/index.html


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

Use the host from ingress to access API(s).

---

## Prerequisites

- GitHub active account
- Maven installed
- Docker installed & authenticated with DockerHub
- Google Cloud active account
- Google Cloud SDK (`gcloud`) setup
- Kubernetes CLI (`kubectl`) installed

---

