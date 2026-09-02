# Trade database — design and historical trade data

This is the design record for the Sprint 3 trade database. It names the apply
command, summarises the model, and covers the historical-trade-data design the
brief requires.

## Building the database

There are two one-command paths, and they seed the *same* rows two ways.
Both read `POSTGRES_*` from the repository-root `.env`, never prompt for a
password, and finish by running `probes/` (the six named queries plus the two
required rejections).

**Docker (one line, seeds from CSV).** Builds a self-contained Postgres 16
image, applies the migrations, bulk-loads `seed/csv/*.csv` with `COPY`, and
runs the probes:

```bash
# from this folder (sprint-03-trade-database/)
./scripts/setup.sh            # bash / Linux / macOS / Git Bash / WSL
./scripts/setup.ps1           # Windows PowerShell
```

**Local psql (one line, seeds from CSV).** For a Postgres you already run, this
recreates the database, applies the migrations, bulk-loads `seed/csv/*.csv`,
and runs the probes:

```bash
./scripts/create_db.sh        # bash
./scripts/create_db.ps1       # Windows PowerShell
```

`scripts/apply.sh` / `apply.ps1` remain available if you already have an empty
database and prefer the `.sql` seed (`seed/001_seed.sql`) without recreating
the DB or running probes.

All of the above apply every `migrations/*.sql` in filename order with
`psql -v ON_ERROR_STOP=1 --no-password`, so any failure aborts with a non-zero
exit and nothing is prompted. The local path reads the target database from
`TARGET_DATABASE`, falling back to `POSTGRES_DB` in the repository-root `.env`.
The repository-root `docker-compose.yml` is a third route that mounts the same
files, loads the CSV seed, and runs the probes on first start.

The schema is numbered migrations, one concern per file, applied in filename
order. From the first design review onward these files are immutable; later
changes are new numbered files (`017_...`), never edits to an earlier one.

| File | Owns |
|---|---|
| `001_extensions.sql` | `pgcrypto` |
| `002_enums.sql` | domain enums (`account_status`, `order_side`, `order_status`, …) |
| `003_users.sql` | identity (email is the notification destination) |
| `004_accounts.sql` | two identifiers, cash, status, optimistic-lock `version` |
| `005_instruments.sql` | Fauxnance `symbol`, `asset_class`, `tradable` flag |
| `006_orders.sql` | idempotency key, limit price, all four statuses |
| `007_positions.sql` | quantity + average cost, no shorting |
| `008_cash_ledger.sql` | cash movements + entry-sign CHECK |
| `009_watchlists.sql` … `011_price_alerts.sql` | Sprint 10 watchlists |
| `012_notifications.sql` | email delivery ledger (references order/account; unique `event_id`) |
| `013_portfolio_snapshots.sql` | Sprint 10 priced snapshots |
| `014_audit_logs.sql` | audit trail |
| `015_indexes.sql` | indexes justified in `design/indexes.md` |
| `016_integrity_guards.sql` | order ACTIVE-account / tradable-instrument / terminal-immutability triggers |

Seed data is kept separate: the canonical `.sql` file `seed/001_seed.sql`, and
an equivalent per-table `seed/csv/*.csv` set for the `COPY`-based Docker load.

## Model summary

Core entities: `accounts`, `instruments`, `orders`, `positions`, `cash_ledger`,
plus `users` for identity. Extension tables (`watchlists`, `watchlist_items`,
`price_alerts`, `notifications`, `portfolio_snapshots`, `audit_logs`) are the
Sprint 10 superset, retained now. Customer preferences (default account +
alert channel) are **omitted**: delivery is email-only for now, using
`users.email`. The Preferences table can be added as `017_…` in Sprint 10 if
SMS/push/in-app are needed.

See `design/er-diagram.md` for the full diagram, `design/normalisation.md` for
3NF and the one deliberate denormalisation, and `design/indexes.md` for the
index justifications.

