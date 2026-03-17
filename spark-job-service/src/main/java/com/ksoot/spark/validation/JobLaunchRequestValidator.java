package com.ksoot.spark.validation;

import com.ksoot.spark.dto.JobLaunchRequest;

public interface JobLaunchRequestValidator {

  void validate(JobLaunchRequest jobLaunchRequest);
}
