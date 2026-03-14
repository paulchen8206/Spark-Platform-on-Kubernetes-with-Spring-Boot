# Spark Job Service

Spring Boot service that accepts REST requests and launches Spark jobs using `spark-submit`.

## Installation

For prerequisites and repository-level setup, see [Installation](../README.md#installation).

## What This Module Does

- Exposes job launcher APIs under `/v1/spark-jobs`.
- Exposes job execution query APIs under `/v1/spark-jobs/executions`.
- Supports multiple job request DTOs:
  - [SalesReportJobLaunchRequest](src/main/java/com/ksoot/spark/dto/SalesReportJobLaunchRequest.java)
  - [LogsAnalysisJobLaunchRequest](src/main/java/com/ksoot/spark/dto/LogsAnalysisJobLaunchRequest.java)
  - [SparkExampleJobLaunchRequest](src/main/java/com/ksoot/spark/dto/SparkExampleJobLaunchRequest.java)
- Uses [SparkSubmitJobLauncher](src/main/java/com/ksoot/spark/launcher/SparkSubmitJobLauncher.java) to build and execute `spark-submit` commands.

## Configuration

Primary config files:
- [application.yml](src/main/resources/config/application.yml)
- [application-local.yml](src/main/resources/config/application-local.yml)
- [application-minikube.yml](src/main/resources/config/application-minikube.yml)

Key properties:
- `spark.*`: common Spark runtime settings.
- `spark-launcher.persist-jobs`: enables/disables execution history APIs.
- `spark-launcher.capture-jobs-logs`: streams child job logs into this service logs.
- `spark-launcher.jobs.*`: per-job launcher settings (`main-class-name`, `jar-file`, job-specific env/spark config).

The default HTTP port is `8090`.

## Running Locally

Ensure launcher scripts are executable:

```bash
chmod -R +x cmd/*
```

### Local Profile

1. Start infrastructure as documented in [Docker Compose](../README.md#docker-compose).
2. Build artifacts so referenced jars exist in local Maven repository.
3. Run with local profile:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

You can also run [SparkJobService.java](src/main/java/com/ksoot/spark/SparkJobService.java) from IDE.

### Minikube Profile

1. Prepare Minikube infra as documented in [Preparing for Minikube](../README.md#preparing-for-minikube).
2. Update `spark.master` in [application-minikube.yml](src/main/resources/config/application-minikube.yml) using current `kubectl cluster-info` endpoint.
3. Run with minikube profile:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=minikube
```

Swagger UI:
- http://localhost:8090/swagger-ui/index.html?urls.primaryName=Spark+Jobs

## API Reference

### Start Spark Job

```http
POST /v1/spark-jobs/start
```

Example:

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

`correlationId` can be provided optionally; if omitted, the service generates one.

### Stop Spark Job

```http
POST /v1/spark-jobs/stop/{correlationId}
```

Example:

```bash
curl -X POST 'http://localhost:8090/v1/spark-jobs/stop/71643ba2-1177-4e10-a43b-a21177de1022'
```

### Job Execution Query APIs

These endpoints are enabled only when `spark-launcher.persist-jobs=true`.

```http
GET /v1/spark-jobs/executions
GET /v1/spark-jobs/executions/{jobName}
GET /v1/spark-jobs/executions/{jobName}/running
GET /v1/spark-jobs/executions/{jobName}/latest
GET /v1/spark-jobs/executions/latest?jobNames=sales-report-job&jobNames=logs-analysis-job
GET /v1/spark-jobs/executions/job-names
GET /v1/spark-jobs/executions/count
GET /v1/spark-jobs/executions/count/{jobName}
GET /v1/spark-jobs/executions/count-running
GET /v1/spark-jobs/executions/count-by-correlation-id/{correlationId}
GET /v1/spark-jobs/executions/by-correlation-id/{correlationId}
```

## Build

```bash
mvn clean install
```

## Testing

```bash
mvn test
```

## References

- Apache Spark 4.0 docs: https://spark.apache.org/docs/4.0.0
- Running Spark on Kubernetes: https://spark.apache.org/docs/4.0.0/running-on-kubernetes.html
- Spark submit: https://spark.apache.org/docs/4.0.0/submitting-applications.html
- Spring Boot: https://docs.spring.io/spring-boot/index.html

