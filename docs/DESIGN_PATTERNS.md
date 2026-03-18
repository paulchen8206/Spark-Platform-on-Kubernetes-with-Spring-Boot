# Design Patterns Used in This Project

This document centralizes module-level design patterns used across the repository.
For Spring Boot architecture layers, request flow diagrams, and annotation reference, see [Spring Boot Framework Patterns](SPRING_BOOT_FRAMEWORK.md).

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
