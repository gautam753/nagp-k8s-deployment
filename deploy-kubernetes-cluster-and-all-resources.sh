#!/bin/bash
set -e

# ---------------------- Configuration ----------------------
# Prompt user for inputs
read -p "Enter GCP Project ID: " PROJECT_ID
read -p "Enter Compute Zone [default: us-central1-a]: " COMPUTE_ZONE
COMPUTE_ZONE=${COMPUTE_ZONE:-us-central1-a}  # default value if blank

read -p "Enter Namespace [default: nagp-ns]: " NAMESPACE
NAMESPACE=${NAMESPACE:-nagp-ns}

read -p "Enter GKE Cluster Name to be created [default: nagp-demo-default-cluster]: " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-nagp-demo-cluster-v4}

REPO_URL="https://github.com/gautam753/nagp-demo-user-service.git"
DOCKER_USER_NAME="goutampaul"
DOCKER_REPO="goutampaul/nagp-demo-user-service"
BRANCH="main"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
IMAGE_TAG=""

# ---------------------- Functions ----------------------
function setup_gcloud_config() {
  gcloud config set project "$PROJECT_ID"
  gcloud config set compute/zone "$COMPUTE_ZONE"
}

function clone_and_build_project() {
  mkdir "$TIMESTAMP" && chmod 777 "$TIMESTAMP"
  echo "[INFO] Created working directory: $TIMESTAMP"
  pushd "$TIMESTAMP"

  git clone -b "$BRANCH" "$REPO_URL" project
  echo "[INFO] Cloned repo"

  pushd project
  chmod 777 *
  mvn clean install
  chmod 777 target/*
  echo "[INFO] Build complete"
  popd
  popd
}

function build_and_push_docker_image() {
  pushd "$TIMESTAMP/project"
  COMMIT_ID=$(git rev-parse HEAD)
  IMAGE_TAG=$DOCKER_REPO:$COMMIT_ID
  docker login -u "$DOCKER_USER_NAME"

  docker build -t "$IMAGE_TAG" .
  docker tag "$IMAGE_TAG" "$DOCKER_REPO:latest"

  docker push "$IMAGE_TAG"
  docker push "$DOCKER_REPO:latest"
  docker logout

  echo "[INFO] Docker image pushed: $IMAGE_TAG"
  popd > /dev/null
  echo "$IMAGE_TAG"
}

function create_gke_cluster() {
  gcloud beta container clusters create "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --zone "$COMPUTE_ZONE" \
    --tier standard \
    --cluster-version "1.32.4-gke.1415000" \
    --release-channel "regular" \
    --machine-type "e2-medium" \
    --image-type "COS_CONTAINERD" \
    --disk-type "pd-standard" \
    --disk-size "20" \
    --num-nodes "4" \
    --enable-ip-alias \
    --enable-autoupgrade \
    --enable-autorepair \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
    --enable-managed-prometheus \
    --enable-shielded-nodes \
    --metadata disable-legacy-endpoints=true \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA,JOBSET,CADVISOR,KUBELET,DCGM \
    --network "projects/$PROJECT_ID/global/networks/default" \
    --subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" \
    --default-max-pods-per-node "110" \
    --node-locations "$COMPUTE_ZONE"

  echo "[INFO] GKE cluster '$CLUSTER_NAME' created"
  gcloud container clusters get-credentials "$CLUSTER_NAME"
}

function deploy_kubernetes_resources() {
  echo "[INFO] Creating namespace..."
  kubectl apply -f nagp-namespace.yaml

  echo "[INFO] Installing NGINX ingress controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

  echo "[INFO] Applying ConfigMap..."
  kubectl apply -f configmap/nagp-configmap.yaml

  echo "[INFO] Creating secret..."
  kubectl apply -f nagp-secret/nagp-secret.yaml

  echo "[INFO] Deploying PostgreSQL..."
  kubectl apply -f postgres/postgres-statefulstate.yaml
  kubectl apply -f postgres/postgres-headless-service.yaml

  echo "[INFO] Deploying user service..."
  TEMP_IMAGE_TAG="$IMAGE_TAG"
  echo "[INFO] Deploying image: $TEMP_IMAGE_TAG"
  cp user-service/user-deployment.yaml user-service/user-deployment-temp.yaml
  sed -i "s@CONTAINER_IMAGE@$TEMP_IMAGE_TAG@g" user-service/user-deployment-temp.yaml
  kubectl apply -f user-service/user-deployment.yaml
  rm user-service/user-deployment-temp.yaml
  kubectl apply -f user-service/user-service.yaml

  echo "[INFO] Waiting for user-app pod..."
  kubectl wait --for=condition=ready pod -l app=user-app -n "$NAMESPACE" --timeout=60s

  echo "[INFO] Applying ingress..."
  kubectl apply -f ingress/nagp-ingress.yaml
  wait_for_ingress
}

function wait_for_ingress() {
  echo "[INFO] Waiting for external IP allocation..."
  until kubectl get ingress nagp-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q '[0-9]'; do
    echo "[WAIT] Ingress external IP pending..."
    sleep 5
  done

  echo "[SUCCESS] Ingress is ready:"
  kubectl get ingress -n "$NAMESPACE" -o wide
}

# ---------------------- Execution ----------------------
setup_gcloud_config
clone_and_build_project
IMAGE_TAG=$(build_and_push_docker_image)
sed -i 's@CONTAINER_IMAGE@'"$IMAGE_TAGD"'@' user-service/user-deployment.yaml
create_gke_cluster
deploy_kubernetes_resources

echo -e "\n[INFO] Deployment Summary:"
kubectl get all -n "$NAMESPACE"