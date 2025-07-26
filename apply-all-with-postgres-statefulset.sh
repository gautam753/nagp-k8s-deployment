#!/bin/bash

# variables
PROJECT_ID=radiant-raceway-466813-m5
COMPUTE_ZONE=us-central1-a
NAMESPACE=nagp-ns
CLUSTER_NAME=nagp-demo-cluster-v4
timestamp=$(date +%Y%m%d_%H%M%S)
DOCKER_REPOSITORY_URL=goutampaul/nagp-demo-user-service


# set project
gcloud config set project radiant-raceway-466813-m5

# configure zone
gcloud config set compute/zone us-central1-a

mkdir ${timestamp}
chmod 777 ${timestamp}
echo "${timestamp} directory created"

cd ${timestamp}

git clone -b main https://github.com/gautam753/nagp-demo-user-service.git nagp-demo-user-service
echo -e "\nnagp-demo-user-service repo cloned from GitHub"


cd nagp-demo-user-service
chmod 777 *
mvn clean install
cd target
chmod 777 *
cd ..
echo -e "\nnagp-demo-user-service code build completed"


COMMIT_ID=$(git rev-parse HEAD)
echo -e "\nBuilding the Docker image..."
docker login -u goutampaul
docker build --tag $DOCKER_REPOSITORY_URL:$COMMIT_ID .
docker tag $DOCKER_REPOSITORY_URL:$COMMIT_ID $DOCKER_REPOSITORY_URL:latest
echo -e "\nPushing the Docker image to Docker hub Repository"
docker push $DOCKER_REPOSITORY_URL:$COMMIT_ID
docker push $DOCKER_REPOSITORY_URL:latest
echo -e "\nDocker Push to Docker hub Repository Completed -  $DOCKER_REPOSITORY_URL:$COMMIT_ID"
docker logout

cd ../../
pwd


# sed -i 's@CONTAINER_IMAGE@'"$DOCKER_REPOSITORY_URL:$COMMIT_ID"'@' user-service/user-deployment.yaml

# create cluster
gcloud beta container --project "radiant-raceway-466813-m5" clusters create "$CLUSTER_NAME" --zone "us-central1-a" --tier "standard" --no-enable-basic-auth --cluster-version "1.32.4-gke.1415000" --release-channel "regular" --machine-type "e2-medium" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "20" --metadata disable-legacy-endpoints=true --num-nodes "4" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA,JOBSET,CADVISOR,KUBELET,DCGM --enable-ip-alias --network "projects/radiant-raceway-466813-m5/global/networks/default" --subnetwork "projects/radiant-raceway-466813-m5/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --enable-ip-access --security-posture=standard --workload-vulnerability-scanning=disabled --no-enable-google-cloud-access --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --binauthz-evaluation-mode=DISABLED --enable-managed-prometheus --enable-shielded-nodes --shielded-integrity-monitoring --no-shielded-secure-boot --node-locations "us-central1-a"
echo -e "\n'nagp-demo-cluster' GKE cluster created"

# configures kubectl to use the cluster created
gcloud container clusters get-credentials $CLUSTER_NAME

# Namespace
kubectl apply -f nagp-namespace.yaml
echo -e "\nNamespace 'nagp-ns' created"

# NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
echo -e "\n'NGINX Ingress Controller' created"

# ConfigMap
kubectl apply -f configmap/nagp-configmap.yaml
echo -e "\n'nagp-config-map' created"

# secret
kubectl apply -f nagp-secret/nagp-secret.yaml
echo -e "\n'nagp-secret' created"

# postgres-statefulset
kubectl apply -f postgres/postgres-statefulstate.yaml
echo -e "\n'postgres-statefulstate' created"

# postgres-headless-service
kubectl apply -f postgres/postgres-headless-service.yaml
echo -e "\n'postgres-headless-service' created"

# User service dployment setup
kubectl apply -f user-service/user-deployment.yaml
echo -e "\n'user-deployment' created"

# User service service setup
kubectl apply -f user-service/user-service.yaml
echo -e "\nWaiting for pod 'user-app-pod' to be created..."
kubectl wait --for=condition=ready pod -l app=user-app -n=nagp-ns --timeout=30s
echo -e "\n'user-app' pod(s) created"

# Ingress (after NGINX controller is installed)
kubectl apply -f ingress/nagp-ingress.yaml
while [ -z "$(kubectl get ingress nagp-ingress -n nagp-ns -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" ]; do
  echo "Waiting for ingress to get external IP..."
  sleep 5
done
echo -e "\nIngress is ready:"


kubectl get all -n nagp-ns
kubectl get ingress -n nagp-ns -o wide
