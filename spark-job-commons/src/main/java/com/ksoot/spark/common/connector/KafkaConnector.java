package com.ksoot.spark.common.connector;

import com.ksoot.spark.common.config.properties.ConnectorProperties;
import com.ksoot.spark.common.util.SparkOptions;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.spark.sql.*;
import org.apache.spark.sql.WriteConfigMethods;
import org.apache.spark.sql.streaming.DataStreamWriter;
import org.apache.spark.sql.types.StructType;

@Slf4j
@RequiredArgsConstructor
public class KafkaConnector {

  protected final SparkSession sparkSession;

  protected final ConnectorProperties properties;

  public Dataset<Row> readStream(final String topic) {
    var streamReader =
        this.sparkSession
            .readStream()
            .format(SparkOptions.Kafka.FORMAT)
            .option(SparkOptions.Kafka.SUBSCRIBE, topic)
            .option(SparkOptions.Kafka.STARTING_OFFSETS, "latest");
    this.properties.getKafkaOptions().readOptions().forEach(streamReader::option);
    Dataset<Row> dataset = streamReader.load();
    return dataset;
  }

  public Dataset<Row> readStream(final String topic, final StructType schema) {
    var streamReader =
        this.sparkSession
            .readStream()
            .schema(schema)
            .format(SparkOptions.Kafka.FORMAT)
            .option(SparkOptions.Kafka.SUBSCRIBE, topic)
            .option(SparkOptions.Kafka.STARTING_OFFSETS, "latest");
    this.properties.getKafkaOptions().readOptions().forEach(streamReader::option);
    Dataset<Row> dataset = streamReader.load();
    return dataset;
  }

  public void write(final Dataset<Row> dataset, final String topic) {
    log.info(
        "Streaming data to Kafka: {} topic: {}",
        this.properties.getKafkaOptions().getBootstrapServers(),
        this.properties.getKafkaOptions().getTopic());
    var writer =
        dataset
            // // The lambda used in following map method must be Serializable
            // .map(
            // // Mapper function in case you want to convert dataset to another object and write
            // that
            // object to kafka topic. It must be serializable
            //
            //  ,
            // // Some Encoder as per your need, for eg.
            // Encoders.BINARY()
            // )
            .write()
            .format(SparkOptions.Kafka.FORMAT)
            .option(SparkOptions.Kafka.TOPIC, topic);
    this.properties.getKafkaOptions().writeOptions().forEach(writer::option);
    writer.save();
  }

  public DataStreamWriter<Row> writeStream(final Dataset<Row> dataset, final String topic) {
    var streamWriter =
        dataset
            // // The lambda used in following map method must be Serializable
            // .map(
            // // Mapper function in case you want to convert dataset to another object and write
            // that
            // object to kafka topic. It must be serializable
            //
            //  ,
            // // Some Encoder as per your need, for eg.
            // Encoders.BINARY()
            // )
            .writeStream()
            .format(SparkOptions.Kafka.FORMAT);
    final Map<String, String> writeOptions =
        new HashMap<>(this.properties.getKafkaOptions().writeOptions());
    writeOptions.put(SparkOptions.Kafka.TOPIC, topic);
    this.applyStreamOptions(streamWriter, writeOptions);
    return streamWriter;
  }

  @SuppressWarnings("unchecked")
  private void applyStreamOptions(
      final DataStreamWriter<Row> streamWriter, final Map<String, String> options) {
    ((WriteConfigMethods<DataStreamWriter<Row>>) streamWriter).options(options);
  }
}
