# Spark on Kubernetes End-to-End with Spring Boot

End-to-end reference project for launching and managing Apache Spark jobs from Spring Boot, with local development and Kubernetes deployment support.

This repository includes:
- A Spark job launcher service (`spark-job-service`) with REST APIs to start, stop, and track jobs.
- Two sample Spark jobs:
  - Batch: `spark-batch-sales-report-job`
  - Streaming: `spark-stream-logs-analysis-job`
- Shared Spark/job utilities in `spark-job-commons`.
- Infrastructure definitions for Docker Compose, Kubernetes manifests, and Helm.

## Project Modules

- [`spark-job-service`](spark-job-service/README.md): REST API service that builds and runs `spark-submit` commands.
- [`spark-job-commons`](spark-job-commons/README.md): Shared components used by Spark jobs.
- [`spark-batch-sales-report-job`](spark-batch-sales-report-job/README.md): Sample batch pipeline.
- [`spark-stream-logs-analysis-job`](spark-stream-logs-analysis-job/README.md): Sample streaming pipeline.

## Installation

### Prerequisites

- Java 21
- Maven 3.9+
- Docker and Docker Compose
- Optional for Kubernetes workflows:
  - `kubectl`
  - Minikube
  - Helm 3

### Build all modules

From repository root:

```bash
mvn clean install
```

## Local Development

### Makefile Happy Path

Use the root `Makefile` to run the most common local Kubernetes flow:

```bash
make minikube-start
make build images
make namespace secrets \
  PLATFORM_POSTGRES_PASSWORD='<set-postgres-password>' \
  PLATFORM_ARANGO_ROOT_PASSWORD='<set-arango-password>' \
  PLATFORM_CDK_ADMIN_PASSWORD='<set-admin-password>' \
  PLATFORM_CONDUKTOR_ANALYST_PASSWORD='<set-analyst-password>'
make deploy rollout-status
make smoke
```

To see all available operational targets:

```bash
make help
```

If `kubectl port-forward -n ksoot svc/spark-job-service 8090:8090` is unstable on your machine, prefer the in-cluster smoke commands (`make smoke`) for job submission and validation.

### Docker Compose

Start local infrastructure:

```bash
export CDK_ADMIN_PASSWORD='<set-admin-password>'
export CDK_ANALYST_PASSWORD='<set-analyst-password>'
export DATABASE_PASSWORD='<set-postgres-password>'
export POSTGRES_PASSWORD='<set-postgres-password>'
export ARANGO_ROOT_PASSWORD='<set-arango-password>'
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml ps
```

Main local endpoints from [`docker/docker-compose.yml`](docker/docker-compose.yml):
- Conduktor UI: http://localhost:8081
- Kafka UI: http://localhost:8100
- Kafka broker (host): `localhost:9092`
- PostgreSQL: `localhost:5432`
- MongoDB: `localhost:27017`
- ArangoDB: `localhost:8529`

Notes:
- If required by your workflow, create databases `spark_jobs_db` and `error_logs_db` and Kafka topics `job-stop-requests` and `error-logs`.
- Ensure required ports are available before running Compose.

### Run Services and Jobs

