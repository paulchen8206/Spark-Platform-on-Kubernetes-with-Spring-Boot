FROM ksoot/spark:4.0.0

ADD target/spark-stream-logs-analysis-job-*.jar $SPARK_JOB_APPS_DIR/spark-stream-logs-analysis-job.jar

ENTRYPOINT [ "/opt/entrypoint.sh" ]