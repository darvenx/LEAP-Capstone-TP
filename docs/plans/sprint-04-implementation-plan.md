# Sprint 4 Implementation Plan — Analytics & ETL (+ Sprint 3 remediation)

> **Status: plan only. Nothing in this document has been implemented.** It is the design
> contract for the next chat, where the actual code, migrations, config and tests will be
> written. It also records the Sprint 3 database defects that must be fixed *now* so the
> Sprint 4 pipeline repoints cleanly in Sprint 7.
>
> **Sources read in full:** `docs/analysis/project-blueprint.md`, `docs/analysis/current-sprint-analysis.md`,
> `reference-repo/` (root `README`, `.env.example`, `.gitignore`, `contracts/analytics-schema.sql`,
> `contracts/trade-api.yaml`, `infra/postgres/README.md`, `sprint-03-trade-database/`,
> `sprint-04-analytics-etl/` incl. the three candle fixtures and `fixtures/README.md`), and every
> file under `Our-project/` (all 14 migrations, `schema.sql`, both scripts, both `sql/` files, all
> seed CSVs).
>
> **Binding precedence:** `reference-repo/` binds over `Project.pdf`; the five `contracts/` bind over
> everything (a renamed field breaks a generated client). `.NS` = NSE, `.BO` = BSE.

---

## SECTION A — Required changes

This section answers the ten planning requirements directly.

### A.0 The headline finding — Sprint 3 has a "split-brain" and will not build today

The Sprint 3 code is not merely missing columns; it contains **two mutually inconsistent schemas**
and at least one migration that cannot execute. This is more than the sprint analysis flagged and it
must be reconciled before anything downstream is trusted.

| # | Problem | Evidence | Effect |
|---|---|---|---|
| SB-1 | **Two different schemas coexist.** The `migrations/` describe tables `trading_accounts`, `holdings`, `orders(order_id, order_type, remaining_quantity, limit_price)`. But `sql/failure_tests.sql`, `sql/verify_queries.sql` and `scripts/setup_db_and_seed.sh` reference a *different, non-existent* schema: `accounts`, `positions`, `trades`, `account_ledger`, `currencies`, `orders(id, idempotency_key, price, state, filled_at)`. | `sql/verify_queries.sql` lines 4–19; `sql/failure_tests.sql` lines 3–16; `scripts/setup_db_and_seed.sh` line 34 (`currencies.csv`). | Every file in `sql/` and the seed script fails immediately against the migrated DB. The repo is internally contradictory. |
| SB-2 | **Migration `007_create_orders.sql` cannot apply.** `status order_status NOT NULL DEFAULT 'OPEN'`, but the `order_status` enum (migration 001) is `NEW/FILLED/CANCELLED/REJECTED` — `'OPEN'` is not a member. | `007` line 24 vs `001` lines 25–30. | `CREATE TABLE orders` errors with `invalid input value for enum order_status: "OPEN"`. The database cannot be built from the migrations as written. |
| SB-3 | **Redundant `schema.sql` aggregator.** `schema.sql` only re-`\i`-includes the 14 migrations. It duplicates the migration list and is a second source of truth that will drift. | `schema.sql` lines 1–15. | This is the "main sql file + sub sql files" redundancy called out in the request. Versioning is supposed to *be* the numbered migrations; the aggregator is not required. |
| SB-4 | **`setup_db_and_seed.sh` applies `schema.sql`, not the migration folder, and loads a `currencies` table that no migration creates.** It also prompts for a password (breaks the "runs without prompting" acceptance rule). | `setup_db_and_seed.sh` lines 11–16, 30, 34. | Seed load fails; the apply command is not the unattended, non-zero-on-failure command Sprint 3 requires. |

**Consequence:** the "does Sprint 3 need modification?" question (requirement 1) is answered
decisively — **yes**, and not just additively. See A.1.

### A.1 Requirement 1 — Does Sprint 3 code require modification?

**Yes.** Two layers of change:

1. **Correctness/consistency (blocking, do now):** reconcile the split-brain (SB-1…SB-4), fix the
   broken `007`, and close the data-model gaps the sprint analysis raised (idempotency key, account
   `status`/`version`, instrument `asset_class`/`currency`, `holder_name` source, the
   `order_type`/partial-fill divergence, the `order_executions` matching table).
