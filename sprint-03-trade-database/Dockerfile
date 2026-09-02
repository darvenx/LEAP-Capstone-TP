# Sprint 3 trade database - a Postgres 16 image that builds itself.
#
# On its first start (empty data volume) it applies every migration, bulk-loads
# the CSV seed, and runs probes/, so `scripts/setup.sh` / `scripts/setup.ps1`
# give a one-line, fully migrated-seeded-and-tested database with no manual step.
#
# Build context is this folder (sprint-03-trade-database/).
FROM postgres:16

# Migrations, CSV seed, COPY script and probes, baked into the image (not
# mounted), so the image is self-contained and reproducible.
COPY migrations/          /schema/migrations/
COPY seed/csv/            /schema/seed/csv/
COPY scripts/load_csv.sql /schema/scripts/load_csv.sql
COPY probes/              /schema/probes/

# The init hook Postgres runs once on an empty volume. Files in this directory
# run in filename order; the 10_ prefix leaves room for earlier hooks if needed.
COPY scripts/docker_init.sh /docker-entrypoint-initdb.d/10_init.sh
RUN chmod +x /docker-entrypoint-initdb.d/10_init.sh

EXPOSE 5432
