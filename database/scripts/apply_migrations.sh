#!/usr/bin/env bash
set -euo pipefail

TARGET_DB=${TARGET_DATABASE:-${POSTGRES_DB:-}}
PSQL_CMD=${PSQL_CMD:-psql}

if [ -z "$TARGET_DB" ]; then
  echo "TARGET_DATABASE or POSTGRES_DB must be set"
  exit 2
fi

for f in migrations/*.sql; do
  echo "Applying $f to $TARGET_DB"
  $PSQL_CMD "$TARGET_DB" -f "$f"
done

echo "Migrations applied successfully"