- Run the job launcher service from [`spark-job-service`](spark-job-service/README.md#running-locally).
- Run sample jobs directly from IDE or module-specific instructions:
  - [`spark-batch-sales-report-job`](spark-batch-sales-report-job/README.md)
  - [`spark-stream-logs-analysis-job`](spark-stream-logs-analysis-job/README.md)

`spark-job-service` default port is `8090` (see `spark-job-service/src/main/resources/config/application.yml`).

## Minikube

### Preparing for Minikube

Deploy infrastructure and RBAC:

```bash
kubectl create secret generic platform-secrets -n ksoot \
  --from-literal=postgres-password='<set-postgres-password>' \
  --from-literal=arango-root-password='<set-arango-password>' \
  --from-literal=cdk-admin-password='<set-admin-password>' \
  --from-literal=conduktor-analyst-password='<set-analyst-password>'
kubectl apply -f k8s/infra-kubernetes-deploy.yml
kubectl apply -f k8s/spark-rbac.yml
kubectl config set-context --current --namespace=ksoot
kubectl get pods -n ksoot
```

For local access to `LoadBalancer` services on Minikube, run:

```bash
minikube tunnel
```

### Running on Minikube

- Build images for the modules you want to run.
- Load images into Minikube if needed.
- Deploy `spark-job-service` using [`k8s/deployment.yml`](k8s/deployment.yml) and use its REST APIs.

Detailed steps remain in module READMEs:
- [`spark-job-service`](spark-job-service/README.md)
- [`spark-batch-sales-report-job`](spark-batch-sales-report-job/README.md)
- [`spark-stream-logs-analysis-job`](spark-stream-logs-analysis-job/README.md)

## Kubernetes Configuration Files

- [`k8s/infra-kubernetes-deploy.yml`](k8s/infra-kubernetes-deploy.yml): Namespace (`ksoot`) and infra workloads/services (MongoDB, ArangoDB, PostgreSQL, Zookeeper, Kafka, Kafka UI).
- [`k8s/spark-rbac.yml`](k8s/spark-rbac.yml): Service account and RBAC bindings required by Spark driver/executor pods.
- [`k8s/deployment.yml`](k8s/deployment.yml): Deployment for the Spring Boot job launcher service.

## Helm

Helm chart is under [`helm`](helm). Example install:

```bash
helm install my-release ./helm -f helm/values-dev.yaml \
  --set platformSecrets.existingSecret=platform-secrets
```

Environment-specific values files:
- [`helm/values-dev.yaml`](helm/values-dev.yaml)
- [`helm/values-qa.yaml`](helm/values-qa.yaml)
- [`helm/values-stg.yaml`](helm/values-stg.yaml)
- [`helm/values-prd.yaml`](helm/values-prd.yaml)

## GitHub Actions CI/CD

Workflow: [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml)

Current behavior in workflow:
- Triggers on pushes to `dev`, `testing`, and `stg`.
- Triggers on pull requests targeting `prd`.
- Runs Maven build/tests per environment.
- Contains placeholders/comments for multi-image build/push and deployment expansion.

Required GitHub Environment Secrets (for `qa`, `stg`, and `prd` deployments):
- `PLATFORM_POSTGRES_PASSWORD`
- `PLATFORM_ARANGO_ROOT_PASSWORD`
- `PLATFORM_CDK_ADMIN_PASSWORD`
- `PLATFORM_CONDUKTOR_ANALYST_PASSWORD`
- `KUBECONFIG_QA`
- `KUBECONFIG_STG`
- `KUBECONFIG_PRD`
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`
- `DOCKER_REPO`

Preflight check (requires GitHub CLI `gh` authenticated to this repository):

```bash
required=(
  PLATFORM_POSTGRES_PASSWORD
  PLATFORM_ARANGO_ROOT_PASSWORD
  PLATFORM_CDK_ADMIN_PASSWORD
  PLATFORM_CONDUKTOR_ANALYST_PASSWORD
  KUBECONFIG_QA
  KUBECONFIG_STG
  KUBECONFIG_PRD
  DOCKER_USERNAME
  DOCKER_PASSWORD
  DOCKER_REPO
)

for env in qa stg prd; do
  echo "Checking environment: $env"
  existing=$(gh secret list --env "$env" --json name --jq '.[].name')
  for key in "${required[@]}"; do
    if ! echo "$existing" | grep -qx "$key"; then
      echo "  MISSING: $key"
    fi
  done
done
```

## Configuration Precedence Order

At the project level, configuration precedence follows standard Spring Boot external configuration rules:
- https://docs.spring.io/spring-boot/reference/features/external-config.html

For job launching specifically:
1. Request-level `sparkConfigs` passed to `spark-job-service` APIs (highest precedence)
2. `spark-job-service` deployment/runtime overrides
3. `spark-job-service` application configuration
4. Individual job module defaults (lowest precedence)

## Architecture and Diagrams

### Components Diagram (Mermaid)

```mermaid
flowchart LR
  A[Client or Scheduler] --> B[spark-job-service\nSpring Boot REST API]
  B --> C[spark-job-commons\nShared launch and connector logic]
  B --> D[spark-batch-sales-report-job]
  B --> E[spark-stream-logs-analysis-job]

  D --> F[(MongoDB)]
  D --> G[(PostgreSQL)]
  D --> P[(In-memory product reference)]

  E --> I[(Kafka error-logs topic)]
  E --> G

  B --> J[(PostgreSQL task metadata)]
```

### Deployment Diagram (Mermaid)

```mermaid
flowchart TB
  subgraph K8s[ksoot namespace]
    SVC[spark-job-service Deployment/Service]
    INFRA[(Kafka, Zookeeper, MongoDB, ArangoDB, PostgreSQL, Kafka UI)]
    RBAC[spark ServiceAccount + RBAC]
  end

  USER[Operator or API client] -->|POST /v1/spark-jobs/start| SVC
  SVC -->|spark-submit| DRV[Spark Driver Pod]
  DRV --> EX1[Spark Executor Pod]
  DRV --> EX2[Spark Executor Pod]
  DRV --> INFRA
  EX1 --> INFRA
  EX2 --> INFRA
  RBAC --> DRV
  RBAC --> EX1
  RBAC --> EX2
```

### End-to-End Architecture Flow (Mermaid)

```mermaid
sequenceDiagram
  participant U as User/Client
  participant API as spark-job-service
  participant SP as Spark on Kubernetes
  participant JOB as Spark Job (Batch/Streaming)
  participant DS as Data Stores and Kafka

  U->>API: Submit start request (jobName, args, sparkConfigs)
  API->>API: Resolve effective configuration precedence
  API->>SP: Execute spark-submit
  SP->>JOB: Create driver and executor pods
  JOB->>DS: Read/write datasets and topics
  JOB-->>API: Task execution updates and logs
  API-->>U: Job accepted/status available
```

Design sources are in [`diagrams`](diagrams):
- [`diagrams/Spark_Deploy_Modes.drawio`](diagrams/Spark_Deploy_Modes.drawio)
- [`diagrams/Spark_Deployment_Cluster.drawio`](diagrams/Spark_Deployment_Cluster.drawio)
- [`diagrams/Configurations_Precedence_Order.drawio`](diagrams/Configurations_Precedence_Order.drawio)
- [`diagrams/Spark_deploy_local.drawio`](diagrams/Spark_deploy_local.drawio)

## References

- Apache Spark: https://spark.apache.org/docs/4.0.0
- Running Spark on Kubernetes: https://spark.apache.org/docs/4.0.0/running-on-kubernetes.html
- Spark Submit: https://spark.apache.org/docs/4.0.0/submitting-applications.html
- Spark Configuration: https://spark.apache.org/docs/4.0.0/configuration.html
- Spark Structured Streaming + Kafka: https://spark.apache.org/docs/4.0.0/structured-streaming-kafka-integration.html
- Spring Boot docs: https://docs.spring.io/spring-boot/index.html
- Spring Externalized Configuration: https://docs.spring.io/spring-boot/reference/features/external-config.html