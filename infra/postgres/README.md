# Postgres initialisation

The `postgres` service in the repository-root `docker-compose.yml` mounts:

- `sprint-03-trade-database/` at `/sprint-03` (read-only) — the migrations and
  seed, the single source of truth.
- `infra/postgres/initdb/` at `/docker-entrypoint-initdb.d` (read-only) — the
  init hook Postgres runs on first start.

`initdb/01_apply.sh` runs once, on an empty data volume, in filename order. It
applies every `sprint-03/migrations/*.sql` and then every `sprint-03/seed/*.sql`
with `psql -v ON_ERROR_STOP=1`, so a fresh `docker compose up` builds the schema
and loads the fixtures with no manual step. Because it reads the same numbered
files the local apply command uses, there is no second, drift-prone copy of the
SQL to keep in step (the concern the reference `infra/postgres/README.md`
raises).

## Rebuilding

Nothing in `initdb/` re-runs against a volume that already has data. To apply a
schema change, reset the volume:

```bash
docker compose down -v      # removes the postgres volume
docker compose up -d        # re-runs the init hook from scratch
```
