package com.aiks.spark.validation;

import com.aiks.spark.dto.JobLaunchRequest;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class JobLaunchRequestValidationChain {

  private final List<JobLaunchRequestValidator> validators;

  public void validate(final JobLaunchRequest jobLaunchRequest) {
    this.validators.forEach(validator -> validator.validate(jobLaunchRequest));
  }
}
