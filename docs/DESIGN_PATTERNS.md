# Design Patterns Used in This Project

This document centralizes common Spring Boot patterns and module-level design patterns used across the repository.

## 1) Dependency Injection (Constructor-based)

Primary examples:
- [SparkJobController](../spark-job-service/src/main/java/com/aiks/spark/api/SparkJobController.java)
- [SparkPipelineExecutor (stream)](../spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/SparkPipelineExecutor.java)

```mermaid
classDiagram
  class SparkJobController {
    -SparkJobLauncher sparkJobLauncher
    -JobLaunchRequestValidationChain validationChain
    +startSparkJob(jobLaunchRequest)
    +stopSparkJob(correlationId)
  }

  class SparkJobLauncher {
    <<interface>>
    +startJob(jobLaunchRequest)
    +stopJob(jobCorrelationId)
  }

  class JobLaunchRequestValidationChain {
    +validate(jobLaunchRequest)
  }

  SparkJobController --> SparkJobLauncher : constructor injection
  SparkJobController --> JobLaunchRequestValidationChain : constructor injection
```

## 2) REST Controller Layer

Primary example:
- [SparkJobController](../spark-job-service/src/main/java/com/aiks/spark/api/SparkJobController.java)

```mermaid
classDiagram
  class SparkJobController {
    +startSparkJob(jobLaunchRequest) ResponseEntity~String~
    +stopSparkJob(correlationId) ResponseEntity~String~
  }

  class JobLaunchRequest
  class ResponseEntity~String~
  class SparkJobLauncher

  SparkJobController --> JobLaunchRequest : request body
  SparkJobController --> SparkJobLauncher : delegates launch/stop
  SparkJobController --> ResponseEntity~String~ : returns
```

## 3) Java Config + Bean Factory Methods

Primary example:
- [SparkJobServiceConfiguration](../spark-job-service/src/main/java/com/aiks/spark/conf/SparkJobServiceConfiguration.java)

```mermaid
classDiagram
  class SparkJobServiceConfiguration {
    +sparkProperties(environment) Properties
    +paginatedResourceAssembler(resolver) PaginatedResourceAssembler
  }

  class Environment
  class Properties
  class HateoasPageableHandlerMethodArgumentResolver
  class PaginatedResourceAssembler

  SparkJobServiceConfiguration --> Environment : bean method arg
  SparkJobServiceConfiguration --> Properties : creates bean
  SparkJobServiceConfiguration --> HateoasPageableHandlerMethodArgumentResolver : bean method arg
  SparkJobServiceConfiguration --> PaginatedResourceAssembler : creates bean
```

## 4) Externalized Type-safe Configuration

Primary example:
- [ConnectorProperties](../spark-job-commons/src/main/java/com/aiks/spark/common/config/properties/ConnectorProperties.java)

```mermaid
classDiagram
  class ConnectorProperties {
    +SaveMode saveMode
    +String outputMode
    +outputMode() OutputMode
    +FileOptions fileOptions
    +JdbcOptions jdbcOptions
    +MongoOptions mongoOptions
    +ArangoOptions arangoOptions
    +KafkaOptions kafkaOptions
  }

  class FileOptions
  class JdbcOptions
  class MongoOptions
  class ArangoOptions
  class KafkaOptions

  ConnectorProperties *-- FileOptions
  ConnectorProperties *-- JdbcOptions
  ConnectorProperties *-- MongoOptions
  ConnectorProperties *-- ArangoOptions
  ConnectorProperties *-- KafkaOptions
```

## 5) Auto-Configuration + Conditional Beans

Primary example:
- [SparkCommonsConfiguration](../spark-job-commons/src/main/java/com/aiks/spark/common/config/SparkCommonsConfiguration.java)

