package com.ksoot.spark.common.config;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;
import org.apache.commons.lang3.StringUtils;
import org.apache.spark.sql.SparkSession;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.EnumerablePropertySource;
import org.springframework.core.env.Environment;
import org.springframework.core.env.PropertySource;

@AutoConfiguration
public class SparkSessionConfiguration {

  private static final String SPARK_PREFIX = "spark.";

  @Bean
  @ConditionalOnMissingBean
  SparkSession sparkSession(final Environment environment) {
    SparkSession.Builder sparkSessionBuilder = SparkSession.builder();

    if (environment instanceof ConfigurableEnvironment configurableEnvironment) {
      final List<PropertySource<?>> propertySources =
          configurableEnvironment.getPropertySources().stream().collect(Collectors.toList());
      final List<String> sparkPropertyNames =
          propertySources.stream()
              .filter(propertySource -> propertySource instanceof EnumerablePropertySource)
              .map(propertySource -> (EnumerablePropertySource<?>) propertySource)
              .map(EnumerablePropertySource::getPropertyNames)
              .flatMap(Arrays::stream)
              .filter(key -> key.startsWith(SPARK_PREFIX))
              .distinct()
              .collect(Collectors.toList());

      for (String key : sparkPropertyNames) {
        final String value = environment.getProperty(key);
        if (StringUtils.isNotBlank(value)) {
          sparkSessionBuilder = sparkSessionBuilder.config(key, value);
        }
      }
    }

    return sparkSessionBuilder.getOrCreate();
  }
}
