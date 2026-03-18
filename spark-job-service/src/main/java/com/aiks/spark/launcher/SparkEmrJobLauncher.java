package com.aiks.spark.launcher;

import com.aiks.spark.conf.SparkLauncherProperties;
import com.aiks.spark.dto.JobLaunchRequest;
import java.util.Properties;

// TODO: Implement to submit job on EMR
public class SparkEmrJobLauncher extends AbstractSparkJobLauncher {

  protected SparkEmrJobLauncher(
      final Properties sparkProperties, final SparkLauncherProperties sparkLauncherProperties) {
    super(sparkProperties, sparkLauncherProperties);
  }

  @Override
  public void startJob(JobLaunchRequest jobLaunchRequest) {}

  @Override
  public void stopJob(String jobCorrelationId) {}
}
