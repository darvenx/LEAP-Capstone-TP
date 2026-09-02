#!/usr/bin/env bash
#
# create_db.sh - local (non-Docker) one-line command.
#
# Recreates the target database, applies every migration, bulk-loads seed/csv,
# and runs probes/. Credentials come from the repository-root .env. Never
# prompts for a password (psql --no-password).
#
# Requires a running Postgres and `psql` on PATH.
#
#     ./scripts/create_db.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$REPO_DB_DIR/.." && pwd)"

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

export PGHOST="${PGHOST:-localhost}"
export PGUSER="${PGUSER:-${POSTGRES_USER:-postgres}}"
export PGPASSWORD="${PGPASSWORD:-${POSTGRES_PASSWORD:-}}"
if [ -z "$PGPASSWORD" ]; then
  echo "ERROR: set POSTGRES_PASSWORD in the repository-root .env (password prompt is disabled)" >&2
  exit 2
fi

PSQL=(psql -v ON_ERROR_STOP=1 --no-psqlrc --no-password)

cd "$REPO_DB_DIR"

echo "==> Recreating database '$TARGET_DB'"
"${PSQL[@]}" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${TARGET_DB}' AND pid <> pg_backend_pid();"
"${PSQL[@]}" -d postgres -c "DROP DATABASE IF EXISTS \"${TARGET_DB}\";"
"${PSQL[@]}" -d postgres -c "CREATE DATABASE \"${TARGET_DB}\";"

echo "==> Applying migrations to '$TARGET_DB'"
for f in migrations/*.sql; do
  echo "    migration: $f"
  "${PSQL[@]}" -d "$TARGET_DB" -f "$f"
done

echo "==> Loading CSV seed into '$TARGET_DB'"
"${PSQL[@]}" -d "$TARGET_DB" -f "$SCRIPT_DIR/load_csv.sql"

echo "==> Running probes"
"${PSQL[@]}" -d "$TARGET_DB" -f "$REPO_DB_DIR/probes/verify_queries.sql"
# Expected 23505 / 23503: do not abort the script on those errors.
psql -v ON_ERROR_STOP=0 --no-psqlrc --no-password -d "$TARGET_DB" \
  -f "$REPO_DB_DIR/probes/failure_tests.sql"

echo ""
echo "Done. '$TARGET_DB' is migrated, CSV-seeded and probe-tested."
