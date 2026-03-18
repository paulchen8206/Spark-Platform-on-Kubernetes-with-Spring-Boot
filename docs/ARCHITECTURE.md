# Project Architecture

This document contains project-level runtime and deployment diagrams.

For complementary details, see:

- [Spring Boot Framework](SPRING_BOOT_FRAMEWORK.md) for module framework coverage, service flow, and Spring annotation usage.
- [Design Patterns](DESIGN_PATTERNS.md) for class-diagram-focused pattern documentation.
- [Spark Job Service API](SPARK_JOB_SERVICE_API.md) for endpoint-level behavior.

## Components Diagram (Mermaid)

```mermaid
flowchart LR
  A[Client or Scheduler] --> B[spark-job-service\nSpring Boot REST API]
  B --> C[spark-job-commons\nShared launch and connector logic]
  B --> D[spark-batch-sales-report-job]
  B --> E[spark-stream-logs-analysis-job]

  D --> F[(MongoDB sales input)]
  D --> G[(PostgreSQL)]
  D --> P[(ArangoDB products and reports)]

  E --> I[(Kafka error-logs topic)]
  E --> G

  B --> J[(PostgreSQL task metadata)]
```

## Dataflow Diagram (Mermaid)

```mermaid
flowchart LR
  C[Client] -->|POST /v1/spark-jobs/start| API[spark-job-service]
  API -->|Persist execution metadata| META[(PostgreSQL)]
  API -->|spark-submit| DRV[Spark Driver Pod]
  DRV --> EXE[Spark Executor Pods]

  EXE -->|Batch sales input| MONGO[(MongoDB sales)]
  EXE -->|Batch reference/output| ARANGO[(ArangoDB products and sales_report_YYYY_MM)]
  EXE -->|Structured streaming sink| PG[(PostgreSQL error_logs)]
  EXE -->|Consume stream| KAFKA[(Kafka error-logs topic)]

  API -->|Query execution APIs| C
```

## Deployment Diagram (Mermaid)

```mermaid
flowchart TB
  subgraph K8s[aiks namespace]
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

## End-to-End Architecture Flow (Mermaid)

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

## Local Deployment View (Mermaid)

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

  EX --> Mongo[(MongoDB sales)]
  EX --> Arango[(ArangoDB products and sales_report_YYYY_MM)]
  EX --> Postgres[(PostgreSQL task metadata)]
```

## Deploy Modes View (Mermaid)

```mermaid
flowchart LR
  Start[Job start request] --> Decide{spark.submit.deployMode}

  Decide -->|client/local| Local[spark-submit local\nDriver JVM on service host]
  Decide -->|cluster/k8s| Cluster[spark-submit k8s\nDriver Pod on Kubernetes]

  Local --> LocalExec[Local executors/threads]
  Cluster --> PodExec[Executor pods]

  LocalExec --> Targets[(MongoDB / ArangoDB / PostgreSQL / Kafka)]
  PodExec --> Targets

  note1[local mode\nFast debug, simpler networking]
  note2[cluster mode\nProduction-like scheduling and isolation]

  Local -.-> note1
  Cluster -.-> note2
```
