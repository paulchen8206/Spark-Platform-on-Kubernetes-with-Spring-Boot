package com.aiks.spark.launcher;

import com.aiks.spark.dto.JobLaunchRequest;

public interface SparkJobLauncher {

  void startJob(final JobLaunchRequest jobLaunchRequest);

  void stopJob(final String jobCorrelationId);
}
