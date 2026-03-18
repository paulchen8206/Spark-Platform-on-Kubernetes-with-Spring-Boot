package com.aiks.spark.loganalysis;

import com.aiks.spark.common.SparkStreamLauncher;
import com.aiks.spark.common.config.properties.ConnectorProperties;
import com.aiks.spark.common.connector.JdbcConnector;
import com.aiks.spark.common.connector.KafkaConnector;
import com.aiks.spark.loganalysis.parser.ErrorLogParserStrategy;
import java.util.concurrent.TimeoutException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.streaming.DataStreamWriter;
import org.apache.spark.sql.streaming.StreamingQueryException;
import org.springframework.stereotype.Component;

@Component
@Slf4j
@RequiredArgsConstructor
public class SparkPipelineExecutor {

  private static final String ERROR_LOGS_TABLE = "error_logs";

  private final ConnectorProperties connectorProperties;

  private final KafkaConnector kafkaConnector;

  private final JdbcConnector jdbcConnector;

  private final SparkStreamLauncher sparkStreamLauncher;

  private final ErrorLogParserStrategy errorLogParserStrategy;

  public void execute() {
    Dataset<Row> kafkaLogs =
        this.kafkaConnector.readStream(this.connectorProperties.getKafkaOptions().getTopic());
    // Deserialize Kafka messages as text
    Dataset<Row> logLines = kafkaLogs.selectExpr("CAST(value AS STRING) as log_line");
    // Just for testing
    //    this.writeToConsole(errorLogs);

    Dataset<Row> errorLogs = this.errorLogParserStrategy.parse(logLines);

    DataStreamWriter<Row> logsStreamWriter =
        this.jdbcConnector.writeStream(errorLogs, ERROR_LOGS_TABLE);
    // Start the stream in separate thread
    this.sparkStreamLauncher.startStream(logsStreamWriter);
  }

  // Just for testing
  @SuppressWarnings("unused")
  private void writeToConsole(final Dataset<Row> errorLogs) {
    try {
      errorLogs
          .writeStream()
          .outputMode(this.connectorProperties.getOutputMode())
          .format("console")
          .start()
          .awaitTermination();
    } catch (final TimeoutException | StreamingQueryException e) {
      log.error("Error while writing to Console", e);
    }
  }
}
