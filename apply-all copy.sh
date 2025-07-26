#!/bin/bash

./apply-all-with-postgres-statefulset.sh radiant-raceway-466813-m5 nagp-demo-cluster

# Rolling update user-app-deployment with updated container image
kubectl set image deployment/user-app-deployment user-app-container=goutampaul/nagp-demo-user-service:v1 -n nagp-ns
kubectl rollout status deployment/user-app-deployment -n nagp-ns
kubectl rollout history deployment/user-app-deployment -n nagp-ns



kubectl port-forward svc/postgres-app-service -n nagp-ns 5432:5432
sudo apt update && sudo apt install postgresql-client -y
psql -h 127.0.0.1 -U nagpdbuser -d nagpdb
CREATE SCHEMA userschema AUTHORIZATION nagpdbuser;
GRANT USAGE, CREATE ON SCHEMA userschema TO nagpdbuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA userschema GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO nagpdbuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA userschema GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO nagpdbuser;
kubectl get secret nagp-secret -n nagp-ns -o jsonpath="{.data.PG_USER}" | base64 -d

POSTGRES_DB=nagpdb
POSTGRES_USER=nagpdbuser
POSTGRES_PASSWORD=nagpdbpassword
X_API_KEY=nagpH3ZHZkjIG9CtFtircFsniAwCAbr2RXID5pNDrlJkPhQ0IxrerWJRiaB6aSUD