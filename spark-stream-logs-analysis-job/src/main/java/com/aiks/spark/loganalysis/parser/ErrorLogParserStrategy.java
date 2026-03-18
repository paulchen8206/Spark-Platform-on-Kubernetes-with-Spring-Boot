package com.aiks.spark.loganalysis.parser;

import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;

public interface ErrorLogParserStrategy {

  Dataset<Row> parse(Dataset<Row> logLines);
}
