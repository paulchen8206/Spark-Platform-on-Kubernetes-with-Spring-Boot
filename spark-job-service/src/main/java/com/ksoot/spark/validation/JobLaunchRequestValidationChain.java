package com.ksoot.spark.validation;

import com.ksoot.spark.dto.JobLaunchRequest;
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
