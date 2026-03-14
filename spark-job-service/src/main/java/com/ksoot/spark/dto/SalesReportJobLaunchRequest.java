package com.ksoot.spark.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonTypeName;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import java.time.YearMonth;
import java.util.Map;
import java.util.Objects;
import lombok.*;
import org.apache.commons.lang3.StringUtils;

@Getter
@ToString(callSuper = true)
@Valid
@JsonTypeName("sales-report-job")
// Should be Immutable
public class SalesReportJobLaunchRequest extends JobLaunchRequest {

  @Schema(description = "Report for the month", example = "2024-11", nullable = true)
  @NotNull
  @PastOrPresent
  private YearMonth month;

  private SalesReportJobLaunchRequest(
      final String jobName, final Map<String, Object> sparkConfigs, final YearMonth month) {
    super(jobName, sparkConfigs);
    this.month = Objects.nonNull(month) ? month : YearMonth.now();
  }

  @JsonCreator
  public static SalesReportJobLaunchRequest of(
      @JsonProperty("jobName") final String jobName,
      @JsonProperty("sparkConfigs") final Map<String, Object> sparkConfigs,
      @JsonProperty("month") final YearMonth month,
      @JsonProperty("jobArguments") final Map<String, Object> jobArguments) {
    return new SalesReportJobLaunchRequest(
        jobName, sparkConfigs, Objects.nonNull(month) ? month : monthFromArgs(jobArguments));
  }

  private static YearMonth monthFromArgs(final Map<String, Object> jobArguments) {
    if (Objects.isNull(jobArguments)) {
      return null;
    }

    final Object monthValue = jobArguments.get("month");
    if (Objects.isNull(monthValue)) {
      return null;
    }

    final String rawMonth = String.valueOf(monthValue);
    if (StringUtils.isBlank(rawMonth)) {
      return null;
    }

    return YearMonth.parse(rawMonth);
  }

  @Override
  public Map<String, String> jobArgs() {
    return Map.of("STATEMENT_MONTH", month.toString());
  }
}