2. **Structure/format (do now):** the folder and versioning layout must match the reference format
   (numbered migrations as the single versioned source of truth; `design/` docs; `DESIGN.md`;
   `.sql` seed; a proper apply command).

**Migration strategy decision (major — see justification):** because the project is **pre-first
design-review**, no teammate has a populated database yet, and the current migrations are internally
broken (SB-2) and contradict a phantom schema (SB-1), the plan is a **one-time corrective
re-baseline** of the migration set `001…015` into one coherent, contract-aligned design — *not* a
stack of "fix-up" migrations layered on a base that never applied. The reference explicitly permits
in-place migration edits *until the first design review* precisely for this convergence phase. From
the design review onward, migrations become immutable and every change is a new numbered file
(`016_…`), which is the versioning discipline the request asks for.

> Alternative (documented, not chosen): keep `001–014` verbatim and add `015_…`, `016_…` fixes. This
> is rejected here because it cannot fix SB-2 (a base migration that never applies) without editing
> `007` anyway, and it bakes the split-brain permanently into history. If the team prefers the
> purely-additive route, that is a one-line decision to flip in the implementation chat.

### A.2 Requirement 4 — Database changes (the corrected model)

Target operational schema (PostgreSQL 16), aligned to `trade-api.yaml` and able to feed
`contracts/analytics-schema.sql`. Key corrections vs today:

| Area | Today | Change | Driver |
|---|---|---|---|
| **Account identity** | PK `account_id UUID`, plus `account_number` string | Numeric surrogate `id BIGINT GENERATED ALWAYS AS IDENTITY` (PK) **and** business `account_id VARCHAR(32) UNIQUE` (e.g. `ACC-000001`) | `trade-api.yaml`: path/`accountId` = numeric `ACCOUNTS.id` (int64); `AccountResponse.accountId` = string. `analytics-schema.dim_account.source_id BIGINT` = operational `accounts.id`. UUID PK cannot satisfy either. |
| **Account state** | none (only on `users`) | Add `status account_status NOT NULL DEFAULT 'ACTIVE'` + `CHECK` | Rules 2 (`ACC-403`), "suspended can't trade"; `dim_account` SCD2; analysis blocker #2 |
| **Optimistic lock** | none | Add `version INT NOT NULL DEFAULT 0` | Rule for `ORD-409` lost-update; NFR-02; analysis blocker #2 |
| **Holder name** | none | Add `holder_name` (on account) | `AccountResponse.holderName`, `dim_account.holder_name`; analysis #5 |
| **Account currency** | none | Add `currency CHAR(3) NOT NULL DEFAULT 'INR'` | `BalanceResponse.currency` |
| **Idempotency** | `orders` has none | Add `idempotency_key VARCHAR(100) NOT NULL` + `UNIQUE` | Rule 8, `23505` demo, `fact_trades.source_order_id` uniqueness; analysis blocker #1 |
| **Order shape** | `order_type` (MARKET/LIMIT), `remaining_quantity`, `limit_price`, `NUMERIC(18,4)` qty | Drop `order_type` + `remaining_quantity`; rename `limit_price`→`price DECIMAL(18,2) NOT NULL CHECK>0`; `quantity INTEGER CHECK>0`; add `executed_price DECIMAL(18,2) NULL` | Domain: single limit price, no partial fills, one terminal state; contract `quantity` int32≥1; analysis #4 |
| **Order status** | enum has `NEW/FILLED/CANCELLED/REJECTED` but default `'OPEN'` (invalid) | Default `'NEW'`; keep the four states only | SB-2; contract `OrderStatus` |
| **Instrument** | `ticker`, `sector`, `is_active` | Rename `ticker`→`symbol` (Fauxnance scheme); drop `sector`; add `asset_class VARCHAR(20)`, `currency CHAR(3)`; keep `exchange`; keep tradable flag (`is_active`→`tradable`) | `dim_instrument` needs `asset_class`+`currency`+`exchange`; S4 "by asset class" claim; delist = flag; analysis blocker #3 |
| **Positions** | table `holdings`, `quantity NUMERIC(18,4)` | Rename to `positions`; `quantity INTEGER CHECK>=0`; `average_buy_price`→`average_cost DECIMAL(18,2)`; keep `UNIQUE(account_id,instrument_id)` | Domain (no fractional shares, no shorting); `PositionResponse`; reconciles the `sql/` references |
| **Order matching** | `order_executions` (buy/sell matching) seed + CSV | Remove | Platform model is executor-fills-vs-price, not order matching; analysis #6 |
| **Money type** | `NUMERIC` | Use `DECIMAL(18,2)` consistently (money) / `INTEGER` (quantities) | Blueprint "money is decimal"; analytics contract uses `DECIMAL` |