```mermaid
classDiagram
  class SparkCommonsConfiguration {
    <<AutoConfiguration>>
  }

  class SparkExecutionManagerConfiguration {
    +kafkaListenerEndpointRegistry() KafkaListenerEndpointRegistry
    +sparkExecutionManager(sparkSession, kafkaListenerEndpointRegistry, messageSource) SparkExecutionManager
  }

  class SparkStreamLauncherConfiguration {
    +sparkStreamLauncher(sparkExecutionManager, taskExecutor) SparkStreamLauncher
  }

  class SparkExecutionManager
  class SparkStreamLauncher

  SparkCommonsConfiguration *-- SparkExecutionManagerConfiguration
  SparkCommonsConfiguration *-- SparkStreamLauncherConfiguration
  SparkExecutionManagerConfiguration --> SparkExecutionManager : creates bean when conditions match
  SparkStreamLauncherConfiguration --> SparkStreamLauncher : creates bean when conditions match
```

## 6) Startup Runner Pattern (ApplicationRunner)

Primary examples:
- [SalesReportJob](../spark-batch-sales-report-job/src/main/java/com/aiks/spark/sales/SalesReportJob.java)
- [LogAnalysisJob](../spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/LogAnalysisJob.java)

```mermaid
classDiagram
  class ApplicationRunner {
    <<interface>>
    +run(args)
  }

  class SalesReportJob {
    +applicationRunner(sparkPipelineExecutor) ApplicationRunner
  }

  class SparkStatementJobRunner {
    +run(args)
  }

  class LogAnalysisJob {
    +applicationRunner(sparkPipelineExecutor) ApplicationRunner
  }

  class LogAnalysisJobRunner {
    +run(args)
  }

  class SparkPipelineExecutor

  SparkStatementJobRunner ..|> ApplicationRunner
  LogAnalysisJobRunner ..|> ApplicationRunner
  SalesReportJob --> SparkStatementJobRunner : creates
  LogAnalysisJob --> LogAnalysisJobRunner : creates
  SparkStatementJobRunner --> SparkPipelineExecutor : executes
  LogAnalysisJobRunner --> SparkPipelineExecutor : executes
```

## 7) Event/Listener-driven Lifecycle Handling

Primary example:
- [SparkExecutionManager](../spark-job-commons/src/main/java/com/aiks/spark/common/SparkExecutionManager.java)

```mermaid
classDiagram
  class SparkExecutionManager {
    +onJobStart(taskExecution)
    +onJobCompletion(taskExecution)
    +onJobFailure(taskExecution, throwable)
    +onJobStopRequest(correlationId)
  }

  class KafkaListenerEndpointRegistry
  class SparkSession
  class MessageSource
  class StreamingQuery

  SparkExecutionManager --> KafkaListenerEndpointRegistry : stops listeners
  SparkExecutionManager --> SparkSession : cancels/stops context
  SparkExecutionManager --> MessageSource : resolves i18n messages
  SparkExecutionManager --> StreamingQuery : stop on signal
```

## 8) Validation Pipeline (Chain of Responsibility style)

Primary examples:
- [JobLaunchRequestValidationChain](../spark-job-service/src/main/java/com/aiks/spark/validation/JobLaunchRequestValidationChain.java)
- [JobNameValidator](../spark-job-service/src/main/java/com/aiks/spark/validation/JobNameValidator.java)
- [CorrelationIdValidator](../spark-job-service/src/main/java/com/aiks/spark/validation/CorrelationIdValidator.java)

```mermaid
classDiagram
  class JobLaunchRequestValidationChain {
    -List~JobLaunchRequestValidator~ validators
    +validate(jobLaunchRequest)
  }

  class JobLaunchRequestValidator {
    <<interface>>
    +validate(jobLaunchRequest)
  }

  class JobNameValidator {
    +validate(jobLaunchRequest)
  }

  class CorrelationIdValidator {
    +validate(jobLaunchRequest)
  }

  JobLaunchRequestValidationChain --> JobLaunchRequestValidator : iterates
  JobNameValidator ..|> JobLaunchRequestValidator
  CorrelationIdValidator ..|> JobLaunchRequestValidator
```

