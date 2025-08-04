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
  read -p "Press Enter to configure Google Cloud Project and compute zone..."
  echo
  echo "[INFO] Configuring Google Cloud Project and compute zone..."
  gcloud config set project "$PROJECT_ID"
  gcloud config set compute/zone "$COMPUTE_ZONE"
  echo "[INFO] Google Cloud Project and compute zone configured"
  echo
}

function clone_and_build_project() {
  echo
  read -p "Press Enter to Clone and Build project code..."
  echo
  mkdir "$TIMESTAMP" && chmod 777 "$TIMESTAMP"
  echo "[INFO] Created working directory: $TIMESTAMP"
  pushd "$TIMESTAMP"

  git clone -b "$BRANCH" "$REPO_URL" project
  echo "[INFO] Cloned repo"

  pushd project
  chmod 777 *
  mvn clean install
  chmod 777 target/*
  echo "[INFO] Build completed"
  popd
  popd
}

function build_and_push_docker_image() {
  echo
  read -p "Press Enter to Build and Push docker image to DockerHub..."
  echo
  pushd "$TIMESTAMP/project"
  COMMIT_ID=$(git rev-parse HEAD)
  IMAGE_TAG=$DOCKER_REPO:$COMMIT_ID
  
  # Commenting out below line as it require dockerhub access token. Directly using existing image from dockerHube which is pushed during video recording, in method 'deploy_kubernetes_resources()'
  # docker login -u "$DOCKER_USER_NAME"

  docker build -t "$IMAGE_TAG" .
  docker tag "$IMAGE_TAG" "$DOCKER_REPO:latest"

  # Commenting out below lines as it require dockerhub access token. Directly using existing image from dockerHube which is pushed during video recording, in method 'deploy_kubernetes_resources()'
  # docker push "$IMAGE_TAG"
  # docker push "$DOCKER_REPO:latest"
  # docker logout

  echo "[INFO] Docker image pushed: $IMAGE_TAG"
  popd
}



function create_gke_cluster() {
  echo
  read -p "Press Enter to create GKE cluster..."
  echo
  gcloud beta container clusters create "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --zone "$COMPUTE_ZONE" \
    --tier standard \
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
  echo
  read -p "Press Enter to deploy kubernetes resources..."
  echo

  echo "[INFO] Creating namespace..."
  kubectl apply -f nagp-namespace.yaml

  echo
  read -p "Press Enter to install Ingress NGINX Controller..."
  echo

  echo "[INFO] Installing NGINX ingress controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

  CONTEXT_NAME=gke_"$PROJECT_ID"_"$COMPUTE_ZONE"_"$CLUSTER_NAME"
  kubectl config set-context "$CONTEXT_NAME" --namespace="$NAMESPACE"
  kubectl config use-context "$CONTEXT_NAME" --namespace="$NAMESPACE"

  echo
  read -p "Press Enter to deploy configMap..."
  echo

  echo "[INFO] Applying ConfigMap..."
  kubectl apply -f configmap/nagp-configmap.yaml

  echo
  read -p "Press Enter to deploy secret..."
  echo

  echo "[INFO] Creating secret..."
  kubectl apply -f nagp-secret/nagp-secret.yaml

  echo
  read -p "Press Enter to deploy postgres headless service..."
  echo

  echo "[INFO] Deploying PostgreSQL..."
  kubectl apply -f postgres/postgres-statefulstate.yaml
  kubectl apply -f postgres/postgres-headless-service.yaml

  echo
  read -p "Press Enter to deploy user-service..."
  echo

  echo "[INFO] Deploying user service..."
  # using existing image from dockerHube which is pushed during video recording
  TEMP_IMAGE_TAG="goutampaul/nagp-demo-user-service:a89279e157d806bef67fcc7732448b8e7f05b91a"
  echo "[INFO] Deploying image: $TEMP_IMAGE_TAG"
  cp user-service/user-deployment.yaml user-service/user-deployment-temp.yaml
  sed -i "s@CONTAINER_IMAGE@$TEMP_IMAGE_TAG@g" user-service/user-deployment-temp.yaml
  kubectl apply -f user-service/user-deployment-temp.yaml
  rm user-service/user-deployment-temp.yaml
  kubectl apply -f user-service/user-service.yaml

  echo "[INFO] Waiting for user-app pod..."
  kubectl wait --for=condition=ready pod -l app=user-app -n "$NAMESPACE" --timeout=420s

  echo
  read -p "Press Enter to deploy Ingress..."
  echo
  
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
build_and_push_docker_image
create_gke_cluster
deploy_kubernetes_resources

echo -e "\n[INFO] Deployment Summary:"
kubectl get all -n "$NAMESPACE"