Extension tables (`watchlists`, `watchlist_items`, `price_alerts`, `notifications`,
`portfolio_snapshots`, `audit_logs`) are **retained** — they are the Sprint 10 superset the blueprint
sanctions and cost nothing now. `price_alerts`/`watchlist_items` FK to instruments already; they only
inherit the `instruments` rename (`ticker`→`symbol` is internal id-based, so no FK change).

**Not changed this sprint (deferred to Sprint 7, by design):** `orders.executed_on` and
`orders.rejection_reason` are added by the Sprint 7 executor migration (`016_…`), exactly as the
blueprint sequences it. Adding them now would be speculative.

### A.3 Requirement 5 — ETL pipelines

One pipeline, three pure stages + a runner, built so Sprint 7 repoints it from candles to Postgres
without reshaping (this is the whole point of Sprint 4).

```
FAUXNANCE  GET /candles/{symbol}          .cache/{symbol}_{range}.json (raw)
   (X-Api-Key, key from env)  ── extract ──►  raw JSON  ── transform ──►  clean frame + quarantine
                                                                                   │  load
                                                                                   ▼
                                                                        DuckDB  (market_candles now;
                                                                        star schema in Sprint 7)
                                                                                   │
                                                                                   ▼
                                                          offline HTML dashboard (plotly, inlined JS)
```

- **extract** (network + key only): calls Fauxnance, caches raw response to `.cache/` keyed by
  symbol+range, returns raw JSON unchanged. Four-way error handling lives here (429 / other 4xx /
  network / and it hands 200-with-bad-data to transform untouched).
- **transform** (pure, no I/O, no env): parse → type → clean → derive; applies the six malformed-fixture
  decisions (A.6); returns a clean rows collection + a quarantine collection.
- **load** (DuckDB write only): idempotent upsert into DuckDB keyed on (symbol, date).
- **runner** (`__main__` + console script): wires extract→transform→load for the symbol universe,
  writes the dashboard artefacts, prints a per-symbol summary.

**Source-for-now decision:** we have no Fauxnance key yet. The client is written for real, but the
pipeline runs **offline now** by pre-seeding `.cache/` from the three reference fixtures
(`candles-*.json`) — the fixtures carry the exact `CandlesResponse` envelope the live API returns.
Flipping to live is then just: put a real key in `.env`, clear `.cache/`, re-run. No code change.
(Details in A.8 and Section F.)

### A.4 Requirement 6 — Configuration changes

- Add `Our-project/.env.example` (committed) — copied from `reference-repo/.env.example`.
- Add `Our-project/.env` (git-ignored) — same keys, `FAUXNANCE_API_KEY` left as the placeholder
  until the real key arrives. **No secret is committed.**
- Add `Our-project/.gitignore` — ignore `.env`, `.cache/`, `*.duckdb`, `*.duckdb.wal`, `*.egg-info/`,
  `.venv/`, `__pycache__/` (merges the reference root `.gitignore` and the Sprint 4 `.gitignore`).
- `sprint-04-analytics-etl/pyproject.toml` — packaging + `[dev]` extra (pytest) + dependency pins.
- Fix the apply command so it is unattended and non-zero-on-failure (A.2/Section C), reads
  `TARGET_DATABASE` → falls back to `POSTGRES_DB`.

### A.5 Requirement 7 — Environment variables

Full list in **Section E**. Sprint 4 only *reads* `FAUXNANCE_BASE_URL` and `FAUXNANCE_API_KEY`; the
DB apply command reads `TARGET_DATABASE`/`POSTGRES_*`. Kafka/JWT vars are carried in `.env.example`
now (so the template is complete) but consumed later.

### A.6 Requirement 9 — Test strategy (summary; full plan in Section G)

