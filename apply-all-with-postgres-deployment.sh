#!/bin/bash

PROJECT_ID=$1
COMPUTE_ZONE=us-central1-a
CLUSTER_NAME=$3

# set project
gcloud config set project $PROJECT_ID

# configure zone
gcloud config set compute/zone us-central1-a

# create cluster
gcloud beta container --project "$PROJECT_ID" clusters create "$CLUSTER_NAME" --zone "us-central1-a" --tier "standard" --no-enable-basic-auth --cluster-version "1.32.4-gke.1415000" --release-channel "regular" --machine-type "e2-medium" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "20" --metadata disable-legacy-endpoints=true --node-pool "$CLUSTER_NAME-node-pool" --num-nodes "4" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA,JOBSET,CADVISOR,KUBELET,DCGM --enable-ip-alias --network "projects/$PROJECT_ID/global/networks/default" --subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --enable-ip-access --security-posture=standard --workload-vulnerability-scanning=disabled --no-enable-google-cloud-access --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --binauthz-evaluation-mode=DISABLED --enable-managed-prometheus --enable-shielded-nodes --shielded-integrity-monitoring --no-shielded-secure-boot --node-locations "us-central1-a"

# configures kubectl to use the cluster created
gcloud container clusters get-credentials $CLUSTER_NAME

# Namespace
kubectl apply -f nagp-namespace.yaml

# NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# ConfigMap
kubectl apply -f configmap/nagp-configmap.yaml

# secret
kubectl apply -f nagp-secret/nagp-secret.yaml

# PostgreSQL setup
kubectl apply -f postgres/postgres-pvc.yaml

#postgres-deployment
kubectl apply -f postgres/postgres-deployment.yaml

# postgres-service
kubectl apply -f postgres/postgres-service.yaml

# User service dployment setup
kubectl apply -f user-service/user-deployment.yaml

# User service service setup
kubectl apply -f user-service/user-service.yaml

# Ingress (after NGINX controller is installed)
kubectl apply -f ingress/nagp-ingress.yaml

kubectl get all -n nagp-ns
kubectl get ingress -n nagp-ns -o wide