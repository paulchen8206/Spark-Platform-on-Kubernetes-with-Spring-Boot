# Spark Job Commons

Shared library used by Spark job modules in this repository.

## Usage

Add dependency from sibling modules:

```xml
<dependency>
  <groupId>com.ksoot.spark</groupId>
  <artifactId>spark-job-commons</artifactId>
  <version>${project.version}</version>
</dependency>
```

## Connectors

Reusable connectors are provided in [connector](src/main/java/com/ksoot/spark/common/connector):
- [FileConnector](src/main/java/com/ksoot/spark/common/connector/FileConnector.java)
- [MongoConnector](src/main/java/com/ksoot/spark/common/connector/MongoConnector.java)
- [ArangoConnector](src/main/java/com/ksoot/spark/common/connector/ArangoConnector.java)
- [JdbcConnector](src/main/java/com/ksoot/spark/common/connector/JdbcConnector.java)
- [KafkaConnector](src/main/java/com/ksoot/spark/common/connector/KafkaConnector.java)

Base connector config class: [ConnectorProperties](src/main/java/com/ksoot/spark/common/config/properties/ConnectorProperties.java)

```yaml
ksoot:
  connector:
    save-mode: Append
    output-mode: Update
```

Common options:
- `save-mode`: batch write save mode (`Append`, `Overwrite`, `ErrorIfExists`, `Ignore`).
- `output-mode`: streaming sink output mode (`Append`, `Complete`, `Update`).

### Connector Configuration Examples

File options:

```yaml
ksoot:
  connector:
    file-options:
      format: csv
      header: true
      path: spark-space/output
      merge: true
```

MongoDB options:

```yaml
ksoot:
  connector:
    mongo-options:
      url: mongodb://localhost:27017
      database: sales_db
```

ArangoDB options:

```yaml
ksoot:
  connector:
    arango-options:
      endpoints: localhost:8529
      database: products_db
      username: root
      password: admin
```

JDBC options:

```yaml
ksoot:
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
ksoot:
  connector:
    kafka-options:
      bootstrap-servers: localhost:9092
      topic: error-logs
      fail-on-data-loss: false
```

## Job Lifecycle Support

### Job Listener

[SparkExecutionManager](src/main/java/com/ksoot/spark/common/SparkExecutionManager.java) provides:
- Lifecycle logging (start/end/duration).
- Status updates (`Completed`, `Failed`, `Terminated`).
- Optional stop-signal handling through Kafka topic `job-stop-requests`.

Stopping is best-effort because Spark jobs may not terminate immediately depending on execution state.

### Stream Launcher

[SparkStreamLauncher](src/main/java/com/ksoot/spark/common/SparkStreamLauncher.java) starts and awaits streaming queries in a dedicated thread and supports retry behavior.

## Error Handling

Use [JobProblem](src/main/java/com/ksoot/spark/common/error/JobProblem.java) as the common exception type.

```java
throw JobProblem.of("IOException while reading file").cause(e).build();
```

## Utilities

- [SparkUtils](src/main/java/com/ksoot/spark/common/util/SparkUtils.java)
- [SparkOptions](src/main/java/com/ksoot/spark/common/util/SparkOptions.java)
- [StringUtils](src/main/java/com/ksoot/spark/common/util/StringUtils.java)
- [JobConstants](src/main/java/com/ksoot/spark/common/util/JobConstants.java)
- [DateTimeUtils](src/main/java/com/ksoot/spark/common/util/DateTimeUtils.java)
- [DateTimeFormatUtils](src/main/java/com/ksoot/spark/common/util/DateTimeFormatUtils.java)
- [ExecutionContext](src/main/java/com/ksoot/spark/common/util/ExecutionContext.java)

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

