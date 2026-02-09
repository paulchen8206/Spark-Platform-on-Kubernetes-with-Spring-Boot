FROM ksoot/spark:4.0.0

ADD target/spark-batch-sales-report-job-*.jar $SPARK_JOB_APPS_DIR/spark-batch-sales-report-job.jar

ENTRYPOINT [ "/opt/entrypoint.sh" ]