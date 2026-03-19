# Spring Boot Framework

This document describes the high-level frameworks and Spring Boot capabilities used by each of the four modules in this project. All modules share a common Spring Boot 3.4.0 parent and Apache Spark 4.0.0 (Scala 2.13).

---

## Module Overview

```mermaid
flowchart LR
    SJS["spark-job-service\nREST API · Actuator\nSpring Kafka producer\nSpring Cloud Task"]
    SJC["spark-job-commons\nShared auto-config library\nSpark session · AOP\nSpring Kafka consumer\nSpring Retry"]
    SALES["spark-batch-sales-report-job\nBatch Spark job\nSpring Cloud Task\nSpring Data MongoDB"]
    STREAM["spark-stream-logs-analysis-job\nStreaming Spark job\nSpring Cloud Task\nSpring Kafka · Spring Retry"]
    SJS -->|"spark-submit\n(REST trigger)"| SALES
    SJS -->|"spark-submit\n(REST trigger)"| STREAM
    SALES -->|depends on| SJC
    STREAM -->|depends on| SJC
    SJS -->|"Kafka stop signal"| SJC
```

---

## Framework Summary by Module

| Framework / Library | spark-job-service | spark-job-commons | spark-batch-sales-report-job | spark-stream-logs-analysis-job |
|---|:---:|:---:|:---:|:---:|
| Spring Boot 3.4.0 | ✓ | ✓ | ✓ | ✓ |
| Spring Boot Web (Tomcat) | ✓ | | | |
| Spring Boot Actuator | ✓ | | | |
| Spring Boot Validation (JSR-303) | ✓ | | ✓ | ✓ |
| Spring Boot HATEOAS | ✓ | | | |
| Spring Boot Log4j2 | | ✓ | ✓ | ✓ |
| Spring Boot AOP | | ✓ | | |
| Spring Cloud Task 3.x | ✓ | ✓ | ✓ | ✓ |
| Spring Kafka | ✓ (producer) | ✓ (consumer) | | ✓ (consumer) |
| Spring Retry | | ✓ | | ✓ |
| Spring Data MongoDB | | | ✓ | |
| Springdoc OpenAPI 2.7.0 | ✓ | | | |
| Apache Spark Core + SQL 4.0 | | ✓ (provided) | ✓ (provided) | ✓ (provided) |
| Spark SQL–Kafka Connector | | ✓ | | ✓ |
| MongoDB Spark Connector | | ✓ | ✓ | |
| ArangoDB Spark Datasource | | ✓ | ✓ | ✓ |
| PostgreSQL JDBC | ✓ | ✓ | ✓ | ✓ |
| Lombok | ✓ | ✓ | ✓ | ✓ |
| maven-shade-plugin (uber JAR) | | | ✓ | ✓ |

---

## Common Configuration Binding Mechanism

All modules follow the same Spring Boot configuration pattern:
- Define typed configuration classes with `@ConfigurationProperties`.
- Register them with `@EnableConfigurationProperties` in module configuration.
- Inject them into runtime components using constructor injection.

Primary examples:
- [spark-job-service/src/main/java/com/aiks/spark/conf/SparkLauncherProperties.java](../spark-job-service/src/main/java/com/aiks/spark/conf/SparkLauncherProperties.java)
- [spark-job-service/src/main/java/com/aiks/spark/conf/SparkJobServiceConfiguration.java](../spark-job-service/src/main/java/com/aiks/spark/conf/SparkJobServiceConfiguration.java)
- [spark-job-service/src/main/java/com/aiks/spark/launcher/SparkSubmitJobLauncher.java](../spark-job-service/src/main/java/com/aiks/spark/launcher/SparkSubmitJobLauncher.java)
- [spark-job-commons/src/main/java/com/aiks/spark/common/config/properties/ConnectorProperties.java](../spark-job-commons/src/main/java/com/aiks/spark/common/config/properties/ConnectorProperties.java)
- [spark-job-commons/src/main/java/com/aiks/spark/common/config/SparkConnectorConfiguration.java](../spark-job-commons/src/main/java/com/aiks/spark/common/config/SparkConnectorConfiguration.java)
- [spark-batch-sales-report-job/src/main/java/com/aiks/spark/sales/conf/JobProperties.java](../spark-batch-sales-report-job/src/main/java/com/aiks/spark/sales/conf/JobProperties.java)
- [spark-batch-sales-report-job/src/main/java/com/aiks/spark/sales/conf/JobConfiguration.java](../spark-batch-sales-report-job/src/main/java/com/aiks/spark/sales/conf/JobConfiguration.java)
- [spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/conf/JobProperties.java](../spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/conf/JobProperties.java)
- [spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/conf/JobConfiguration.java](../spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/conf/JobConfiguration.java)

