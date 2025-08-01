# Usefule commands and notes

- **rollout status:** kubectl rollout status deployment/user-app-deployment -n nagp-ns

- **rollout history:** kubectl rollout history deployment/user-app-deployment -n nagp-ns

- **install metric server:** kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

- **Scale deployment**: kubectl scale deployment user-app-deployment --replicas=2 -n nagp-ns

- **apply HPA**: kubectl apply -f hpa/nagp-hpa.yaml

- **POD resourcse utilization**: kubectl top pod -n nagp-ns

- **get pods**: kubectl get pod -n nagp-ns

- **Database Schema Check:** 
    kubectl port-forward svc/postgres-app-service -n nagp-ns 5432:5432
    sudo apt update && sudo apt install postgresql-client -y
    psql -h 127.0.0.1 -U nagpdbuser -d nagpdb
    \dn
    \dt userschema.*
    select * from userschema.users;

- **Extract secret runtime:** kubectl get secret nagp-secret -n nagp-ns -o jsonpath="{.data.PG_USER}" | base64 -d

- **Secrets & configs:** 
    POSTGRES_DB=nagpdb
    POSTGRES_USER=nagpdbuser
    POSTGRES_PASSWORD=nagpdbpassword
    X_API_KEY=nagpH3ZHZkjIG9CtFtircFsniAwCAbr2RXID5pNDrlJkPhQ0IxrerWJRiaB6aSUD

---