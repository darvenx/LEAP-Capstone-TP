# Sprint 4 Implementation Progress

Living log of every significant change made while implementing
`docs/plans/sprint-04-implementation-plan.md`. Newest entries at the bottom of
each section.

## Decisions taken (the plan's five open questions)

The plan (Section "Open decisions to confirm") left five choices. All five are
resolved here in line with the plan's stated recommendation, because the plan is
approved and these are the pre-first-review, contract-driven defaults:

| # | Decision | Choice | Why |
|---|---|---|---|
| 1 | Re-baseline `001…0NN` vs additive `015_…` | **Re-baseline** | Pre-first-review; base migration `007` never applied (invalid enum default); split-brain must be removed from history, not layered over. |
| 2 | Account PK `UUID` → `BIGINT` identity | **BIGINT identity `id` + string `account_id`** | `trade-api.yaml` path/JWT `accountId` is int64 = `ACCOUNTS.id`; `AccountResponse.accountId` is the string ref; `analytics-schema.dim_account.source_id BIGINT`. UUID PK cannot satisfy either. |
| 3 | Seed as `.sql` vs CSV `\copy` | **Numbered `.sql`** | Sprint 3 brief: "seed data, as `.sql` files"; also mounts cleanly into `/docker-entrypoint-initdb.d`. |
| 4 | Negative-volume disposition | **Null the volume, keep OHLC** | OHLC is valid and charted; volume is a separate, non-charted-here measure. |
| 5 | Create `.env` / `.env.example` now | **Yes, now** | They carry only placeholders (no secret), and Sprint 4 reads `FAUXNANCE_*`. |

---

## Change log

### 2026-08-26 — Sprint 3 re-baseline (remediation)

**Change description.** Replaced the internally contradictory `database/` folder
with a coherent, contract-aligned `sprint-03-trade-database/`. Re-baselined the
migration set into `001…015`, converted the seed to numbered `.sql`, rewrote the
`sql/` evidence files against the real schema, added the missing design docs,
replaced the apply command, and deleted the redundant `schema.sql` aggregator and
the interactive/broken scripts.

**Reason for change.** Sprint 3 had a "split-brain": migrations described
`trading_accounts/holdings/orders(order_type,limit_price)` while `sql/` and the
setup script referenced a phantom `accounts/positions/trades/currencies` schema.
Migration `007` could not even apply (`status ... DEFAULT 'OPEN'` is not a member
of the `order_status` enum). Left as-is, the database could not be built and the
Sprint 7 ETL repoint would have no valid source. (Plan Section A.0–A.2, C.)

**Files modified / created.**
- New: `sprint-03-trade-database/migrations/001_extensions.sql … 015_indexes.sql` (15 files).
- New: `sprint-03-trade-database/seed/001_users.sql … 006_cash_ledger.sql` + `seed/README.md`.
- New: `sprint-03-trade-database/sql/failure_tests.sql`, `sql/verify_queries.sql`.
- New: `sprint-03-trade-database/scripts/apply.sh`, `apply.ps1`, `create_db.sh`.
- New: `sprint-03-trade-database/DESIGN.md`, `design/er-diagram.md`, `design/indexes.md`, `design/normalisation.md`.
- Deleted: entire old `database/` tree (14 migrations, `schema.sql`, 2 scripts, 2 sql files, 13 seed CSVs, seed README).

**Key schema corrections.** `accounts` now has BIGINT identity `id` + string
`account_id` + `holder_name` + `currency` + `status` + `version`; `orders` has
`idempotency_key UNIQUE`, `INTEGER quantity`, `DECIMAL price`, nullable
`executed_price`, default `'NEW'`, dropped `order_type`/`remaining_quantity`;
`holdings`→`positions` with `average_cost`; `instruments` has `symbol`/
`asset_class`/`currency`/`tradable` (dropped `sector`). `DECIMAL(18,2)` money
throughout. Matching-model `order_executions` removed.

**Future dependency impact.**
- **S5 domain:** enums (`account_status`, `order_side`, `order_status`), `version`,
  unique `idempotency_key` now exist to build entities against.
