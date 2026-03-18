package com.aiks.spark.validation;

import com.aiks.spark.dto.JobLaunchRequest;

public interface JobLaunchRequestValidator {

  void validate(JobLaunchRequest jobLaunchRequest);
}
