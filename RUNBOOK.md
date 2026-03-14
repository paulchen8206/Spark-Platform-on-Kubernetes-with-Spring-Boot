# Local Development Operations: Minikube (Docker Driver)

This runbook describes day-to-day operations for running this project locally on Kubernetes using Minikube with the Docker driver.

## Quick Makefile Usage

From repository root, these commands cover the standard lifecycle:

```bash
make minikube-start
make build images
make namespace secrets
make deploy rollout-status
make smoke
```

For cleanup:

```bash
make cleanup
make cleanup-all
```

## 1. Prerequisites

- Docker Desktop running
- Minikube installed
- kubectl installed
- Java 21
- Maven (`mvn`)

Optional but useful:
- `jq`
- `watch`

## 2. Start Local Kubernetes (Minikube on Docker)

```bash
minikube start --driver=docker --cpus=4 --memory=6144
kubectl config use-context minikube
kubectl get nodes
```

If Docker Desktop has lower memory available, reduce `--memory` accordingly.

If you need LoadBalancer access locally:

```bash
minikube tunnel
```

Keep `minikube tunnel` running in a separate terminal.

## 3. Build JARs and Container Images

Switch Docker CLI to Minikube's Docker daemon so built images are directly available to the cluster.

```bash
eval "$(minikube -p minikube docker-env)"
```

Build project artifacts:

```bash
mvn clean package -DskipTests
```

Build images used by the Kubernetes manifests:

```bash
docker build -t ksoot/spark:4.0.0 -f docker/Dockerfile docker
docker build -t spark-job-service:0.0.1 ./spark-job-service
docker build -t spark-batch-sales-report-job:0.0.1 ./spark-batch-sales-report-job
docker build -t spark-stream-logs-analysis-job:0.0.1 ./spark-stream-logs-analysis-job
```

Verify images exist:

```bash
docker images | grep -E "spark-job-service|spark-batch-sales-report-job|spark-stream-logs-analysis-job"
```

## 4. Create Namespace and Secrets

Create namespace and platform secret used by infrastructure components.

```bash
kubectl create namespace ksoot --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n ksoot -f k8s/platform-secrets-dev.yaml
```

Edit `k8s/platform-secrets-dev.yaml` if you want different initial passwords.

## 5. Deploy Infrastructure and App

```bash
kubectl apply -f k8s/infra-kubernetes-deploy.yml
kubectl apply -f k8s/spark-rbac.yml
kubectl apply -f k8s/deployment.yml
```

Track rollout:

```bash
kubectl rollout status deployment/postgres -n ksoot --timeout=300s
kubectl rollout status deployment/kafka-ui -n ksoot --timeout=300s
kubectl rollout status deployment/spark-job-service -n ksoot
kubectl get pods -n ksoot -o wide
kubectl get svc -n ksoot
```

## 6. Access Services

Option A: port-forward spark-job-service:

```bash
kubectl port-forward -n ksoot svc/spark-job-service 8090:8090
```

Option B: use LoadBalancer with `minikube tunnel` and service external IPs:

```bash
kubectl get svc -n ksoot
```

Common endpoints:

- Spark Job Service: `http://localhost:8090` (with port-forward)
- Kafka UI: service `kafka-ui` in namespace `ksoot`
- Conduktor: service `conduktor` when deployed via Helm

Kafka UI in-cluster health check:

```bash
kubectl run kafka-ui-check --rm -i --restart=Never -n ksoot --image=busybox:1.36 -- wget -qO- http://kafka-ui:8100/actuator/health
```

Expected:

```json
{"status":"UP","groups":["liveness","readiness"]}
```

Spark Job Service API check (in a separate terminal while port-forward is running):

```bash
curl -s -o /tmp/spark_job_service_response.json -w '%{http_code}' http://localhost:8090/v3/api-docs && echo
head -c 220 /tmp/spark_job_service_response.json
```

Expected HTTP status: `200`.

If `kubectl port-forward` exits with code `1`:

```bash
# Ensure the service and backing pod are healthy
kubectl get svc -n ksoot spark-job-service
kubectl get pods -n ksoot -l name=spark-job-service -o wide

# Check whether local port 8090 is already in use
lsof -nP -iTCP:8090 -sTCP:LISTEN

# If needed, retry using a direct pod target instead of service
SPARK_JOB_SERVICE_POD=$(kubectl get pods -n ksoot -l name=spark-job-service -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n ksoot pod/${SPARK_JOB_SERVICE_POD} 8090:8090
```

If local port-forward remains unreliable, use the in-cluster curl smoke flow in section 7.

## 7. Submit and Stop a Job

Start job:

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

Note: `correlationId` is optional. If not provided, the service generates one.

Stop job:

```bash
curl -X POST 'http://localhost:8090/v1/spark-jobs/stop/71643ba2-1177-4e10-a43b-a21177de1022'
```

Verified in-cluster smoke flow (works without local port-forward):

```bash
# Optional: remove old completed/failed Spark job pods first
kubectl get pods -n ksoot --no-headers \
  | awk '/(sales-report-job|logs-analysis-job)/ && ($3=="Error" || $3=="Completed" || $3=="Failed") {print $1}' \
  | xargs -r kubectl delete pod -n ksoot

# Submit sales batch job
kubectl run sales-submit --rm -i --restart=Never -n ksoot --image=curlimages/curl:8.10.1 -- \
  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
  -H 'Content-Type: application/json' \
  -d '{"jobName":"sales-report-job","jobArguments":{"month":"2024-08"}}'

# Submit logs streaming job
kubectl run logs-submit --rm -i --restart=Never -n ksoot --image=curlimages/curl:8.10.1 -- \
  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
  -H 'Content-Type: application/json' \
  -d '{"jobName":"logs-analysis-job"}'

# Observe pod states
kubectl get pods -n ksoot --sort-by=.metadata.creationTimestamp | tail -n 12
```

Expected smoke result:

- Sales driver pod reaches `Completed`.
- Logs driver pod remains `Running` with executor pods `Running`.

## 8. Logs and Troubleshooting

Check events and pod status:

```bash
kubectl get events -n ksoot --sort-by=.metadata.creationTimestamp
kubectl get pods -n ksoot -o wide
```

Tail service logs:

```bash
kubectl logs -n ksoot deployment/spark-job-service -f
```

If image pull or image not found issues appear:

- Ensure `eval "$(minikube docker-env)"` was used before `docker build`.
- Rebuild the image with the exact tag used by manifests.
- Restart deployment:

```bash
kubectl rollout restart deployment/spark-job-service -n ksoot
```

If `spark-job-service` fails to start due to DB authentication:

```bash
kubectl apply -n ksoot -f k8s/platform-secrets-dev.yaml

kubectl rollout restart deployment/spark-job-service -n ksoot
kubectl rollout status deployment/spark-job-service -n ksoot --timeout=300s
```

## 9. Cleanup

Preferred Makefile command for full teardown:

```bash
make cleanup-all
```

Remove app and infrastructure:

```bash
kubectl delete -f k8s/deployment.yml
kubectl delete -f k8s/spark-rbac.yml
kubectl delete -f k8s/infra-kubernetes-deploy.yml
```

Stop or delete Minikube:

```bash
minikube stop
# or
minikube delete
```

## 10. Helm Alternative (Optional)

If using Helm for Conduktor/Postgres/Kafka/Zookeeper, reuse the same existing secret:

```bash
helm upgrade --install local-release ./helm -f helm/values-dev.yaml \
  --set platformSecrets.existingSecret=platform-secrets
```
