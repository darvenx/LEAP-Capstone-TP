#!/usr/bin/env bash
set -euo pipefail

# Usage: TARGET_DATABASE=mydb ./scripts/setup_db_and_seed.sh

TARGET_DB=${TARGET_DATABASE:-${POSTGRES_DB:-trade_db}}
PGHOST=${PGHOST:-localhost}
PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres}

if [ -z "${PGPASSWORD:-}" ]; then
  echo -n "Postgres password for user ${PGUSER}: "
  read -s PGPASSWORD
  echo
  export PGPASSWORD
fi

PSQL="psql -h $PGHOST -p $PGPORT -U $PGUSER"

echo "Checking if database '$TARGET_DB' exists..."
EXISTS=$($PSQL -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${TARGET_DB}';")
if [ "$EXISTS" != "1" ]; then
  echo "Database does not exist — creating '${TARGET_DB}'"
  $PSQL -d postgres -c "CREATE DATABASE \"${TARGET_DB}\";"
else
  echo "Database '${TARGET_DB}' already exists"
fi

echo "Applying schema migrations to ${TARGET_DB}"
$PSQL -d "$TARGET_DB" -f schema.sql

echo "Loading seed fixtures (seed/*.sql, in numbered order)"
for f in seed/*.sql; do
  echo "Applying $f"
  $PSQL -d "$TARGET_DB" -f "$f"
done

echo "Seed loading complete"