`notifications` is an email delivery ledger: rather than copying an order's
price/quantity into the message (a second value that could drift from the
order), each order-driven row **references** its `related_order_id` and
`account_id`, and carries a unique `event_id` so a replayed at-least-once event
is delivered at most once. The numbers live once — on `orders`. There is no
`channel` column; email is the only delivery path.

Key correctness properties enforced by the database, not by application code:

- `orders.idempotency_key` `UNIQUE` — rule 8; the `23505` demonstration.
- Foreign keys on `orders`, `positions`, `cash_ledger` → `accounts`/`instruments`
  — the `23503` demonstration.
- `CHECK` constraints: account state (enum + non-negative cash), positive order
  quantity and price, non-negative position quantity, three-letter currency.
- `accounts.version` — optimistic lock for Sprint 6 (`ORD-409` lost update).
- Two account identifiers: numeric `id` (contract `accountId`) and string
  `account_id` (contract `AccountResponse.accountId`).

Both required rejections are scripted in `probes/failure_tests.sql`; the six named
queries are in `probes/verify_queries.sql`.

## Historical trade data

The operational tables answer "what is true right now". The desk also asks "what
did we trade last quarter, by instrument, by week". That is a different access
pattern, and Sprint 4 builds a separate analytical store (DuckDB star schema,
`contracts/analytics-schema.sql`) for it. This section is the reasoning, not the
rows.

### What we retain about an executed trade, and at what grain

The **grain of the fact is one order**, in whatever status it reached (not one
execution and not one state change). `fact_trades` in the analytics contract is
one row per order. Everything needed to populate it already exists on `orders`:
`id` (→ `source_order_id`, unique, idempotent load), `side`, `quantity`, `price`,
`executed_price`, `status`, `created_on`, plus the account and instrument keys.
Rejected and cancelled orders are retained precisely because fill rate cannot be
computed from fills alone.

Beyond what the order carries, the warehouse derives and stores: `trade_value`
(quantity × executed_price where filled, else quantity × price — precomputed so
every query need not), the SCD2 account version (`dim_account`, so a trade
placed while an account was ACTIVE still reads as ACTIVE even after it is
suspended), and the `exchange` derived from the symbol scheme.

### How the structures are populated, and by which component

The Python ETL (Sprint 4, extended Sprint 7) is the only writer of the
analytical store. No service reads or writes it. In Sprint 4 the same pipeline
runs over Fauxnance market-data candles; in Sprint 7 it is repointed at these
operational tables — the pipeline shape does not change, only the source.

### How the Sprint 7 extract pulls incrementally

`orders.created_on` is the watermark. The extract selects orders created since
the last successful load's high-water mark (`idx_orders_created_on` makes this a
range scan, not a full table scan), loads dimensions before facts, and merges
`fact_trades` on the unique `source_order_id` so re-running a window never
double-counts. That is why `created_on` exists and is indexed, and why order ids
are unique and stable.

### Behaviour at 100× volume

Orders accumulate without limit and are read far more than written. At 100× the
seeded volume:

- **Partitioning:** range-partition `orders` by `created_on` (monthly). The
  incremental extract and the account-scoped queries both align to the partition
  key or prune well, and old partitions can be detached wholesale.
- **Archival / retention:** orders are the legal record and are never deleted;
  closed accounts and delisted instruments are flagged, not removed. Cold
  partitions can move to cheaper storage. The analytical store, being
  append-mostly and rebuildable, has laxer retention than the operational one.
- **Cost:** partitioning adds operational complexity (a partition-creation job)
  and a small planning cost; it is **not needed yet** at seed scale, and this is
  a defensible "not yet" rather than a silent omission. The watermark index and
  the account/created composite are the changes that earn their keep first.

### What it costs

On write: the idempotency-key unique index and the two `orders` indexes are
maintained per insert; `positions` must be updated in the same transaction as a
fill (the denormalisation tax). In operational complexity: the ETL is a separate
moving part with its own watermark and reconciliation, which the analytics
contract makes a first-class, testable deliverable rather than an afterthought.
