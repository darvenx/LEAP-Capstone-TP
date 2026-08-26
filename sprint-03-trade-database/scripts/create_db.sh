#!/usr/bin/env bash
#
# create_db.sh - convenience helper that creates the target database if it does
# not already exist, then hands off to apply.sh. Not required by the brief (the
# apply command targets an existing empty database) but handy for a local,
# non-Docker Postgres. Non-interactive: reads connection from libpq env vars.
#
#     ./scripts/create_db.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$PROJECT_ROOT/.env"
  set +a
fi

TARGET_DB="${TARGET_DATABASE:-${POSTGRES_DB:-}}"
if [ -z "$TARGET_DB" ]; then
  echo "ERROR: set TARGET_DATABASE, or POSTGRES_DB in the repository-root .env" >&2
  exit 2
fi

export PGUSER="${PGUSER:-${POSTGRES_USER:-postgres}}"
export PGPASSWORD="${PGPASSWORD:-${POSTGRES_PASSWORD:-}}"

EXISTS="$(psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${TARGET_DB}'" || true)"
if [ "$EXISTS" = "1" ]; then
  echo "Database '$TARGET_DB' already exists."
else
  echo "Creating database '$TARGET_DB'."
  psql -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"${TARGET_DB}\";"
fi

exec "$SCRIPT_DIR/apply.sh"