- **transform** unit tests (the assessed core): one test per malformed defect, including the
  mandated `test_rejects_a_high_below_a_low`; plus happy-path typing, dedupe, calendar-gap tolerance,
  null-volume tolerance, `synthetic` handling.
- **extract** tests: cache hit avoids a second call; 429 stops; other-4xx fails one symbol and
  continues; network error retries with backoff then gives up. All offline via fixtures/mocks; the
  suite never opens a socket and never needs a key.
- **load** tests: re-running the same frame does not double-count (idempotency).
- **DB**: `sql/failure_tests.sql` proves `23505` (dup idempotency key) and `23503` (FK violation)
  against the *real* corrected schema; `sql/verify_queries.sql` returns sensible rows for the six
  named queries against seed.

### A.7 Requirement 10 — Documentation updates

- **New:** `docs/plans/sprint-04-implementation-plan.md` (this file).
- **New (Sprint 3 completeness, required by the brief):** `sprint-03-trade-database/DESIGN.md`
  (historical trade data), `design/er-diagram.md` (Mermaid), `design/indexes.md` (≥3 indexes, each
  tied to a named query), `design/normalisation.md` (3NF notes + deliberate denormalisation).
- **New (Sprint 4):** `sprint-04-analytics-etl/README.md`, `claims.md` (three business claims),
  the dashboard artefact(s).
- **Update:** `Our-project/README.md` (root: how to build DB + run ETL); append a Sprint 4 section to
  `docs/analysis/current-sprint-analysis.md` progress if desired.
- **Decision log candidates** (from blueprint §11/§12): re-baseline vs additive migrations; UUID→BIGINT
  account id; each malformed-defect disposition; symbol universe.

### A.8 Requirement 8 — API integrations

**Fauxnance** (the only external API this sprint). Base URL `FAUXNANCE_BASE_URL`; auth header
`X-Api-Key: <FAUXNANCE_API_KEY>`; quota 2000/day/key.

| Endpoint | Use in Sprint 4 | Notes |
|---|---|---|
| `GET /candles/{symbol}` | primary extract | `CandlesResponse` envelope (Section F). One symbol+range = one request. |
| `GET /usage` | optional pre-flight | check remaining quota before a batch |
| `GET /health` | optional pre-flight | needs no key |
| `GET /quotes/{symbol}` | **not** Sprint 4 | Sprint 7 executor/poller only |

Integration is coded now but exercised against cached fixtures until the key exists (A.3).

---

## SECTION B — New files

> Paths relative to `Our-project/`. Nothing here is created yet.

### B.1 Config / root
```
.env.example                         # copied from reference-repo/.env.example (committed template)
.env                                 # git-ignored; placeholder Fauxnance key for now
.gitignore                           # .env, .cache/, *.duckdb, .venv/, *.egg-info/, __pycache__/
```

### B.2 Sprint 4 — analytics ETL (installable Python project)
```
sprint-04-analytics-etl/
├── pyproject.toml                   # name, entry-point script, [dev]=pytest, deps pinned
├── README.md                        # how to install/run, symbol universe, defect decisions
├── claims.md                        # three business claims → chart artefacts
├── .gitignore                       # .cache/, *.duckdb, *.egg-info/
├── src/
│   └── analytics_etl/
│       ├── __init__.py
│       ├── config.py                # loads env (python-dotenv); base URL + key; NEVER logs key
│       ├── fauxnance_client.py      # HTTP client, X-Api-Key, 4-way errors, .cache/ read/write
│       ├── extract.py               # extract(symbol, range) -> raw dict   (network only)
│       ├── transform.py             # transform(raw) -> (clean_rows, quarantine)  (pure)
│       ├── load.py                  # load(rows, duckdb_path) -> counts     (write only)
│       ├── dashboard.py             # builds offline HTML (plotly, include_plotlyjs='inline')
│       └── __main__.py              # runner: wires E→T→L, writes dashboard, prints summary
├── fixtures/                        # copied from reference-repo (offline tests + seed of .cache)
│   ├── candles-infy-ns-2026-07.json
│   ├── candles-reliance-ns-2026-07.json
│   └── candles-malformed.json
├── tests/
│   ├── conftest.py                  # loads fixtures from disk
│   ├── test_transform.py            # per-defect incl. test_rejects_a_high_below_a_low
│   ├── test_extract_errors.py       # 429 / 4xx / network / cache-hit (mocked, no network)
│   └── test_load_idempotent.py      # re-run does not double-count
├── reports/                         # committed dashboard output
│   └── report.html                  # (or one file per claim)
└── .cache/                          # git-ignored; raw pulls / fixture-seeded raw JSON
```

