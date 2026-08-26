# LEAP Capstone — Enterprise Trading Platform

A retail-brokerage trading platform built one component per sprint. This
repository currently holds **Sprint 3 (trade database)** and **Sprint 4
(analytics & ETL pipeline)**. Later sprints (domain engine, Trade API, event
backbone, auth, UI, extensions) slot in as sibling folders.

```
Our-project/
├── .env / .env.example / .gitignore   # shared local config (secrets git-ignored)
├── docker-compose.yml                 # one-command Postgres (Sprint 3 schema + seed)
├── infra/postgres/                    # container init hook (mounts migrations + seed)
├── sprint-03-trade-database/          # migrations, seed (.sql), sql evidence, design docs
├── sprint-04-analytics-etl/           # installable Python ETL: extract/transform/load + dashboard
└── docs/                              # analysis, plans, progress, reviews
```

## Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| Python | 3.12+ (tested on 3.14) | Sprint 4 pipeline and tests |
| PostgreSQL client `psql` **or** Docker Desktop | PG 16 | Sprint 3 database |

## One-time setup

```bash
# 1. Copy the environment template and (optionally) add your Fauxnance key.
#    Without a key, Sprint 4 runs offline from committed fixtures.
cp .env.example .env        # Windows PowerShell: Copy-Item .env.example .env
```

---

## Sprint 3 — build and verify the trade database

Choose **one** path.

### Path A — Docker (no local Postgres needed)

```bash
docker compose up -d
```

This starts Postgres 16 and, on the first start (empty volume), applies every
migration then every seed file in order. Verify:

```bash
# the six named queries
docker compose exec -T postgres psql -U postgres -d trading -f /sprint-03/sql/verify_queries.sql
# the two required rejections (23505 duplicate key, 23503 FK violation)
docker compose exec -T postgres psql -U postgres -d trading -v ON_ERROR_STOP=0 -f /sprint-03/sql/failure_tests.sql
```

Rebuild from scratch: `docker compose down -v && docker compose up -d`.

### Path B — local Postgres (one command)

With `psql` on your PATH and a running Postgres, from
`sprint-03-trade-database/`:

```bash
# create the database if needed, then migrate + seed in one go
./scripts/create_db.sh              # or, if the DB already exists: ./scripts/apply.sh
```

Windows PowerShell equivalent (DB already exists):

```powershell
cd sprint-03-trade-database
./scripts/apply.ps1
```

The apply command reads `TARGET_DATABASE` (falling back to `POSTGRES_DB` from
`.env`), applies `migrations/*.sql` then `seed/*.sql` with
`psql -v ON_ERROR_STOP=1`, and exits non-zero on any failure. Then verify:

```bash
psql "$TARGET_DATABASE" -v ON_ERROR_STOP=1 -f sql/verify_queries.sql
psql "$TARGET_DATABASE" -v ON_ERROR_STOP=0 -f sql/failure_tests.sql
```

Design docs: `sprint-03-trade-database/DESIGN.md`, `design/er-diagram.md`,
`design/indexes.md`, `design/normalisation.md`.

---

## Sprint 4 — run the analytics & ETL pipeline

From the repository root (`Our-project/`):

```bash
# 1. Create a virtual environment and install the project with its dev extras.
python -m venv .venv

#    Windows PowerShell:
.venv\Scripts\python -m pip install -e "sprint-04-analytics-etl[dev]"
#    Linux/macOS:
.venv/bin/python -m pip install -e "sprint-04-analytics-etl[dev]"

# 2. Run the test suite (offline; no key, no network).
.venv\Scripts\python -m pytest sprint-04-analytics-etl      # Windows
.venv/bin/python -m pytest sprint-04-analytics-etl          # Linux/macOS

# 3. Run the pipeline. Writes analytics.duckdb and reports/report.html,
#    and prints a per-symbol summary.
.venv\Scripts\python -m analytics_etl                        # Windows
.venv/bin/python -m analytics_etl                            # Linux/macOS
#    (equivalently, the console script:)  analytics-etl
```

Open `sprint-04-analytics-etl/reports/report.html` in a browser (it needs no
network — plotly's JS is inlined). The three business claims are in
`sprint-04-analytics-etl/claims.md`.

### Going live on Fauxnance

The pipeline runs offline from the committed fixtures until you supply a key.
When you have one: put it in `.env` as `FAUXNANCE_API_KEY`, delete
`sprint-04-analytics-etl/.cache/`, and re-run. No code changes.

---

## Where things are documented

| Topic | File |
|---|---|
| Full platform blueprint | `docs/analysis/project-blueprint.md` |
| Sprint 4 analysis | `docs/analysis/current-sprint-analysis.md` |
| Sprint 4 plan | `docs/plans/sprint-04-implementation-plan.md` |
| Implementation progress log | `docs/progress/sprint-04-progress.md` |
| Sprint 4 review | `docs/reviews/sprint-04-review.md` |
