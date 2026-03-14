#!/bin/bash

set -euo pipefail

# Define the Spark submit command
SPARK_SUBMIT_CMD=${JOB_SUBMIT_COMMAND:-}

if [ -z "$SPARK_SUBMIT_CMD" ]; then
  echo "JOB_SUBMIT_COMMAND is required"
  exit 1
fi

# Execute the Spark submit command
echo "Inside spark-job-submit.sh ..."

read -r -a SPARK_SUBMIT_CMD_ARR <<< "$SPARK_SUBMIT_CMD"

"${SPARK_SUBMIT_CMD_ARR[@]}"

# Check the exit status of the Spark submit command
if [ $? -eq 0 ]; then
  echo "Spark submit command successful."
else
  echo "Spark submit command failed."
  exit 1
fi