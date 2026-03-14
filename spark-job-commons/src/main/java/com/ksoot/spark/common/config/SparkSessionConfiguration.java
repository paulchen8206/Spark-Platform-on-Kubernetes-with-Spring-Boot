package com.ksoot.spark.common.config;

import org.apache.spark.sql.SparkSession;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
public class SparkSessionConfiguration {

  @Bean
  @ConditionalOnMissingBean
  SparkSession sparkSession() {
    return SparkSession.builder().getOrCreate();
  }
}