### B.3 Sprint 3 — design docs & remediation (required by the Sprint 3 brief, currently missing)
```
sprint-03-trade-database/            # (renamed from database/, see Section D)
├── DESIGN.md                        # historical trade data design (grain, population, S7 extract, scale)
└── design/
    ├── er-diagram.md                # Mermaid erDiagram of the corrected model
    ├── indexes.md                   # ≥3 indexes, each tied to one named query + plan rationale
    └── normalisation.md             # 3NF notes + any deliberate denormalisation (positions)
```

---

## SECTION C — Modified / removed files

> All under the current `database/` → to be renamed `sprint-03-trade-database/` (Section D).

### C.1 Migrations — re-baselined into one coherent, contract-aligned set
| File (target) | Action | Change summary |
|---|---|---|
| `001_extensions.sql` | modify | keep `pgcrypto` (orders keep UUID id); drop enum block from here |
| `002_enums.sql` | modify | rename `user_status`→`account_status`; **drop `order_type`**; keep `order_side`, `order_status(NEW/FILLED/REJECTED/CANCELLED)`, `ledger_entry_type`, `alert_direction`, `notification_status` |
| `003_users.sql` | modify | keep; ensure a name source exists (holder name lives on account) |
| `004_accounts.sql` | modify | **BIGINT identity `id` PK** + `account_id VARCHAR(32) UNIQUE` + `holder_name` + `currency` + `status` (CHECK) + `version` + `cash_balance DECIMAL(18,2) CHECK>=0` |
| `005_instruments.sql` | modify | `symbol` (was `ticker`), add `asset_class`,`currency`; drop `sector`; `tradable` flag |
| `006_orders.sql` | modify | UUID `id` PK; **`idempotency_key` UNIQUE NOT NULL**; `quantity INTEGER>0`; `price DECIMAL(18,2)>0`; `executed_price` nullable; status default `'NEW'`; drop `order_type`/`remaining_quantity` |
| `007_positions.sql` | modify | renamed from holdings; `quantity INTEGER>=0`; `average_cost`; `UNIQUE(account_id,instrument_id)` |
| `008_cash_ledger.sql` | keep | minor: FK now points at BIGINT `accounts.id` |
| `009_watchlists.sql` … `013_notifications.sql` | keep | inherit account-id / instrument-id type/name updates only |
| `014_portfolio_snapshots.sql`, `015_audit_logs.sql` | keep/renumber | unchanged content |
| `016_indexes.sql` | modify | index set aligned to the six named queries (idempotency_key unique already indexes; add account-scoped order history, positions by account, created_on for the extract, business-ref lookup) |
| `0XX_order_executions` | **remove** | matching model deleted |

> Exact final numbering is settled during implementation; the table shows intent. If the team vetoes
> re-baseline, these become additive `015_…`/`016_…` files instead (and `007`'s default is still
> corrected in place, since it otherwise never applies).

### C.2 Non-migration files
| File | Action | Why |
|---|---|---|
| `schema.sql` | **remove** | redundant aggregator (SB-3); migrations are the single versioned source. The apply script iterates `migrations/*.sql` directly. |
| `scripts/apply_migrations.sh` | modify | add `psql -v ON_ERROR_STOP=1`; after migrations, load `seed/*.sql` in filename order; keep `TARGET_DATABASE`→`POSTGRES_DB` fallback; no prompts |
| `scripts/setup_db_and_seed.sh` | modify or remove | stop applying `schema.sql`; stop loading non-existent `currencies`; align to `.sql` seed; remove interactive password prompt (read from env) |
| `sql/failure_tests.sql` | modify | rewrite against real tables (`orders.id`, `idempotency_key`, `accounts.id`, `instruments.id`); prove `23505` + `23503` |
| `sql/verify_queries.sql` | modify | rewrite the six queries against real tables (`accounts`, `positions`, `orders.status`, `created_on`, business-ref lookup); parameterise cleanly |
| `seed/*.csv` + loader | convert | replace CSV `\copy` approach with numbered `.sql` seed files (`seed/001_*.sql` …) per the Sprint 3 brief ("seed data, as `.sql` files"); regenerate rows for the corrected columns and all coverage states |
| `seed/order_executions.csv` | remove | matching model deleted |
| `seed/instruments_new.csv`, `orders_new.csv`, etc. | replace | rebuild as `.sql` with `symbol`/`asset_class`/`currency`, `idempotency_key`, orders in all four states, account states ACTIVE/SUSPENDED/CLOSED, a low-cash account, a delisted instrument still referenced, reconciling positions, timestamps spread across months |
| `README.md` (root) | modify | document DB build + ETL run |

