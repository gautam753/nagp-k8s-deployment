# Usefule commands and notes

- **rollout status:** kubectl rollout status deployment/user-app-deployment -n nagp-ns
- **rollout history:** kubectl rollout history deployment/user-app-deployment -n nagp-ns
- **Database Schema Check:** 
    kubectl port-forward svc/postgres-app-service -n nagp-ns 5432:5432
    sudo apt update && sudo apt install postgresql-client -y
    psql -h 127.0.0.1 -U nagpdbuser -d nagpdb
- **Extract secret runtime:** kubectl get secret nagp-secret -n nagp-ns -o jsonpath="{.data.PG_USER}" | base64 -d
- **Secrets & configs:** 
    POSTGRES_DB=nagpdb
    POSTGRES_USER=nagpdbuser
    POSTGRES_PASSWORD=nagpdbpassword
    X_API_KEY=nagpH3ZHZkjIG9CtFtircFsniAwCAbr2RXID5pNDrlJkPhQ0IxrerWJRiaB6aSUD

---