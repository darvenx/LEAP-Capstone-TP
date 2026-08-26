#!/usr/bin/env bash
#
# apply.sh - take an empty database to fully migrated and seeded, in one command.
#
# Run from the sprint-03-trade-database/ folder:
#
#     ./scripts/apply.sh
#
# Behaviour required by the Sprint 3 brief:
#   - applies every migrations/*.sql in filename order
#   - then loads every seed/*.sql in filename order
#   - reads the target database from TARGET_DATABASE, falling back to
#     POSTGRES_DB (loaded from the repository-root .env if present)
#   - runs without prompting and exits non-zero the moment anything fails
#     (psql -v ON_ERROR_STOP=1)
#
# Connection is taken from the standard libpq environment variables
# (PGHOST, PGPORT, PGUSER, PGPASSWORD). Nothing is prompted for.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$REPO_DB_DIR/.." && pwd)"

# Load POSTGRES_* / TARGET_DATABASE from the repository-root .env if present.
# Values already set in the environment win over the file.
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

# Default the connecting user to POSTGRES_USER when PGUSER is not set.
export PGUSER="${PGUSER:-${POSTGRES_USER:-postgres}}"
export PGPASSWORD="${PGPASSWORD:-${POSTGRES_PASSWORD:-}}"

PSQL=(psql -v ON_ERROR_STOP=1 --no-psqlrc -d "$TARGET_DB")

cd "$REPO_DB_DIR"

echo "==> Applying migrations to '$TARGET_DB'"
for f in migrations/*.sql; do
  echo "    migration: $f"
  "${PSQL[@]}" -f "$f"
done

echo "==> Loading seed data into '$TARGET_DB'"
for f in seed/*.sql; do
  echo "    seed: $f"
  "${PSQL[@]}" -f "$f"
done

echo "==> Done. '$TARGET_DB' is migrated and seeded."
