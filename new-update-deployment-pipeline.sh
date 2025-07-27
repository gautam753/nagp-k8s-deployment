#!/bin/bash
set -e

# ---------------------- Configuration ----------------------
# Prompt user for inputs
read -p "Enter GCP Project ID: " PROJECT_ID
read -p "Enter Compute Zone [default: us-central1-a]: " COMPUTE_ZONE
COMPUTE_ZONE=${COMPUTE_ZONE:-us-central1-a}  # default value if blank

read -p "Enter Namespace [default: nagp-ns]: " NAMESPACE
NAMESPACE=${NAMESPACE:-nagp-ns}

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
  echo
  read -p "Press Enter to Clone and Build project repo..."
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
  echo "[INFO] Build complete"
  popd
  popd
}

function build_and_push_docker_image() {
  echo
  read -p "Press Enter to Build and Push Docker image to DockerHub..."
  echo
  
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
  popd
}

function rollout_new_update() {
  echo
  read -p "Press Enter to continue to the next step..." key
  echo

  echo "[INFO] Deploying user service..."
  TEMP_IMAGE_TAG="$IMAGE_TAG"
  echo "[INFO] Deploying image: $TEMP_IMAGE_TAG"
  cp user-service/user-deployment.yaml user-service/user-deployment-temp.yaml
  sed -i "s@CONTAINER_IMAGE@$TEMP_IMAGE_TAG@g" user-service/user-deployment-temp.yaml
  kubectl apply -f user-service/user-deployment-temp.yaml
  rm user-service/user-deployment-temp.yaml

  echo "[INFO] Waiting for deployment rollout to complete..."
  kubectl rollout status deployment/user-app-deployment -n "$NAMESPACE" --timeout=60s

  echo "[INFO] Waiting for user-app pod..."
  kubectl wait --for=condition=ready pod -l app=user-app -n "$NAMESPACE" --timeout=60s

  kubectl apply -f user-service/user-service.yaml
}
# ---------------------- Execution ----------------------
setup_gcloud_config
clone_and_build_project
build_and_push_docker_image
rollout_new_update

echo -e "\n[INFO] Deployment Summary:"
kubectl get all -n "$NAMESPACE"