---

## SECTION D — Folder structure (target)

The reference repo names each sprint as a top-level folder (`sprint-03-trade-database`,
`sprint-04-analytics-etl`), and the Sprint 4 brief *requires* `pip install -e sprint-04-analytics-etl`
from the repo root — so the Sprint 4 folder name is fixed. For consistency, `database/` is renamed to
`sprint-03-trade-database/`.

```
Our-project/
├── .env                              # NEW (git-ignored)
├── .env.example                      # NEW
├── .gitignore                        # NEW
├── README.md                         # updated
├── sprint-03-trade-database/         # renamed from database/
│   ├── migrations/                   # 001..0NN  (single versioned source of truth)
│   ├── seed/                         # numbered .sql seed files (was CSV)
│   ├── scripts/                      # apply command (ON_ERROR_STOP, seeds, no prompt)
│   ├── sql/                          # failure_tests.sql, verify_queries.sql (real schema)
│   ├── design/                       # NEW: er-diagram.md, indexes.md, normalisation.md
│   └── DESIGN.md                     # NEW: historical trade data design
├── sprint-04-analytics-etl/          # NEW (installable Python project; see Section B.2)
│   ├── pyproject.toml
│   ├── src/analytics_etl/{config,fauxnance_client,extract,transform,load,dashboard,__main__}.py
│   ├── fixtures/  tests/  reports/  .cache/
│   ├── README.md  claims.md  .gitignore
└── docs/
    ├── analysis/{project-blueprint.md, current-sprint-analysis.md}
    └── plans/sprint-04-implementation-plan.md
```

> Later sprints slot in as siblings: `sprint-05-domain-engine/`, `sprint-06-trade-api/`, …, plus an
> `infra/postgres/` (from Sprint 6) that mounts a copy of the numbered migrations + seed.

---

## SECTION E — Environment variables

All carried in `.env.example` (committed) and `.env` (git-ignored). "Used in S4?" marks what this
sprint actually reads.

| Variable | Example / default | Used in S4? | Purpose |
|---|---|---|---|
| `POSTGRES_DB` | `trading` | apply cmd | single shared database name |
| `POSTGRES_USER` | `postgres` | apply cmd | DB user |
| `POSTGRES_PASSWORD` | `postgres_dev_password` | apply cmd | DB password |
| `TARGET_DATABASE` | (unset → falls back to `POSTGRES_DB`) | apply cmd | lets the apply command target a scratch DB |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka:29092` | no (S7) | event backbone |
| `JWT_SECRET` | `dev-only-change-me-…-32+chars` | no (S6/S8) | shared HS256 secret |
| `FAUXNANCE_BASE_URL` | `https://y4t9nq2bqf.execute-api.eu-west-2.amazonaws.com/v1` | **yes** | market-data base URL |
| `FAUXNANCE_API_KEY` | `replace-with-your-fauxnance-key` | **yes** | personal key, `X-Api-Key`, 2000/day; **never committed, never to browser** |

Rules: `.env` git-ignored; `.env.example` committed with placeholders; the key is read only from
`FAUXNANCE_API_KEY` (never a literal in source/tests/fixtures) and never logged.

---

## SECTION F — Sample payloads

### F.1 Fauxnance `GET /candles/{symbol}` — the envelope the extract consumes
```json
{
  "data": {
    "symbol": "INFY.NS",
    "interval": "1d",
    "currency": "INR",
    "candles": [
      { "date": "2026-07-01", "open": 1584.5, "high": 1601.2, "low": 1580.05,
        "close": 1598.7, "adjclose": 1598.7, "volume": 7412300, "synthetic": false }
    ]
  },
  "meta": { "asOf": "2026-07-11T06:00:00Z", "disclaimer": "Educational data. Not for investment use.",
            "symbol": "INFY.NS", "source": "mixed", "stale": false, "partial": true,
            "availableFrom": "2016-01-04" }
}
```

