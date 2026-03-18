#!/bin/bash
# Creates the extra Spark sink database alongside the primary spark_jobs_db.
# POSTGRES_EXTRA_DB must be set in the container environment.
set -e

echo "Creating extra Spark database: $POSTGRES_EXTRA_DB"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" \
  -c "CREATE DATABASE $POSTGRES_EXTRA_DB;" \
  -c "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_EXTRA_DB TO $POSTGRES_USER;"
echo "Done."
