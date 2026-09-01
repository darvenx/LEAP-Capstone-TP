#!/usr/bin/env bash
#
# setup.sh - the Docker one-line command. Build the Sprint 3 database image and
# run a fully migrated + CSV-seeded + probe-tested Postgres 16 container.
#
#     ./scripts/setup.sh
#
# Credentials come from the repository-root .env if present, else safe local
# defaults. Override the published port with PGPORT (default 5432). Never
# prompts for a password.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"          # sprint-03-trade-database/
PROJECT_ROOT="$(cd "$DB_DIR/.." && pwd)"

# Load POSTGRES_* from the repo-root .env if present (values already in the
# environment win). Never fails if the file is absent.
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$PROJECT_ROOT/.env"
  set +a
fi

IMAGE="leap-trade-db:sprint03"
CONTAINER="leap-trade-db"
PORT="${PGPORT:-5432}"
DB="${POSTGRES_DB:-trading}"
USER_NAME="${POSTGRES_USER:-postgres}"
PASSWORD="${POSTGRES_PASSWORD:-postgres_dev_password}"

echo "==> Building image '$IMAGE'"
docker build -t "$IMAGE" "$DB_DIR"

echo "==> Removing any previous '$CONTAINER' container"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

echo "==> Starting '$CONTAINER' on localhost:$PORT (db '$DB')"
docker run -d \
  --name "$CONTAINER" \
  -p "$PORT:5432" \
  -e POSTGRES_DB="$DB" \
  -e POSTGRES_USER="$USER_NAME" \
  -e POSTGRES_PASSWORD="$PASSWORD" \
  "$IMAGE" >/dev/null

echo "==> Waiting for init (migrations, CSV seed, probes) to finish"
deadline=$((SECONDS + 120))
until docker logs "$CONTAINER" 2>&1 | grep -q "PostgreSQL init process complete"; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "ERROR: timed out waiting for database init. Last logs:" >&2
    docker logs "$CONTAINER" >&2 || true
    exit 1
  fi
  # Surface an init failure instead of spinning until the timeout.
  if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo "ERROR: container '$CONTAINER' exited before init finished. Logs:" >&2
    docker logs "$CONTAINER" >&2 || true
    exit 1
  fi
  sleep 1
done

until docker exec -e PGPASSWORD="$PASSWORD" "$CONTAINER" \
    pg_isready -U "$USER_NAME" -d "$DB" >/dev/null 2>&1; do
  sleep 1
done

echo "==> Running probes"
docker exec -e PGPASSWORD="$PASSWORD" "$CONTAINER" \
  psql -v ON_ERROR_STOP=1 --no-psqlrc --no-password -U "$USER_NAME" -d "$DB" \
  -f /schema/probes/verify_queries.sql
docker exec -e PGPASSWORD="$PASSWORD" "$CONTAINER" \
  psql -v ON_ERROR_STOP=0 --no-psqlrc --no-password -U "$USER_NAME" -d "$DB" \
  -f /schema/probes/failure_tests.sql

echo ""
echo "Done. Postgres 16 is migrated, CSV-seeded and probe-tested at localhost:$PORT."
echo "  Connect:  psql -h localhost -p $PORT -U $USER_NAME -d $DB"
echo "  Logs:     docker logs -f $CONTAINER"
echo "  Rebuild:  docker rm -f $CONTAINER && ./scripts/setup.sh"
