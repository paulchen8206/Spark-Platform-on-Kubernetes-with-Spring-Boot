package com.ksoot.spark.common.connector;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

@Component
public class ConnectorFactory {

  private final FileConnector fileConnector;

  private final ObjectProvider<JdbcConnector> jdbcConnectorProvider;

  private final ObjectProvider<MongoConnector> mongoConnectorProvider;

  private final ObjectProvider<ArangoConnector> arangoConnectorProvider;

  private final ObjectProvider<KafkaConnector> kafkaConnectorProvider;

  public ConnectorFactory(
      final FileConnector fileConnector,
      final ObjectProvider<JdbcConnector> jdbcConnectorProvider,
      final ObjectProvider<MongoConnector> mongoConnectorProvider,
      final ObjectProvider<ArangoConnector> arangoConnectorProvider,
      final ObjectProvider<KafkaConnector> kafkaConnectorProvider) {
    this.fileConnector = fileConnector;
    this.jdbcConnectorProvider = jdbcConnectorProvider;
    this.mongoConnectorProvider = mongoConnectorProvider;
    this.arangoConnectorProvider = arangoConnectorProvider;
    this.kafkaConnectorProvider = kafkaConnectorProvider;
  }

  public Object connector(final ConnectorType connectorType) {
    return switch (connectorType) {
      case FILE -> this.fileConnector;
      case JDBC -> this.required(this.jdbcConnectorProvider.getIfAvailable(), connectorType);
      case MONGO -> this.required(this.mongoConnectorProvider.getIfAvailable(), connectorType);
      case ARANGO -> this.required(this.arangoConnectorProvider.getIfAvailable(), connectorType);
      case KAFKA -> this.required(this.kafkaConnectorProvider.getIfAvailable(), connectorType);
    };
  }

  private Object required(final Object connector, final ConnectorType connectorType) {
    if (connector == null) {
      throw new IllegalStateException(
          connectorType + " connector is not available in current runtime");
    }
    return connector;
  }
}
