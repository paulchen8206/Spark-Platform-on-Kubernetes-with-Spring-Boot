# Spark Job Commons

Shared library used by Spark job modules in this repository.

## Usage

Add dependency from sibling modules:

```xml
<dependency>
  <groupId>com.aiks.spark</groupId>
  <artifactId>spark-job-commons</artifactId>
  <version>${project.version}</version>
</dependency>
```

## Makefile Usage

From repository root, common workflows that include this module are:

```bash
make mk-build
make mk-images
```

To build only this module directly:

```bash
mvn -pl spark-job-commons -am clean install
```

## Connectors

Reusable connectors are provided in [connector](src/main/java/com/aiks/spark/common/connector):
- [FileConnector](src/main/java/com/aiks/spark/common/connector/FileConnector.java)
- [MongoConnector](src/main/java/com/aiks/spark/common/connector/MongoConnector.java)
- [ArangoConnector](src/main/java/com/aiks/spark/common/connector/ArangoConnector.java)
- [JdbcConnector](src/main/java/com/aiks/spark/common/connector/JdbcConnector.java)
- [KafkaConnector](src/main/java/com/aiks/spark/common/connector/KafkaConnector.java)

Base connector config class: [ConnectorProperties](src/main/java/com/aiks/spark/common/config/properties/ConnectorProperties.java)

```yaml
aiks:
  connector:
    save-mode: Append
    output-mode: Update
```

Common options:
- `save-mode`: batch write save mode (`Append`, `Overwrite`, `ErrorIfExists`, `Ignore`).
- `output-mode`: streaming sink output mode (`Append`, `Complete`, `Update`).

## Framework and Pattern References

For centralized details, see:

- [Spring Boot Framework](../docs/SPRING_BOOT_FRAMEWORK.md) for the commons module framework role (auto-configuration, Spring Kafka listener, Spring Retry).
- [Design Patterns](../docs/DESIGN_PATTERNS.md) for the Factory pattern class diagram used for connector selection.

### Connector Configuration Examples

File options:

```yaml
aiks:
  connector:
    file-options:
      format: csv
      header: true
      path: spark-space/output
      merge: true
```

MongoDB options:

```yaml
aiks:
  connector:
    mongo-options:
      url: mongodb://localhost:27017
      database: sales_db
```

ArangoDB options:

```yaml
aiks:
  connector:
    arango-options:
      endpoints: localhost:8529
      database: products_db
      username: root
      password: admin
```

JDBC options:

```yaml
aiks:
  connector:
    jdbc-options:
      url: jdbc:postgresql://localhost:5432
      database: error_logs_db
      username: postgres
      password: admin
      batchsize: 1000
      isolation-level: READ_UNCOMMITTED
```

Kafka options:

```yaml
aiks:
  connector:
    kafka-options:
      bootstrap-servers: localhost:9092
      topic: error-logs
      fail-on-data-loss: false
```

## Job Lifecycle Support

### Job Listener

[SparkExecutionManager](src/main/java/com/aiks/spark/common/SparkExecutionManager.java) provides:
- Lifecycle logging (start/end/duration).
- Status updates (`Completed`, `Failed`, `Terminated`).
- Optional stop-signal handling through Kafka topic `job-stop-requests`.

Stopping is best-effort because Spark jobs may not terminate immediately depending on execution state.

### Stream Launcher

[SparkStreamLauncher](src/main/java/com/aiks/spark/common/SparkStreamLauncher.java) starts and awaits streaming queries in a dedicated thread and supports retry behavior.

## Error Handling

Use [JobProblem](src/main/java/com/aiks/spark/common/error/JobProblem.java) as the common exception type.

```java
throw JobProblem.of("IOException while reading file").cause(e).build();
```

## Utilities

- [SparkUtils](src/main/java/com/aiks/spark/common/util/SparkUtils.java)
- [SparkOptions](src/main/java/com/aiks/spark/common/util/SparkOptions.java)
- [StringUtils](src/main/java/com/aiks/spark/common/util/StringUtils.java)
- [JobConstants](src/main/java/com/aiks/spark/common/util/JobConstants.java)
- [DateTimeUtils](src/main/java/com/aiks/spark/common/util/DateTimeUtils.java)
- [DateTimeFormatUtils](src/main/java/com/aiks/spark/common/util/DateTimeFormatUtils.java)
- [ExecutionContext](src/main/java/com/aiks/spark/common/util/ExecutionContext.java)

## Build and Test

```bash
mvn clean install
mvn test
```

## References

- Apache Spark: https://spark.apache.org/docs/4.0.0
- Spark SQL Data Sources: https://spark.apache.org/docs/latest/sql-data-sources.html
- Spark third-party projects: https://spark.apache.org/third-party-projects.html
- MongoDB Spark connector: https://www.mongodb.com/docs/spark-connector/v10.4
- ArangoDB Spark datasource: https://docs.arangodb.com/3.13/develop/integrations/arangodb-datasource-for-apache-spark
- Spark Structured Streaming + Kafka: https://spark.apache.org/docs/4.0.0/structured-streaming-kafka-integration.html