```mermaid
flowchart LR
    EXT["application.yml / profile YAML / env vars"] --> BIND["@ConfigurationProperties\nTyped properties objects"]
    BIND --> REG["@EnableConfigurationProperties\nRegister as Spring beans"]
    REG --> INJ["Constructor injection\ninto services/executors/connectors"]
```

This mechanism is intentionally consistent across modules to make configuration behavior predictable during local runs, Docker, and Kubernetes deployments.

### Troubleshooting Configuration Binding

Common symptoms and checks:
- Symptom: App fails at startup with property validation errors.
    Check: `@Validated` constraints in properties classes and required YAML keys for the active profile.
- Symptom: Properties bean exists but values are null/default.
    Check: `@EnableConfigurationProperties(...)` is present in module config and prefix names exactly match YAML keys.
- Symptom: Profile-specific values are not applied.
    Check: active profile (`spring.profiles.active`) and file naming (`application-<profile>.yml`).
- Symptom: Environment variable overrides do not take effect.
    Check: variable naming/format and whether the process runtime actually received those env vars.
- Symptom: Runtime bean still uses old values.
    Check: constructor injection target type is the expected properties class and no duplicate bean wiring path is used.

---

## spark-job-service

A Spring Boot web service that accepts REST requests to start and stop Spark jobs by invoking `spark-submit` as an external process. It does not run Spark itself — it is a thin orchestration layer.

**Key frameworks:**
- **Spring Boot Web** — exposes `POST /v1/spark-jobs/start` and `POST /v1/spark-jobs/stop/{correlationId}` via `@RestController`
- **Spring Boot Actuator** — health and metrics endpoint at `/actuator/health`
- **Spring Boot Validation** — JSR-303 bean validation on `JobLaunchRequest` request bodies
- **Spring Boot HATEOAS** — paginated response assembly for execution history endpoints
- **Spring Cloud Task** — tracks job lifecycle (start, completion, failure) via `TaskExplorer` / `TaskRepository` backed by PostgreSQL
- **Spring Kafka** — `KafkaTemplate` publishes a stop signal (correlationId) to a Kafka topic when a stop request is received
- **Springdoc OpenAPI 2.7.0** — auto-generates Swagger UI from `@Tag`, `@Operation`, `@ApiResponses` annotations
- **spring-boot-problem-handler** — standardized RFC 7807 error responses
- **`@ConfigurationProperties`** — type-safe binding of all `spark-launcher.*` YAML properties to `SparkLauncherProperties` / `SparkJobProperties`

### Spring Boot Architecture Layers

The service is structured into four horizontal layers. Each layer has a single responsibility and communicates only with the layer immediately below it.

| Layer | Responsibility | Key Classes |
|---|---|---|
| **REST (Presentation)** | Expose HTTP endpoints, bind and validate request bodies, return `ResponseEntity` | `SparkJobController`, `SparkJobExplorerController` |
| **Validation** | Apply pre-launch rules via a chain of validators before the request reaches the launcher | `JobLaunchRequestValidationChain`, `JobNameValidator`, `CorrelationIdValidator` |
| **Launcher (Service)** | Build the `spark-submit` command, execute it asynchronously, publish stop signals to Kafka | `SparkJobLauncher` (interface), `AbstractSparkJobLauncher`, `SparkSubmitJobLauncher`, `SparkEmrJobLauncher` |
| **Configuration** | Bind `application.yml` properties to typed beans, produce shared infrastructure beans | `SparkJobServiceConfiguration`, `SparkLauncherProperties`, `SparkJobProperties` |

