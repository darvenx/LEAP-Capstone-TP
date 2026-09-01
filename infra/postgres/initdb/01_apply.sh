#!/bin/bash
#
# 01_apply.sh - Postgres container init hook.
#
# Postgres runs every file in /docker-entrypoint-initdb.d once, in filename
# order, the first time it starts against an empty data volume. This script
# applies the Sprint 3 migrations, CSV seed and probes from the mounted source
# tree, so a fresh `docker compose up` builds, seeds and tests unattended.
#
# It reads the same numbered files the local apply command uses (mounted at
# /sprint-03), so there is no duplicated, drift-prone copy of the SQL.
set -euo pipefail

SRC=/sprint-03

echo "==> [initdb] applying migrations to '$POSTGRES_DB'"
for f in "$SRC"/migrations/*.sql; do
  echo "    migration: $(basename "$f")"
  psql -v ON_ERROR_STOP=1 --no-psqlrc --no-password --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
done

echo "==> [initdb] loading CSV seed into '$POSTGRES_DB'"
# \copy paths in load_csv.sql are relative to the client cwd.
cd "$SRC"
psql -v ON_ERROR_STOP=1 --no-psqlrc --no-password --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -f "$SRC/scripts/load_csv.sql"

echo "==> [initdb] running probes"
psql -v ON_ERROR_STOP=1 --no-psqlrc --no-password --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -f "$SRC/probes/verify_queries.sql"
# Expected 23505 / 23503: do not abort the script on those errors.
psql -v ON_ERROR_STOP=0 --no-psqlrc --no-password --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -f "$SRC/probes/failure_tests.sql"

echo "==> [initdb] Sprint 3 schema, CSV seed and probes applied."