- **S6 Trade API:** schema now matches `trade-api.yaml` exactly (both account ids,
  decimal cash, status, version, positions with avg cost, all order states,
  `23505` on dup key).
- **S7 executor + ETL:** `orders.id`↔`fact_trades.source_order_id` unique;
  `created_on` indexed as the incremental watermark; `executed_price` present;
  `executed_on`/`rejection_reason` deliberately deferred to the S7 `016_…`
  migration.
- **S10:** extension tables retained; `positions.average_cost` present.

### 2026-08-26 — Root config (.env, .env.example, .gitignore)

**Change description.** Added `Our-project/.env.example` (committed template),
`Our-project/.env` (git-ignored, placeholder key only), and
`Our-project/.gitignore`.

**Reason for change.** Sprint 4 reads `FAUXNANCE_BASE_URL`/`FAUXNANCE_API_KEY`
and the apply command reads `POSTGRES_*`/`TARGET_DATABASE`; the analysis flagged
the missing `.env.example` as a Sprint 4 blocker. The rule "create `.env.example`
if new variables are introduced" applies. (Plan A.4/A.5, Section E.)

**Files modified / created.** `.env.example`, `.env`, `.gitignore` (all new, root).

**Future dependency impact.** The template carries Kafka (S7) and JWT (S6/S8)
variables now so it is complete; those are not read in Sprint 4. No secret is
committed; the key stays a placeholder until issued.

### 2026-08-26 — Sprint 4 analytics ETL project

**Change description.** Built the installable `sprint-04-analytics-etl` package:
`config`, `fauxnance_client`, `extract`, `transform`, `load`, `dashboard`, and a
`__main__` runner (plus console script `analytics-etl`). Copied the three
fixtures, wrote 21 pytest cases, and added `README.md` and `claims.md`.

**Reason for change.** Sprint 4's core deliverable: separated E/T/L over
Fauxnance candles into DuckDB with an offline dashboard and three business
claims. (Plan A.3, A.6, A.8, Section B.2, G.)

**Files modified / created.** `pyproject.toml`; `src/analytics_etl/*.py` (8
modules); `fixtures/*.json` (3); `tests/*.py` (4 incl. `conftest`);
`README.md`; `claims.md`; `.gitignore`; generated `reports/report.html`.

**Verification (run on this host).**
- `pip install -e 'sprint-04-analytics-etl[dev]'` succeeds on a clean venv
  (Python 3.14; wheels resolved for all deps).
- `python -m pytest sprint-04-analytics-etl` → **21 passed**, including
  `test_rejects_a_high_below_a_low` and the four extract error cases.
- `python -m analytics_etl` → 19 clean rows, 5 quarantined (the malformed BSE
  defects), `reports/report.html` written, per-symbol summary printed.

**Future dependency impact.**
- **S7 repoint:** `transform` is pure and source-agnostic; `load` is idempotent
  on a natural key; the DuckDB target and the E/T/L split are frozen so Sprint 7
  swaps the source (candles → Postgres orders) and the load target
  (`market_candles` → `fact_trades` + dims) without reshaping the pipeline.
- The Fauxnance client's four-way error handling and `.cache/` strategy are what
  the Sprint 7 poller reuses.

### 2026-08-26 — Infra: Docker one-command database

**Change description.** Added `docker-compose.yml` (Postgres 16 service) and
`infra/postgres/initdb/01_apply.sh` + `infra/postgres/README.md`. `docker compose
up -d` builds the schema and loads the seed unattended on an empty volume by
mounting `sprint-03-trade-database/` and running the numbered migrations then
seed in filename order.

**Reason for change.** The brief/infra requirements: Postgres starts empty and
the migrations+seed mount into `/docker-entrypoint-initdb.d`, filename order, so
a fresh start builds the database unattended. The init hook reads the same
numbered files as the local apply command, avoiding a drift-prone copy.

**Files modified / created.** `docker-compose.yml`, `infra/postgres/initdb/01_apply.sh`,
`infra/postgres/README.md`.