### F.2 Malformed payload — the six defects and this plan's disposition
Fixture: `candles-malformed.json` (BSE `TATASTEEL.BO`).

| # | Defect (date) | Disposition | Rationale |
|---|---|---|---|
| 1 | duplicate `2026-07-01`, two closes | **dedupe**, keep first, quarantine the later duplicate | one calendar day = one candle; keep it deterministic |
| 2 | `2026-07-02` missing `close` | **drop → quarantine** | close is the charted measure; a candle without it is unusable |
| 3 | `2026-07-06` `open="n/a"` | **drop → quarantine** | non-numeric price cannot be coerced safely |
| 4 | `2026-07-07` high < low | **drop → quarantine** (asserted by `test_rejects_a_high_below_a_low`) | an impossible bar must never reach a chart (the brief's explicit red line) |
| 5 | `2026-07-08` volume = -1 | **null the volume, keep OHLC** | OHLC is valid; volume is a separate, non-charted-here measure — dropping a valid price day loses more than it protects |
| 6 | last row date `09/07/2026` (non-ISO) | **drop → quarantine** | ambiguous DD/MM vs MM/DD; guessing corrupts the series |

> Also tolerated (valid, not defects): a calendar gap (a missing trading day),
> `volume: null` on a real day, and `synthetic: true` (kept, flag retained).

### F.3 Quarantine record (what transform emits for a rejected row)
```json
{ "symbol": "TATASTEEL.BO", "raw": { "date": "2026-07-07", "open": 172.5, "high": 168.1, "low": 175.85 },
  "reason": "HIGH_BELOW_LOW", "stage": "transform" }
```

### F.4 Clean row (transform → load), and the DuckDB target for *now*
```json
{ "symbol": "INFY.NS", "trade_date": "2026-07-01", "open": 1584.50, "high": 1601.20,
  "low": 1580.05, "close": 1598.70, "adjclose": 1598.70, "volume": 7412300,
  "synthetic": false, "currency": "INR", "asset_class": "EQUITY", "exchange": "NSE" }
```
Loaded into a DuckDB table `market_candles` (unique on `(symbol, trade_date)` for idempotency). In
**Sprint 7** the same transform output is remapped to `fact_trades` + dimensions in
`contracts/analytics-schema.sql`; nothing about the pipeline's *shape* changes.

### F.5 `.env` (created now; key still a placeholder)
```dotenv
POSTGRES_DB=trading
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres_dev_password
KAFKA_BOOTSTRAP_SERVERS=kafka:29092
JWT_SECRET=dev-only-change-me-this-secret-is-not-for-production-use
FAUXNANCE_BASE_URL=https://y4t9nq2bqf.execute-api.eu-west-2.amazonaws.com/v1
FAUXNANCE_API_KEY=replace-with-your-fauxnance-key
```

### F.6 DB failure demonstrations (against the corrected schema)
```sql
-- 23505: duplicate idempotency key
INSERT INTO orders (id, idempotency_key, account_id, instrument_id, side, quantity, price, status)
VALUES (gen_random_uuid(), 'DUP-KEY-TEST', 1, 1, 'BUY', 1, 1.00, 'NEW');
INSERT INTO orders (id, idempotency_key, account_id, instrument_id, side, quantity, price, status)
VALUES (gen_random_uuid(), 'DUP-KEY-TEST', 1, 1, 'BUY', 1, 1.00, 'NEW');  -- => SQLSTATE 23505

-- 23503: FK violation (account 999999 does not exist)
INSERT INTO orders (id, idempotency_key, account_id, instrument_id, side, quantity, price, status)
VALUES (gen_random_uuid(), 'FK-TEST', 999999, 1, 'BUY', 1, 1.00, 'NEW');  -- => SQLSTATE 23503
```

---

## SECTION G — Testing plan

### G.1 Sprint 4 — pytest (offline, no network, no key)
| Test file | Cases | Asserts |
|---|---|---|
| `test_transform.py` | happy-path typing; dedupe (defect 1); missing close (2); `"n/a"` (3); **`test_rejects_a_high_below_a_low`** (4); negative volume→null (5); non-ISO date (6); calendar gap tolerated; `volume:null` tolerated; `synthetic` kept | correct disposition per F.2; clean rows are correctly typed `Decimal`; quarantine carries a reason |
| `test_extract_errors.py` | 429 → stop + clear message; other 4xx → fail one symbol, continue others; network error → retry-with-backoff then give up; cache hit → no second HTTP call | four cases are distinguished (not one bare `try`); key never appears in logs |
| `test_load_idempotent.py` | load a frame twice | row count unchanged; no duplicate `(symbol, trade_date)` |

Coverage bar: transform is the assessed core, so it gets the density; extract/load get the
behavioural guarantees teammates rely on.

### G.2 Sprint 3 — database evidence
- `sql/failure_tests.sql` run against the seeded DB → observe `23505` and `23503` (F.6).
- `sql/verify_queries.sql` → the six named queries return sensible rows against seed.
- Apply-command smoke test: from an empty DB, `apply` reaches migrated **and** seeded with
  `ON_ERROR_STOP=1`, exits non-zero on any failure, unattended.
- (Review-time) `EXPLAIN ANALYZE` before/after for the ≥3 justified indexes → `design/indexes.md`.

### G.3 What is explicitly *not* tested this sprint
Live Fauxnance calls (no key yet; exercised via fixtures), Kafka, JWT, the Java domain — all later
sprints.

---

## SECTION H — Future-sprint compatibility considerations

| Sprint | What it needs from this work | How this plan provides it |
|---|---|---|
| **S5 domain** | entities/enums; rule-8 idempotency; account `status`/`version` | corrected enums (`account_status`, `order_side`, `order_status`), `version`, unique `idempotency_key` |
| **S6 Trade API** | numeric `accounts.id` + string `account_id`; decimal cash; `status`; optimistic-lock `version`; positions w/ avg cost; order history all states; `23505` on dup key | all delivered by A.2; schema now matches `trade-api.yaml` exactly |
| **S7 executor + ETL** | guarded `status='NEW'` transition; `version`; executor migration for `executed_price`/`executed_on`/`rejection_reason`; ETL merges on unique `source_order_id`; rejected/cancelled retained | `executed_price` added now; `executed_on`/`rejection_reason` reserved for `016_…`; `orders.id`↔`fact_trades.source_order_id` unique; **the same extract/transform/load functions repoint from candles to Postgres** (pipeline shape frozen this sprint) |
| **S4→S7 repoint** | one incremental, idempotent, watermark-driven load; dimensions before facts; reconciliation | transform is pure and source-agnostic; load already idempotent on a natural key; DuckDB target chosen; ANSI-portable SQL habit followed |
| **S10 Portfolio/Notifications/Watchlists** | positions carry weighted avg cost; extension tables exist | `positions.average_cost`; extension tables retained |
| **Infra (S6)** | Postgres starts empty; migrations+seed mount into `/docker-entrypoint-initdb.d` in filename order | numbered migrations + numbered `.sql` seed are copy-ready into `infra/postgres/` |

**Portability discipline for any SQL added to the analytics side:** DECIMAL not NUMERIC, no
SERIAL/IDENTITY in the star schema (ETL assigns surrogates), no vendor date functions in DDL —
matching `contracts/analytics-schema.sql` so the Sprint 7 load drops in without a rewrite.

---

## Open decisions to confirm in the implementation chat
1. **Re-baseline `001…0NN` vs purely-additive `015_…`** — plan recommends re-baseline (pre-review,
   broken base). *(major)*
2. **Account PK UUID → BIGINT identity** — required by `trade-api.yaml`/`analytics-schema`; confirm we
   accept the FK-wide change. *(major)*
3. **Seed as `.sql` (recommended, matches brief) vs keeping CSV + `\copy`.**
4. **Negative-volume disposition** — null-and-keep (chosen) vs quarantine.
5. **Create `.env`/`.env.example` now** vs in the implementation chat (this plan treats them as
   implementation; they carry only placeholders, so either is safe).

*End of plan. No code, schema, migration, seed, config, or contract has been modified.*
