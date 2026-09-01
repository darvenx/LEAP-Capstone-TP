#!/usr/bin/env bash
#
# docker_init.sh - Postgres container init hook for the CSV one-line setup.
#
# The postgres image runs every file in /docker-entrypoint-initdb.d once, on an
# empty data volume. This hook:
#   1. applies migrations/*.sql in filename order (001, 002, 003, ...),
#   2. bulk-loads the seed from seed/csv/*.csv with COPY (scripts/load_csv.sql),
#   3. runs probes/ (named queries + expected constraint rejections),
# all with ON_ERROR_STOP so any failure aborts the build with a non-zero exit
# (failure_tests.sql is the exception: ON_ERROR_STOP is off because those
# statements are supposed to error).
#
# The equivalent .sql seed (seed/001_seed.sql) is for the local, non-Docker
# apply command; both produce the same rows.
set -euo pipefail

SCHEMA_DIR=/schema

psql=(psql -v ON_ERROR_STOP=1 --no-psqlrc --no-password --username "$POSTGRES_USER" --dbname "$POSTGRES_DB")

echo "==> [initdb] applying migrations to '$POSTGRES_DB'"
for f in "$SCHEMA_DIR"/migrations/*.sql; do
  echo "    migration: $(basename "$f")"
  "${psql[@]}" -f "$f"
done

echo "==> [initdb] loading CSV seed into '$POSTGRES_DB'"
# \copy paths in load_csv.sql are relative to the client cwd.
cd "$SCHEMA_DIR"
"${psql[@]}" -f "$SCHEMA_DIR/scripts/load_csv.sql"

echo "==> [initdb] running probes"
"${psql[@]}" -f "$SCHEMA_DIR/probes/verify_queries.sql"
# Expected 23505 / 23503: do not abort the script on those errors.
psql -v ON_ERROR_STOP=0 --no-psqlrc --no-password --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -f "$SCHEMA_DIR/probes/failure_tests.sql"

echo "==> [initdb] Sprint 3 schema, CSV seed and probes applied."
