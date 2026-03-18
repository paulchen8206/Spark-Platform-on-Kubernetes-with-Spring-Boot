package com.ksoot.spark.loganalysis.conf;

import com.ksoot.spark.common.SparkExecutionManager;
import com.ksoot.spark.common.SparkStreamLauncher;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.SimpleAsyncTaskExecutor;
import org.springframework.core.task.TaskExecutor;

@Slf4j
@Configuration
@EnableConfigurationProperties(JobProperties.class)
class JobConfiguration {

  @Bean
  @ConditionalOnMissingBean(TaskExecutor.class)
  TaskExecutor sparkStreamTaskExecutor() {
    return new SimpleAsyncTaskExecutor("spark-stream-");
  }

  @Bean
  @ConditionalOnMissingBean(SparkStreamLauncher.class)
  SparkStreamLauncher sparkStreamLauncher(
      final SparkExecutionManager sparkExecutionManager, final TaskExecutor taskExecutor) {
    return new SparkStreamLauncher(sparkExecutionManager, taskExecutor);
  }
}
