Seed files for the trade database

Run `scripts/setup_db_and_seed.sh` from the `database/` directory with
`TARGET_DATABASE` set (or with `POSTGRES_DB` in the repository `.env`). The
command applies every migration and then every `seed/*.sql` file in filename
order. It never prompts; provide PostgreSQL authentication through the normal
`PGPASSWORD`, `.pgpass`, or `PGSERVICE` mechanism.

`001_core.sql` is deterministic and is intended to load into an empty
database. Reload by recreating the database rather than merging fixtures.
