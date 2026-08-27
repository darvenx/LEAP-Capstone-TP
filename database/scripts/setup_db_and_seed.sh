#!/usr/bin/env bash
set -euo pipefail

# Usage: TARGET_DATABASE=mydb ./scripts/setup_db_and_seed.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR/.."

if [ -f ../.env ]; then
  set -a
  # shellcheck disable=SC1091
  . ../.env
  set +a
fi

TARGET_DB=${TARGET_DATABASE:-${POSTGRES_DB:-trade_db}}
PGHOST=${PGHOST:-localhost}
PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres}

PSQL=(psql -w -v ON_ERROR_STOP=1 -h "$PGHOST" -p "$PGPORT" -U "$PGUSER")

echo "Checking if database '$TARGET_DB' exists..."
EXISTS=$("${PSQL[@]}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${TARGET_DB}';")
if [ "$EXISTS" != "1" ]; then
  echo "Database does not exist — creating '${TARGET_DB}'"
  "${PSQL[@]}" -d postgres -c "CREATE DATABASE \"${TARGET_DB}\";"
else
  echo "Database '${TARGET_DB}' already exists"
fi

echo "Applying schema migrations to ${TARGET_DB}"
for migration in migrations/*.sql; do
  echo "Applying $migration"
  "${PSQL[@]}" -d "$TARGET_DB" -f "$migration"
done

echo "Loading SQL seed files"
for seed in seed/*.sql; do
  echo "Loading $seed"
  "${PSQL[@]}" -d "$TARGET_DB" -f "$seed"
done

echo "Seed loading complete"