```mermaid
flowchart TB
    subgraph REST["REST Layer (@RestController)"]
        SJC["SparkJobController\n@RestController\n@RequestMapping /v1/spark-jobs"]
        SJEC["SparkJobExplorerController\n@RestController\n@ConditionalOnProperty\npersist-jobs=true"]
    end

    subgraph VALIDATION["Validation Layer (@Component)"]
        CHAIN["JobLaunchRequestValidationChain\n@Component"]
        JNV["JobNameValidator"]
        CIV["CorrelationIdValidator"]
        CHAIN --> JNV
        CHAIN --> CIV
    end

    subgraph LAUNCHER["Launcher Layer (Service)"]
        IFACE("SparkJobLauncher\ninterface")
        ABS["AbstractSparkJobLauncher\nabstract"]
        SUBMIT["SparkSubmitJobLauncher\n@Component\nsparkSubmit + KafkaTemplate"]
        EMR["SparkEmrJobLauncher\n@Component\nAWS EMR launcher"]
        ABS -.->|implements| IFACE
        SUBMIT -->|extends| ABS
        EMR -->|extends| ABS
    end

    subgraph CONFIG["Configuration Layer"]
        SLP["SparkLauncherProperties\n@ConfigurationProperties\nprefix=spark-launcher"]
        SJP["SparkJobProperties\nper-job conf + env"]
        SJSC["SparkJobServiceConfiguration\n@Configuration\n@Bean sparkProperties\n@Bean paginatedResourceAssembler"]
        SLP --> SJP
    end

    SJC --> CHAIN
    SJC --> IFACE
    IFACE --> SUBMIT
    IFACE --> EMR
    SUBMIT --> SLP
    SJSC --> SLP
```

---

### Spring Boot Flow Architecture

The diagrams below trace the two primary HTTP flows end-to-end: submitting a job and stopping one.

#### Start Job Flow — `POST /v1/spark-jobs/start`

An HTTP request body is deserialised into a `JobLaunchRequest`, validated, then handed to `SparkSubmitJobLauncher` which builds and runs a `spark-submit` process asynchronously via a cached thread pool. The response is returned immediately as HTTP 202 Accepted while the job runs in the background.

```mermaid
sequenceDiagram
    participant Client
    participant Controller as SparkJobController<br/>@RestController
    participant Chain as JobLaunchRequestValidationChain
    participant Launcher as SparkSubmitJobLauncher
    participant Command as SparkSubmitCommand
    participant Exec as ExecutorService<br/>(CachedThreadPool)
    participant Spark as spark-submit Process

    Client->>Controller: POST /v1/spark-jobs/start<br/>{ jobName, correlationId, sparkConfigs, ... }
    Controller->>Chain: validate(jobLaunchRequest)
    Chain-->>Controller: (pass or throw 400)
    Controller->>Launcher: startJob(jobLaunchRequest)
    Launcher->>Launcher: resolve SparkJobProperties<br/>from SparkLauncherProperties.jobs[jobName]
    Launcher->>Launcher: merge sparkConfigurations()<br/>(global → job-level → runtime overrides)
    Launcher->>Command: build spark-submit args list
    Command-->>Launcher: List<String> command
    Launcher->>Exec: CompletableFuture.supplyAsync()
    Exec->>Spark: ProcessBuilder.start()
    Controller-->>Client: HTTP 202 Accepted<br/>+ correlationId
    Spark-->>Exec: exitValue (async)
```

#### Stop Job Flow — `POST /v1/spark-jobs/stop/{correlationId}`

Stopping a job is signal-based. The service publishes the `correlationId` to a Kafka topic. Inside the running Spark job, `SparkExecutionManager` consumes that topic and tears down the streaming query or cancels the Spark context.

```mermaid
sequenceDiagram
    participant Client
    participant Controller as SparkJobController<br/>@RestController
    participant Launcher as SparkSubmitJobLauncher
    participant Kafka as KafkaTemplate
    participant Topic as Kafka Topic<br/>spark-launcher.job-stop-topic
    participant Manager as SparkExecutionManager<br/>(inside Spark job)
    participant Query as StreamingQuery / SparkSession

    Client->>Controller: POST /v1/spark-jobs/stop/{correlationId}
    Controller->>Launcher: stopJob(correlationId)
    Launcher->>Kafka: send(jobStopTopic, correlationId)
    Kafka->>Topic: publish message
    Controller-->>Client: HTTP 202 Accepted
    Topic-->>Manager: onMessage(correlationId)
    Manager->>Query: streamingQuery.stop()<br/>or sparkSession.cancelAllJobs()
```

