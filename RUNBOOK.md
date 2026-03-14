# Local Development Operations: Minikube (Docker Driver)

This runbook describes day-to-day operations for running this project locally on Kubernetes using Minikube with the Docker driver.

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
minikube start --driver=docker --cpus=6 --memory=12288
kubectl config use-context minikube
kubectl get nodes
```

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

kubectl create secret generic platform-secrets -n ksoot \
  --from-literal=postgres-password='<set-postgres-password>' \
  --from-literal=arango-root-password='<set-arango-password>' \
  --from-literal=cdk-admin-password='<set-admin-password>' \
  --from-literal=conduktor-analyst-password='<set-analyst-password>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

## 5. Deploy Infrastructure and App

```bash
kubectl apply -f k8s/infra-kubernetes-deploy.yml
kubectl apply -f k8s/spark-rbac.yml
kubectl apply -f k8s/deployment.yml
```

Track rollout:

```bash
kubectl get pods -n ksoot
kubectl get svc -n ksoot
kubectl rollout status deployment/spark-job-service -n ksoot
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

## 7. Submit and Stop a Job

Start job:

```bash
curl -X POST 'http://localhost:8090/v1/spark-jobs/start' \
  -H 'Content-Type: application/json' \
  -d '{
    "jobName": "sales-report-job",
    "correlationId": "71643ba2-1177-4e10-a43b-a21177de1022",
    "month": "2024-11"
  }'
```

Stop job:

```bash
curl -X POST 'http://localhost:8090/v1/spark-jobs/stop/71643ba2-1177-4e10-a43b-a21177de1022'
```

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

## 9. Cleanup

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
