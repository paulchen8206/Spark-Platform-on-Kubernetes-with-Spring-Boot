# Local Development Operations Runbook

This runbook is organized into three distinct end-to-end paths:

- End-to-end A: Docker Compose (local infra + local app runs)
- End-to-end B: Minikube + Kubernetes manifests
- End-to-end C: Helm (optional infra path)

Choose one path and follow it start-to-finish.

## 1. Common Prerequisites

- Java 21
- Maven (`mvn`)
- Docker Desktop
- Optional for Kubernetes paths:
  - `kubectl`
  - Minikube
  - Helm

Useful helper command:

```bash
make help
```

## 2. End-to-End A: Docker Compose

Use this path when you want to run infra locally with Docker Compose and run Spring Boot apps from your machine.

### 2.1 Start Infrastructure

```bash
set -a
source .env
set +a

docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml ps
```

Default local values are in `.env`. Update `.env` before running in shared environments.

### 2.2 Build Artifacts

```bash
mvn clean package -DskipTests
```

### 2.3 Run Spark Job Service Locally

```bash
cd spark-job-service
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

### 2.4 Verify API Availability

In another terminal:

```bash
curl -s -o /tmp/spark_job_service_response.json -w '%{http_code}' http://localhost:8090/v3/api-docs && echo
head -c 220 /tmp/spark_job_service_response.json
```

Expected HTTP status: `200`.

### 2.5 Submit a Job

```bash
curl -X POST 'http://localhost:8090/v1/spark-jobs/start' \
  -H 'Content-Type: application/json' \
  -d '{
    "jobName": "sales-report-job",
    "jobArguments": {
      "month": "2024-11"
    }
  }'
```

### 2.6 Stop a Running Job (Optional)

```bash
curl -X POST 'http://localhost:8090/v1/spark-jobs/stop/<correlation-id>'
```

### 2.7 Cleanup Docker Compose

```bash
docker compose -f docker/docker-compose.yml down
```

## 3. End-to-End B: Minikube + Kubernetes Manifests

Use this path for full Kubernetes execution using the repository manifests.

### 3.1 Quick Path (Makefile)

```bash
make mk-start
make mk-build mk-images
make mk-namespace mk-secrets
make mk-deploy mk-rollout-status
make mk-smoke
```

For teardown:

```bash
make mk-cleanup-all
```

### 3.2 Manual Path

#### 3.2.1 Start Minikube

```bash
minikube start --driver=docker --cpus=4 --memory=6144 -p minikube
kubectl config use-context minikube
kubectl get nodes
```

If needed for `LoadBalancer` services:

```bash
minikube tunnel
```

#### 3.2.2 Build Images in Minikube Docker

```bash
eval "$(minikube -p minikube docker-env)"
mvn clean package -DskipTests

docker build -t ksoot/spark:4.0.0 -f docker/Dockerfile docker
docker build -t spark-job-service:0.0.1 ./spark-job-service
docker build -t spark-batch-sales-report-job:0.0.1 ./spark-batch-sales-report-job
docker build -t spark-stream-logs-analysis-job:0.0.1 ./spark-stream-logs-analysis-job
```

#### 3.2.3 Create Namespace and Secrets

```bash
kubectl create namespace ksoot --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n ksoot -f k8s/platform-secrets-dev.yaml
```

#### 3.2.4 Deploy Infra + RBAC + App

```bash
kubectl apply -f k8s/infra-kubernetes-deploy.yml
kubectl apply -f k8s/spark-rbac.yml
kubectl apply -f k8s/deployment.yml
```

#### 3.2.5 Verify Rollout

```bash
kubectl rollout status deployment/postgres -n ksoot --timeout=300s
kubectl rollout status deployment/kafka-ui -n ksoot --timeout=300s
kubectl rollout status deployment/spark-job-service -n ksoot --timeout=300s
kubectl get pods -n ksoot -o wide
kubectl get svc -n ksoot
```

#### 3.2.6 Submit Jobs (In-cluster, no port-forward needed)

```bash
kubectl run sales-submit --rm -i --restart=Never -n ksoot --image=curlimages/curl:8.10.1 -- \
  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
  -H 'Content-Type: application/json' \
  -d '{"jobName":"sales-report-job","jobArguments":{"month":"2024-08"}}'

