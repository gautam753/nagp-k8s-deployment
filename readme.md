# NAGP Kubernetes Deployment

This repository provides a complete setup to deploy a Spring Boot microservice and PostgreSQL database on Google Kubernetes Engine (GKE). It follows Kubernetes best practices for resource isolation, service exposure, secret management, and CI/CD updates.

---

## 1. Repositories and API Spec

- **Kubernetes manifest Repo:** https://github.com/gautam753/nagp-k8s-deployment.git  
- **User-service Code Repo:** https://github.com/gautam753/nagp-demo-user-service.git  
- **Docker Hub Repo:** https://hub.docker.com/repository/docker/goutampaul/nagp-demo-user-service/general  
- **API Spec (Swagger UI):** http://nagp-demo.example.com/v1/user-service/swagger-ui/index.html

---

## 2. Architecture Overview

- **Namespace:** `nagp-ns`  
    - Logical partitioning in Kubernetes to isolate and manage all resources related to this deployment (Pods, Services, Secrets, etc.).

- **Secrets & ConfigMap:**  
    - `Secrets` store sensitive data such as database credentials in base64-encoded form.  
    - `ConfigMap` manages non-sensitive configuration like environment variables for the Spring Boot app.

- **Database Tier:** PostgreSQL  
    - Deployed using a `StatefulSet` which guarantees the order and uniqueness of Pod names.  
    - Uses `PersistentVolumeClaims (PVC)` for durable storage of database data.

- **API Tier:** Spring Boot Microservice  
    - Deployed as a `Deployment` object for high availability and version control.  
    - Communicates with the database using credentials managed by Secrets and parameters from ConfigMap.

- **Ingress:** NGINX-based Public Access  
    - Routes external HTTP/S traffic to the Spring Boot application using hostname-based routing.  
    - Provides a single entry point for the app with an external IP address.

---

## 3. Project Structure

```bash
.
├── readme.md
├── helper-doc.md
├── deploy-kubernetes-cluster-and-all-resources.sh
├── new-update-deployment-pipeline.sh
├── nagp-namespace.yaml
├── configmap/
│   └── nagp-configmap.yaml
├── nagp-secret/
│   └── nagp-secret.yaml
├── postgres/
│   ├── postgres-headless-service.yaml
│   └── postgres-statefulstate.yaml
├── user-service/
│   ├── user-deployment.yaml
│   └── user-service.yaml
├── hpa/
│   └── nagp-hpa.yaml
└── ingress/
    └── nagp-ingress.yaml
```

---

## 4. Deployment Options

### Kubernetes Cluster Setup and Deployment Guide

This guide provides step-by-step instructions to set up a Kubernetes (GKE) cluster on Google Cloud Platform and deploy a Spring Boot microservice with PostgreSQL using automated shell scripts.

##  Option 1: Steps to Set Up Kubernetes Cluster and Resources from Scratch

###  Upload and Execute Initialization Script
- Upload the `initiate-k8s-cluster-setup.sh` script to **Google Cloud Shell**.
- Run the script to initiate the Kubernetes cluster setup.

###  Script Execution
- The script clones the Kubernetes manifest project `nagp-k8s-deployment` from GitHub.
- It navigates into the cloned repository and executes `deploy-kubernetes-cluster-and-all-resources.sh` to set up the GKE cluster.

###  Script Workflow Overview

#### Step 1: Configuration Setup
- Prompts the user for:
  - GCP Project ID
  - Compute Zone (default: `us-central1-a`)
  - GKE Cluster Name (default: `nagp-demo-cluster-v4`)
  - Kubernetes Namespace (default: `nagp-ns`)
- Configures Google Cloud CLI with the provided project and zone.

#### Step 2: Clone and Build Project
- Clones the GitHub repository: `https://github.com/gautam753/nagp-demo-user-service.git`
- Creates a timestamped working directory.
- Builds the Spring Boot project using Maven (`mvn clean install`).