---

### Key Spring Boot Annotations in Use

| Annotation | Location | Purpose |
|---|---|---|
| `@RestController` + `@RequestMapping` | `SparkJobController`, `SparkJobExplorerController` | Declare HTTP endpoints; return `ResponseEntity` automatically serialised to JSON |
| `@RequiredArgsConstructor` (Lombok) | Controllers, validators, launchers | Generate constructor injection without boilerplate |
| `@ConfigurationProperties(prefix=…)` | `SparkLauncherProperties` | Bind all `spark-launcher.*` YAML keys to a validated typed POJO |
| `@Validated` | `SparkLauncherProperties`, `SparkJobProperties` | Enforce JSR-303 constraints (`@NotEmpty`, `@NotNull`) on config at startup |
| `@Configuration` + `@Bean` | `SparkJobServiceConfiguration` | Produce shared beans (e.g., `sparkProperties`, `paginatedResourceAssembler`) |
| `@ConditionalOnProperty` | `SparkJobExplorerController` | Activate the execution-history controller only when `persist-jobs=true` |
| `@PreDestroy` | `SparkSubmitJobLauncher` | Shutdown the cached thread pool cleanly on application stop |
| `@Tag`, `@Operation`, `@ApiResponses` | Both controllers | Auto-generate OpenAPI 3 documentation via Springdoc |
| `@Component` | `JobLaunchRequestValidationChain`, validators | Register as Spring-managed beans; list auto-collected by Spring for the chain |

---

## spark-job-commons

A shared Spring Boot auto-configuration library consumed by both Spark job modules. It provides Spark session management, connector abstractions, execution lifecycle hooks, and the Kafka consumer that handles job stop signals.

**Key frameworks:**
- **Spring Boot Auto-configuration** — `SparkCommonsConfiguration` is registered as an auto-configuration class; consumers receive `SparkSession`, connectors, and execution management beans without explicit wiring
- **Spring Boot AOP (`spring-boot-starter-aop`)** — aspect-oriented hooks for cross-cutting concerns such as execution logging and retry advice
- **Spring Cloud Task** — `SpringCloudTaskConfiguration` integrates task lifecycle; `SparkExecutionManager` implements `TaskExecutionListener` to react to job start, completion, and failure events
- **Spring Kafka** — `@KafkaListener` in `SparkExecutionManager` subscribes to the stop topic; on receiving the correlationId it stops the active `StreamingQuery` or cancels all Spark jobs
- **Spring Retry** — `@Retryable` applied to stream restart logic in `SparkStreamLauncher`; retries on `StreamRetryableException` with configurable back-off
- **`@ConfigurationProperties`** — `ConnectorProperties` and its nested option classes (`JdbcOptions`, `MongoOptions`, `ArangoOptions`, `KafkaOptions`, `FileOptions`) bind connector config from YAML
- **`@ConditionalOnProperty` / `@ConditionalOnClass`** — sub-configurations (`SparkExecutionManagerConfiguration`, `SparkStreamLauncherConfiguration`) activate only when the required beans and properties are present

```mermaid
flowchart TB
    subgraph AUTO["Auto-configuration (SparkCommonsConfiguration)"]
        SS["SparkSessionConfiguration\nCreates SparkSession bean"]
        SC["SparkConnectorConfiguration\nConnectorFactory + typed connectors"]
        SEC["SparkExecutionManagerConfiguration\nSparkExecutionManager\n@KafkaListener stop handler"]
        SLC["SparkStreamLauncherConfiguration\nSparkStreamLauncher\n@Retryable stream restart"]
    end
    SS --> SC
    SEC --> SS
    SLC --> SEC
```

---

## spark-batch-sales-report-job

A Spring Boot application packaged as a `spark-submit`-compatible uber JAR (via maven-shade-plugin). It reads sales and product data, aggregates them with Spark SQL, and writes a report to MongoDB and ArangoDB.

