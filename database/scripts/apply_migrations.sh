#!/usr/bin/env bash
set -euo pipefail

TARGET_DB=${TARGET_DATABASE:-${POSTGRES_DB:-}}
PSQL_CMD=${PSQL_CMD:-psql}

if [ -z "$TARGET_DB" ]; then
  echo "TARGET_DATABASE or POSTGRES_DB must be set"
  exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR/.."

for f in migrations/*.sql; do
  echo "Applying $f to $TARGET_DB"
  "$PSQL_CMD" -w -v ON_ERROR_STOP=1 "$TARGET_DB" -f "$f"
done

echo "Migrations applied successfully"
