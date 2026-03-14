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

### Maven Components Organization (Mermaid)

```mermaid
flowchart TB
  Root["root pom.xml\npackaging: pom"]

  Commons["spark-job-commons\npom.xml"]
  Service["spark-job-service\npom.xml"]
  Batch["spark-batch-sales-report-job\npom.xml"]
  Stream["spark-stream-logs-analysis-job\npom.xml"]

  Root --> Commons
  Root --> Service
  Root --> Batch
  Root --> Stream

  Commons --> Service
  Commons --> Batch
  Commons --> Stream

  Service --> Batch
  Service --> Stream
```

### Maven Components Organization (Left-to-Right)

```mermaid
flowchart LR
  Root["root pom.xml"]

  Commons["spark-job-commons"]
  Service["spark-job-service"]
  Batch["spark-batch-sales-report-job"]
  Stream["spark-stream-logs-analysis-job"]

  Root --> Commons
  Root --> Service
  Root --> Batch
  Root --> Stream

  Commons --> Service
  Commons --> Batch
  Commons --> Stream

  Service --> Batch
  Service --> Stream
```

## Installation

### Prerequisites

- Java 21
- Maven 3.9+
- Docker and Docker Compose
- Optional for Kubernetes workflows:
  - `kubectl`
  - Minikube
  - Helm 3

This repository standardizes on system Maven (`mvn`) for builds and packaging.

### Build all modules

From repository root:

```bash
mvn clean install
```

## Local Development

### Makefile Happy Path

Use the root `Makefile` to run the most common local Kubernetes flow:

```bash
make mk-start
make mk-build mk-images
make mk-namespace mk-secrets
make mk-deploy mk-rollout-status
make mk-smoke
```

Default local passwords are defined in [k8s/platform-secrets-dev.yaml](k8s/platform-secrets-dev.yaml). Update that file before running in shared environments.

To see all available operational targets:

```bash
make help
```

### Makefile Usage Reference

Common operations from repository root:

```bash
# Build all project artifacts and images
make mk-build mk-images

# Deploy and verify
make mk-namespace mk-secrets
make mk-deploy mk-rollout-status
make mk-pods mk-services

# Submit smoke jobs (in-cluster)
make mk-smoke

# Host access via port-forward (each in its own terminal)
make mk-port-forward
make mk-port-forward-postgres
make mk-port-forward-kafka-ui
make mk-port-forward-spark-ui

# Cleanup
make mk-cleanup
make mk-cleanup-all
```

If host port-forward is unstable on your machine, prefer the in-cluster smoke commands (`make mk-smoke`) for job submission and validation.

### Docker Compose

Start local infrastructure:

```bash
set -a
source .env
set +a
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml ps
```

Default local values are provided in [.env](.env). Update this file before running in shared environments.

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
kubectl apply -n ksoot -f k8s/platform-secrets-dev.yaml
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

### Helm E2E Quick Path

```bash
kubectl create namespace ksoot --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n ksoot -f k8s/platform-secrets-dev.yaml
helm upgrade --install local-release ./helm -n ksoot -f helm/values-dev.yaml \
  --set platformSecrets.existingSecret=platform-secrets
kubectl get pods -n ksoot -o wide
```

Detailed end-to-end Helm operations (verify, access, smoke checks, upgrade, uninstall):
[`RUNBOOK.md` section 10](RUNBOOK.md#10-helm-alternative-optional).

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

### Configuration Precedence Diagram (Mermaid)

```mermaid
flowchart LR
  A[sales-report-job\napplication.yml\nspark.executor.instances=1]
  B[spark-job-service\napplication.yml\njobs.sales-report-job.spark-config\nspark.executor.instances=2]
  C[spark-job-service\napplication.yml\nspark.executor.instances=3]
  D[spark-job-service\ndeployment.yml args\n--spark.executor.instances=5]
  E[Job start request\nsparkConfigs\nspark.executor.instances=4]
  F[Final effective config\nspark.executor.instances=4]

  A --> B --> C --> D --> E --> F
```

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

### Dataflow Diagram (Mermaid)

```mermaid
flowchart LR
  C[Client] -->|POST /v1/spark-jobs/start| API[spark-job-service]
  API -->|Persist execution metadata| META[(PostgreSQL)]
  API -->|spark-submit| DRV[Spark Driver Pod]
  DRV --> EXE[Spark Executor Pods]

  EXE -->|Batch output| MONGO[(MongoDB monthly_sales_statements_yyyy_mm)]
  EXE -->|Structured streaming sink| PG[(PostgreSQL error_logs)]
  EXE -->|Consume stream| KAFKA[(Kafka error-logs topic)]

  API -->|Query execution APIs| C
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

### Local Deploy View (Mermaid)

```mermaid
flowchart LR
  User[REST client or Scheduler] --> SVC[spark-job-service\nlocal profile]
  Req[SalesReportJobLaunchRequest\nmonth, sparkConfigs] --> SVC

  subgraph Configs[Configuration Inputs]
    C1[spark-job-service\napplication-local.yml]
    C2[M2_REPO jar path]
    C3[SPARK_HOME]
  end

  C1 --> SVC
  C2 --> Submit
  C3 --> Submit

  SVC --> Submit[spark-submit\nmaster=local\ndeployMode=client]

  subgraph JVM["Driver JVM - local process"]
    SS[SparkSession]
    EX[Executor threads]
    JAR[spark-batch-sales-report-job.jar]
  end

  Submit --> SS
  SS --> EX
  JAR --> SS

  EX --> Mongo[(MongoDB sales_report_YYYY_MM)]
  EX --> Postgres[(PostgreSQL task metadata)]
```

### Deploy Modes View (Mermaid)

```mermaid
flowchart LR
  Start[Job start request] --> Decide{spark.submit.deployMode}

  Decide -->|client/local| Local[spark-submit local\nDriver JVM on service host]
  Decide -->|cluster/k8s| Cluster[spark-submit k8s\nDriver Pod on Kubernetes]

  Local --> LocalExec[Local executors/threads]
  Cluster --> PodExec[Executor pods]

  LocalExec --> Targets[(MongoDB / PostgreSQL / Kafka)]
  PodExec --> Targets

  note1[Local mode\nFast debug, simpler networking]
  note2[Cluster mode\nProduction-like scheduling and isolation]

  Local -.-> note1
  Cluster -.-> note2
```


## References

- Apache Spark: https://spark.apache.org/docs/4.0.0
- Running Spark on Kubernetes: https://spark.apache.org/docs/4.0.0/running-on-kubernetes.html
- Spark Submit: https://spark.apache.org/docs/4.0.0/submitting-applications.html
- Spark Configuration: https://spark.apache.org/docs/4.0.0/configuration.html
- Spark Structured Streaming + Kafka: https://spark.apache.org/docs/4.0.0/structured-streaming-kafka-integration.html
- Spring Boot docs: https://docs.spring.io/spring-boot/index.html
- Spring Externalized Configuration: https://docs.spring.io/spring-boot/reference/features/external-config.html