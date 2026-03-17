package com.ksoot.spark.validation;

import com.ksoot.spark.dto.JobLaunchRequest;
import org.apache.commons.lang3.StringUtils;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class CorrelationIdValidator implements JobLaunchRequestValidator {

  @Override
  public void validate(final JobLaunchRequest jobLaunchRequest) {
    if (jobLaunchRequest == null || StringUtils.isBlank(jobLaunchRequest.getCorrelationId())) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "correlationId is required");
    }
  }
}
