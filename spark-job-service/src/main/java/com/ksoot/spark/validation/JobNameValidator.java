package com.ksoot.spark.validation;

import com.ksoot.spark.dto.JobLaunchRequest;
import org.apache.commons.lang3.StringUtils;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class JobNameValidator implements JobLaunchRequestValidator {

  @Override
  public void validate(final JobLaunchRequest jobLaunchRequest) {
    if (jobLaunchRequest == null || StringUtils.isBlank(jobLaunchRequest.getJobName())) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "jobName is required");
    }
  }
}