## 9) Factory Pattern (Module-level)

Primary examples:
- [ConnectorFactory](../spark-job-commons/src/main/java/com/aiks/spark/common/connector/ConnectorFactory.java)
- [ConnectorType](../spark-job-commons/src/main/java/com/aiks/spark/common/connector/ConnectorType.java)

```mermaid
classDiagram
  class ConnectorType {
    <<enumeration>>
    FILE
    JDBC
    MONGO
    ARANGO
    KAFKA
  }

  class ConnectorFactory {
    +connector(connectorType)
  }

  class FileConnector
  class JdbcConnector
  class MongoConnector
  class ArangoConnector
  class KafkaConnector

  ConnectorFactory ..> ConnectorType : selects by
  ConnectorFactory --> FileConnector : returns
  ConnectorFactory --> JdbcConnector : returns
  ConnectorFactory --> MongoConnector : returns
  ConnectorFactory --> ArangoConnector : returns
  ConnectorFactory --> KafkaConnector : returns
```

## 10) Template Method Pattern (Module-level)

Primary examples:
- [SalesReportPipelineTemplate](../spark-batch-sales-report-job/src/main/java/com/aiks/spark/sales/pipeline/SalesReportPipelineTemplate.java)
- [SparkPipelineExecutor (batch)](../spark-batch-sales-report-job/src/main/java/com/aiks/spark/sales/SparkPipelineExecutor.java)

```mermaid
classDiagram
  class SalesReportPipelineTemplate {
    +run()
    #loadSales()
    #aggregateSales(salesDataset)
    #loadProducts()
    #buildReport(aggregatedSales, productsDataset)
    #persist(reportDataset)
  }

  class SparkPipelineExecutor {
    -SalesReportPipelineTemplate pipelineTemplate
    +execute()
  }

  class AnonymousSalesReportPipeline {
    <<anonymous>>
    +loadSales()
    +aggregateSales(salesDataset)
    +loadProducts()
    +buildReport(aggregatedSales, productsDataset)
    +persist(reportDataset)
  }

  AnonymousSalesReportPipeline --|> SalesReportPipelineTemplate
  SparkPipelineExecutor --> AnonymousSalesReportPipeline : instantiates
```

## 11) Strategy Pattern (Module-level)

Primary examples:
- [ErrorLogParserStrategy](../spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/parser/ErrorLogParserStrategy.java)
- [RegexErrorLogParserStrategy](../spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/parser/RegexErrorLogParserStrategy.java)
- [SparkPipelineExecutor (stream)](../spark-stream-logs-analysis-job/src/main/java/com/aiks/spark/loganalysis/SparkPipelineExecutor.java)

```mermaid
classDiagram
  class SparkPipelineExecutor {
    -ErrorLogParserStrategy errorLogParserStrategy
    +execute()
  }

  class ErrorLogParserStrategy {
    <<interface>>
    +parse(logLines)
  }

  class RegexErrorLogParserStrategy {
    +parse(logLines)
  }

  SparkPipelineExecutor --> ErrorLogParserStrategy : uses
  RegexErrorLogParserStrategy ..|> ErrorLogParserStrategy
```

---

## Spring Boot Framework Patterns

This section covers the Spring Boot architecture layers and request flow as implemented across this project. These are not abstract patterns — each subsection maps directly to concrete classes and annotations in use.

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
        IFACE["SparkJobLauncher\n<<interface>>"]
        ABS["AbstractSparkJobLauncher\n<<abstract>>"]
        SUBMIT["SparkSubmitJobLauncher\n@Component\nsparkSubmit + KafkaTemplate"]
        EMR["SparkEmrJobLauncher\n@Component\nAWS EMR launcher"]
        IFACE <|.. ABS
        ABS <|-- SUBMIT
        ABS <|-- EMR
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

#### Key Spring Boot Annotations in Use

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