**Key frameworks:**
- **Spring Boot (no web layer)** — started via `spring-cloud-starter-task`; no embedded HTTP server; the application exits after the job completes
- **Spring Cloud Task** — registers the run as a task execution; updates status in PostgreSQL via `TaskRepository`; an `ApplicationRunner` bean drives the pipeline
- **Spring Boot Validation** — `@ConfigurationProperties` with `@Validated` on `JobProperties` ensures all parameters are present at startup
- **Spring Boot Log4j2** — replaces default Logback; Log4j2 configuration in `log4j2.properties`
- **Spring Data MongoDB** — `MongoTemplate` used to seed and persist data during the `DataPopulator` pre-processing step
- **Apache Spark Core + SQL** (provided by Spark runtime) — `SparkSession`, Dataset/DataFrame APIs for batch transformations
- **MongoDB Spark Connector** — Spark DataFrameReader/Writer format `mongodb` for bulk reads and writes
- **ArangoDB Spark Datasource** — Spark DataFrameWriter format `arangodb` for persisting the final report
- **maven-shade-plugin** — produces a fat JAR with all dependencies (except Spark provided scope) for `spark-submit`

```mermaid
sequenceDiagram
    participant SparkSubmit as spark-submit
    participant SRJ as SalesReportJob
    participant Runner as SparkStatementJobRunner
    participant Pipeline as SalesReportPipelineTemplate
    participant Spark as SparkSession

    SparkSubmit->>SRJ: main()
    SRJ->>Runner: run(args)
    Runner->>Pipeline: run()
    Pipeline->>Spark: loadSales() DataFrame
    Pipeline->>Spark: loadProducts() DataFrame
    Pipeline->>Spark: aggregateSales() DataFrame
    Pipeline->>Spark: buildReport() DataFrame
    Pipeline->>Spark: persist() to MongoDB + ArangoDB
    Runner-->>SRJ: complete — Spring Cloud Task records SUCCESS
```

---

## spark-stream-logs-analysis-job

A Spring Boot application packaged as a `spark-submit`-compatible uber JAR. It runs a Spark Structured Streaming query that reads log lines from Kafka, parses error patterns with a regex strategy, and writes results to ArangoDB in micro-batch mode. It runs continuously until a stop signal is received via Kafka.

**Key frameworks:**
- **Spring Boot (no web layer)** — started via `spring-cloud-starter-task`; no embedded HTTP server
- **Spring Cloud Task** — task lifecycle management identical to the batch job; status persisted to PostgreSQL
- **Spring Boot Validation** — `@Validated` on `JobProperties` for startup-time config validation
- **Spring Boot Log4j2** — asynchronous appenders for high-throughput logging during streaming
- **Spring Kafka** — `KafkaTemplate` in `LogsGenerator` publishes sample log events to the input topic; `@KafkaListener` in `SparkExecutionManager` (from commons) handles stop signals
- **Spring Retry** — `@Retryable` in `SparkStreamLauncher` (from commons) restarts the streaming query on transient `StreamRetryableException`
- **Apache Spark Core + SQL** (provided) — `SparkSession` in local or cluster mode
- **Spark SQL–Kafka Connector** — provides a Kafka source (`readStream().format("kafka")`) for Structured Streaming
- **ArangoDB Spark Datasource** — micro-batch `foreachBatch` sink writes parsed error records to ArangoDB
- **maven-shade-plugin** — uber JAR for `spark-submit`

```mermaid
sequenceDiagram
    participant SparkSubmit as spark-submit
    participant LAJ as LogAnalysisJob
    participant Runner as LogAnalysisJobRunner
    participant Executor as SparkPipelineExecutor
    participant Spark as SparkSession
    participant KSource as Kafka Source Topic
    participant Strategy as RegexErrorLogParserStrategy
    participant ASink as ArangoDB Sink
    participant StopKafka as Kafka Stop Topic
    participant Manager as SparkExecutionManager

    SparkSubmit->>LAJ: main()
    LAJ->>Runner: run(args)
    Runner->>Executor: execute()
    Executor->>Spark: readStream().format("kafka")
    KSource-->>Spark: log lines (micro-batch)
    Spark->>Strategy: parse(logLines)
    Strategy-->>Spark: parsed error records
    Spark->>ASink: foreachBatch to ArangoDB
    Note over Runner,Spark: streaming loop runs until stop signal
    StopKafka-->>Manager: correlationId
    Manager->>Spark: streamingQuery.stop()
    Runner-->>LAJ: complete — Spring Cloud Task records SUCCESS
```
