#!/bin/bash
#
# 01_apply.sh - Postgres container init hook.
#
# Postgres runs every file in /docker-entrypoint-initdb.d once, in filename
# order, the first time it starts against an empty data volume. This script
# applies the Sprint 3 migrations and seed from the mounted source tree, so a
# fresh `docker compose up` builds the schema and loads the fixtures unattended.
#
# It reads the same numbered files the local apply command uses (mounted at
# /sprint-03), so there is no duplicated, drift-prone copy of the SQL.
set -euo pipefail

SRC=/sprint-03

echo "==> [initdb] applying migrations to '$POSTGRES_DB'"
for f in "$SRC"/migrations/*.sql; do
  echo "    migration: $(basename "$f")"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
done

echo "==> [initdb] loading seed into '$POSTGRES_DB'"
for f in "$SRC"/seed/*.sql; do
  echo "    seed: $(basename "$f")"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
done

echo "==> [initdb] Sprint 3 schema and seed applied."