kubectl run logs-submit --rm -i --restart=Never -n ksoot --image=curlimages/curl:8.10.1 -- \
  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
  -H 'Content-Type: application/json' \
  -d '{"jobName":"logs-analysis-job"}'

kubectl get pods -n ksoot --sort-by=.metadata.creationTimestamp | tail -n 12
```

#### 3.2.7 Optional API Access via Port Forward

```bash
kubectl port-forward -n ksoot svc/spark-job-service 8090:8090
```

If it fails with exit code `1`:

```bash
kubectl get svc -n ksoot spark-job-service
kubectl get pods -n ksoot -l name=spark-job-service -o wide
lsof -nP -iTCP:8090 -sTCP:LISTEN
SPARK_JOB_SERVICE_POD=$(kubectl get pods -n ksoot -l name=spark-job-service -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n ksoot pod/${SPARK_JOB_SERVICE_POD} 8090:8090
```

#### 3.2.8 Cleanup Minikube Path

```bash
make mk-cleanup
# optional full teardown including minikube profile
make mk-cleanup-all
```

## 4. End-to-End C: Helm (Optional Infra Path)

Use this path when you want Helm-managed platform components (`conduktor`, `postgres`, `kafka`, `zookeeper`).

Note: Helm chart in this repository manages platform infra components, not the `spark-job-service` deployment itself. Keep `k8s/deployment.yml` flow for `spark-job-service`.

### 4.1 Prepare Namespace and Shared Secret

```bash
kubectl create namespace ksoot --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace=ksoot
kubectl apply -n ksoot -f k8s/platform-secrets-dev.yaml
```

### 4.2 Install or Upgrade Helm Release

```bash
helm upgrade --install local-release ./helm -n ksoot -f helm/values-dev.yaml \
  --set platformSecrets.existingSecret=platform-secrets
```

Equivalent target:

```bash
make helm-install
```

### 4.3 Verify Helm Components

```bash
kubectl rollout status deployment/postgres -n ksoot --timeout=300s
kubectl rollout status deployment/zookeeper -n ksoot --timeout=300s
kubectl rollout status deployment/kafka -n ksoot --timeout=300s
kubectl rollout status deployment/conduktor -n ksoot --timeout=300s
kubectl get pods -n ksoot -o wide
kubectl get svc -n ksoot
```

### 4.4 Access Conduktor

```bash
minikube service -n ksoot conduktor --url
```

Credentials source:

- Admin email from `helm/values-dev.yaml` (`conduktor.adminEmail`)
- Admin password from `k8s/platform-secrets-dev.yaml` (`cdk-admin-password`)
- Analyst password from `k8s/platform-secrets-dev.yaml` (`conduktor-analyst-password`)

### 4.5 Deploy/Verify Spark Job Service (if not already running)

```bash
kubectl apply -f k8s/spark-rbac.yml
kubectl apply -f k8s/deployment.yml
kubectl rollout status deployment/spark-job-service -n ksoot --timeout=300s
```

### 4.6 Helm Smoke Checks

```bash
kubectl run kafka-check --rm -i --restart=Never -n ksoot --image=busybox:1.36 -- \
  sh -c 'nc -z kafka 9092 && echo "Kafka reachable"'

kubectl run postgres-check --rm -i --restart=Never -n ksoot --image=postgres:15.15 -- \
  sh -c 'PGPASSWORD=admin psql -h postgres -U conduktor -d conduktor -c "select 1"'
```

### 4.7 Uninstall Helm Release

```bash
helm uninstall local-release -n ksoot
kubectl get all -n ksoot
```
