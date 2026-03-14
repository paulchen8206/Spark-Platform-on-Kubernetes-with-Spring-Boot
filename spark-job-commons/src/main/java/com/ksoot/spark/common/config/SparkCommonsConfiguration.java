package com.ksoot.spark.common.config;

import com.ksoot.spark.common.SparkExecutionManager;
import com.ksoot.spark.common.SparkStreamLauncher;
import org.apache.spark.sql.SparkSession;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.AutoConfigureOrder;
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.cloud.task.repository.TaskExecution;
import org.springframework.context.MessageSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.task.TaskExecutor;
import org.springframework.kafka.config.KafkaListenerEndpointRegistry;
import org.springframework.retry.annotation.Retryable;

@AutoConfiguration
@AutoConfigureOrder(Ordered.HIGHEST_PRECEDENCE)
@ImportAutoConfiguration(
    classes = {
      SparkSessionConfiguration.class,
      SparkConnectorConfiguration.class,
      SpringCloudTaskConfiguration.class
    })
public class SparkCommonsConfiguration {

  @ConditionalOnClass({TaskExecution.class, KafkaListenerEndpointRegistry.class})
  @Configuration(proxyBeanMethods = false)
  static class SparkExecutionManagerConfiguration {

    @Bean
    SparkExecutionManager sparkExecutionManager(
        final SparkSession sparkSession,
        final KafkaListenerEndpointRegistry kafkaListenerEndpointRegistry,
        final MessageSource messageSource) {
      return new SparkExecutionManager(sparkSession, kafkaListenerEndpointRegistry, messageSource);
    }
  }

  @ConditionalOnClass(Retryable.class)
  @Configuration(proxyBeanMethods = false)
  static class SparkStreamLauncherConfiguration {

    @Bean
    @ConditionalOnBean(SparkExecutionManager.class)
    SparkStreamLauncher sparkStreamLauncher(
        final SparkExecutionManager sparkExecutionManager, final TaskExecutor taskExecutor) {
      return new SparkStreamLauncher(sparkExecutionManager, taskExecutor);
    }
  }
}
