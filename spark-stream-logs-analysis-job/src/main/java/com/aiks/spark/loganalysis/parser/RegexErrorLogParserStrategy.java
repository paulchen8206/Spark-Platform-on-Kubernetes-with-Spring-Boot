package com.aiks.spark.loganalysis.parser;

import static org.apache.spark.sql.functions.col;
import static org.apache.spark.sql.functions.regexp_extract;

import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.springframework.stereotype.Component;

@Component
public class RegexErrorLogParserStrategy implements ErrorLogParserStrategy {

  private static final String LOG_REGEX =
      "(?<=^)(\\S+T\\S+)(\\s+ERROR\\s+\\d+\\s+---\\s+\\[([a-zA-Z0-9-]+)\\].*)(:.*)";

  @Override
  public Dataset<Row> parse(final Dataset<Row> logLines) {
    return logLines
        .filter(col("log_line").rlike(LOG_REGEX))
        .select(
            regexp_extract(col("log_line"), LOG_REGEX, 1).alias("datetime"),
            regexp_extract(col("log_line"), LOG_REGEX, 3).alias("application"),
            regexp_extract(col("log_line"), LOG_REGEX, 4).alias("error_message"));
  }
}