#### Step 3: Build and Push Docker Image
- Logs into Docker Hub using the provided username.
- Builds a Docker image tagged with the current Git commit ID.
- Pushes both the commit-tagged and `latest` images to Docker Hub.
- Logs out of Docker.

#### Step 4: Create GKE Cluster
- Creates a GKE cluster with:
  - 4 nodes of type `e2-medium`
  - Enabled features: IP aliasing, auto-upgrade, auto-repair, managed Prometheus, shielded nodes
  - Add-ons: Horizontal Pod Autoscaling, HTTP Load Balancing, GCE Persistent Disk CSI Driver
- Logging and monitoring enabled for system and workload components.

#### Step 5: Deploy Kubernetes Resources
- Applies the namespace manifest.
- Installs the NGINX Ingress Controller.
- Sets the Kubernetes context to the specified namespace.
- Applies:
  - ConfigMap for environment configuration
  - Secret for sensitive credentials
  - PostgreSQL StatefulSet and headless service
  - User-service deployment and service
- Waits for the user-service pod to become ready.
- Applies the Ingress resource and waits for external IP allocation.

#### Step 6: Deployment Summary
- Prints the status of all deployed resources using:
  ```bash
  kubectl get all -n <namespace>
  ```

---

### Option 2: Update Spring Boot App Only

##  Steps to Roll Out New Update in User-Service

This section describes how to deploy updates to the user-service application using the `new-update-deployment-pipeline.sh` script.

###  Execute Update Script
- Navigate to the cloned repository `nagp-k8s-deployment`.
- Run the script `new-update-deployment-pipeline.sh` to initiate the update rollout.

###  Script Workflow Overview

#### Step 1: Configuration Setup
- Prompts the user for:
  - GCP Project ID
  - Compute Zone (default: `us-central1-a`)
  - GKE Cluster Name (default: `nagp-demo-cluster-v4`)
  - Kubernetes Namespace (default: `nagp-ns`)
- Configures Google Cloud CLI with the provided project and zone.

#### Step 2: Clone and Build Project
- Clones the latest version of the GitHub repository: `https://github.com/gautam753/nagp-demo-user-service.git`
- Creates a timestamped working directory.
- Builds the Spring Boot project using Maven (`mvn clean install`).

#### Step 3: Build and Push Docker Image
- Logs into Docker Hub using the provided username.
- Builds a Docker image tagged with the current Git commit ID.
- Pushes both the commit-tagged and `latest` images to Docker Hub.
- Logs out of Docker.

#### Step 4: Roll Out New Update
- Prepares a temporary deployment YAML file by replacing the placeholder `CONTAINER_IMAGE` with the newly built image tag.
- Applies the updated deployment manifest to Kubernetes.
- Waits for the deployment rollout to complete.
- Waits for the updated pod to become ready.

#### Step 5: Deployment Summary
- Prints the status of all deployed resources using:
  ```bash
  kubectl get all -n <namespace>
  ```

---

## 5. Features & Internals

### Docker Image Handling

- Tags: `<commit_id>`, `latest`
- Uses DockerHub login within script

### YAML Substitution

- Substitutes `CONTAINER_IMAGE` with new tag:
  ```bash
  sed -i "s@CONTAINER_IMAGE@${IMAGE_TAG}@g" user-service/user-deployment.yaml
  ```

### Rollout Commands

```bash
kubectl rollout status deployment/user-app-deployment -n nagp-ns
kubectl wait --for=condition=ready pod -l app=user-app -n nagp-ns --timeout=60s
```

---

## 6. Post Deployment Validation

```bash
kubectl get all -n nagp-ns
kubectl get ingress -n nagp-ns
```

Use the ingress host to access Swagger UI or APIs.

---

## 7. Prerequisites

- GitHub account
- Maven installed
- Docker installed and authenticated
- Google Cloud account
- Google Cloud SDK (`gcloud`) installed
- Kubernetes CLI (`kubectl`) installed