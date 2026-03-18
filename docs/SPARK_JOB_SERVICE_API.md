# Spark Job Service API Documentation

Detailed API reference for the `spark-job-service` module.

## Base URL

- Local host: `http://localhost:8090`
- In Docker Compose network (from another container): `http://spark-job-service:8090`

## API Discovery

- OpenAPI JSON: `GET /v3/api-docs`
- Swagger UI: `GET /swagger-ui/index.html?urls.primaryName=Spark+Jobs`

## Job Submit APIs

### Start Spark Job

```http
POST /v1/spark-jobs/start
Content-Type: application/json
```

Accepted request models:

- `SalesReportJobLaunchRequest`
- `LogsAnalysisJobLaunchRequest`
- `SparkExampleJobLaunchRequest`

#### Sales Report Example

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

#### Logs Analysis Example

```bash
curl -X POST 'http://localhost:8090/v1/spark-jobs/start' \
  -H 'Content-Type: application/json' \
  -d '{
    "jobName": "logs-analysis-job"
  }'
```

Typical success response:

- HTTP `202 Accepted`
- Response body contains generated or provided `correlationId`

Notes:

- `correlationId` is optional in the request. If omitted, the service generates one.
- `sparkConfigs` can be supplied to override Spark properties per request.

### Stop Spark Job

```http
POST /v1/spark-jobs/stop/{correlationId}
```

Example:

```bash
curl -X POST 'http://localhost:8090/v1/spark-jobs/stop/71643ba2-1177-4e10-a43b-a21177de1022'
```

Typical success response:

- HTTP `202 Accepted`

## Job Execution Query APIs

These APIs are available only when:

- `spark-launcher.persist-jobs=true`

If persistence is disabled, execution endpoints may be unavailable.

### List and filter

```http
GET /v1/spark-jobs/executions
GET /v1/spark-jobs/executions/{jobName}
GET /v1/spark-jobs/executions/{jobName}/running
GET /v1/spark-jobs/executions/by-correlation-id/{correlationId}
```

Query parameters for paged endpoints:

- `page` (default `0`)
- `size` (default `10`)
- `sort` (repeatable)

### Latest executions

```http
GET /v1/spark-jobs/executions/{jobName}/latest
GET /v1/spark-jobs/executions/latest?jobNames=sales-report-job&jobNames=logs-analysis-job
```

### Names and counts

```http
GET /v1/spark-jobs/executions/job-names
GET /v1/spark-jobs/executions/count
GET /v1/spark-jobs/executions/count/{jobName}
GET /v1/spark-jobs/executions/count-running
GET /v1/spark-jobs/executions/count-by-correlation-id/{correlationId}
```

## JobExecution Response Fields

`JobExecution` payloads include:

- `jobName`
- `executionId`
- `correlationId`
- `status`
- `startTime`
- `endTime`
- `duration`
- `exitMessage`
- `errorMessage`
- `arguments`

## Quick Workflow (curl)

1. Submit a job and capture the correlation id from the response.
2. For long-running/streaming jobs, monitor service logs and Spark UI.
3. Stop with `POST /v1/spark-jobs/stop/{correlationId}` when done.

## Related Docs

- Module overview: `spark-job-service/README.md`
- OpenAPI source in repo: `spark-job-service/api-spec/spark-jobs-openapi.json`
- Root project docs: `README.md`