**Verification note.** Docker and a local `psql` are **not installed on this
host**, so the container path and the raw SQL apply were validated by review, not
executed. The Python pipeline (which the host can run) passes fully. Running the
DB path on a machine with Docker/psql is step 1–3 of the root README.

**Future dependency impact.** Sprint 6 mounts the same folder into its Postgres
container; Kafka/Trade API/executor/auth services slot into this compose file as
siblings in later sprints.

### 2026-08-26 — Docs and close-out

**Change description.** Updated the root `README.md` with the complete
setup/run steps for Sprints 3 and 4 (Docker path, local `psql` path, Python
pipeline), and wrote `docs/reviews/sprint-04-review.md`. Removed the now-empty
old `database/` directory.

**Files modified / created.** `README.md` (rewritten), `docs/reviews/sprint-04-review.md`
(new). Old `database/` tree removed.

**Status.** Sprint 4 implementation complete. Python pipeline and 21 tests pass
on this host; the database path is code-complete and awaits a run on a machine
with Docker or `psql` to capture the `23505`/`23503` and query evidence.

### 2026-08-26 — Consolidated migrations and seed into single files (by request)

**Change description.** Merged the 15 numbered migrations into one
`migrations/001_schema.sql` (extensions → enums → tables in dependency order →
indexes) and the 6 numbered seed files into one `seed/001_seed.sql` (FK order
preserved). Deleted the 21 individual files. Updated `DESIGN.md`,
`design/indexes.md`, `seed/README.md` and `docs/reviews/sprint-04-review.md`
wording to reference the consolidated files.

**Reason for change.** User request to reduce the number of files. The apply
command (`scripts/apply.sh`/`apply.ps1`) and the Docker init hook already glob
`migrations/*.sql` and `seed/*.sql`, so no script change was needed — a single
file per directory is applied exactly as before.

**Files modified / created.** New: `migrations/001_schema.sql`, `seed/001_seed.sql`.
Deleted: `migrations/001_extensions.sql`…`015_indexes.sql`,
`seed/001_users.sql`…`006_cash_ledger.sql`. Updated: `DESIGN.md`,
`design/indexes.md`, `seed/README.md`, `docs/reviews/sprint-04-review.md`.

**Trade-off noted.** The Sprint 3 brief treats numbered migrations as the
versioning unit (acceptance criterion 2). Consolidation reduces file count at the
cost of that per-change granularity. Discipline going forward: schema changes are
new numbered files (`002_...`), not edits to `001_schema.sql` after the first
design review.

**Future dependency impact.** None functional — the schema and seed content are
byte-for-byte equivalent to the previous multi-file set; only the file layout
changed. Sprint 6's Postgres container mounts the same folder and picks up the
single file transparently.

### 2026-08-26 — Expanded seed to ~10 rows per table (by request)

**Change description.** Grew `seed/001_seed.sql` from a minimal set to a
realistic dataset: 10 users, 10 accounts, 10 instruments, 15 orders, 10
positions, 20 cash-ledger rows, 10 watchlists + 10 items, 10 price alerts, 10
notifications, 10 portfolio snapshots, 10 audit logs.

**Reason for change.** User request for realistic, sensible data. More coverage
also makes Sprint 6 API testing and the Sprint 4/7 analytics more meaningful.

**Consistency preserved.** Every position reconciles against the account's FILLED
orders (sell reduces quantity, leaves average cost); every account's
`cash_balance` equals the sum of its `cash_ledger` rows; suspended/closed
accounts placed no orders after losing ACTIVE status; symbols are ones Fauxnance
serves; timestamps spread Feb–Jul 2026.

**Files modified.** `seed/001_seed.sql` (rewritten), `seed/README.md` (coverage
table updated). `sql/verify_queries.sql` and `sql/failure_tests.sql` still use
`ACC-000001`, which remains the richest account.

**Verification note.** Still not run here (no Docker/`psql` on this host); the
reconciliations were checked by hand. The Sprint 4 Python suite is unaffected
(it reads fixtures, not the DB) and still passes.
