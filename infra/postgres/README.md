# Postgres container

The root `docker-compose.yml` starts PostgreSQL and mounts the canonical
`database/migrations/` and `database/seed/` directories read-only. Docker runs
`001_initialize.sql` once, on an empty data volume, and applies the same files
as the local PowerShell runner.

From the repository root:

```powershell
docker compose --env-file .\manifest.env up -d
```

The database is available at `localhost:5432` with the values in
`manifest.env`. To watch initialization logs:

```powershell
docker compose logs -f postgres
```

To rebuild from scratch after changing migrations or seed data:

```powershell
docker compose down -v
docker compose --env-file .\manifest.env up -d
```

Do not use `down -v` if the database contains data you need to keep.
