# Sprint 4 Review — Analytics & ETL (+ Sprint 3 remediation)

Assessment of what was implemented against
`docs/plans/sprint-04-implementation-plan.md`, the two Sprint 4/3 briefs, and the
binding contracts. Verified on this host where possible (Python pipeline and
tests); the database path was validated by review because no Docker/`psql` is
installed here.

## Requirements satisfied

### Sprint 4 (the sprint deliverable)

| # | Acceptance criterion | Evidence |
|---|---|---|
| 1 | Three business claims, each backed by a readable chart | `claims.md` (3 claims), `reports/report.html` (3 labelled charts, offline) |
| 2 | Fauxnance candles via `GET /candles/{symbol}`, key from env | `fauxnance_client.py` (`X-Api-Key`, `FAUXNANCE_API_KEY` only) |
| 3 | Pipeline separated into extract / transform / load | three modules + `__main__` runner; `transform` is pure, `load` is DuckDB-only |
| 4 | pytest over the transform incl. a malformed-input case | 21 tests pass, incl. `test_rejects_a_high_below_a_low` |
| 5 | Rate-limit/error handling, not a bare `try` | four distinct cases: 429 / other-4xx / network-retry / 200-bad-data |
| 6 | ≥2 NSE/BSE symbols | `INFY.NS`, `RELIANCE.NS` (NSE), `TATASTEEL.BO` (BSE) |

Additional: installable project (`pip install -e 'sprint-04-analytics-etl[dev]'`
verified on a clean venv), raw responses cached to `.cache/` keyed by
symbol+range, key never logged (`Config.__repr__` masks it), DuckDB load
idempotent on `(symbol, trade_date)`, six malformed defects each dispositioned
and asserted.

### Sprint 3 (remediation required by the plan)

| Area | Evidence |
|---|---|
| Split-brain removed; one coherent schema | numbered `migrations/001_…017_`; phantom-schema `sql/` files rewritten |
| Broken migration fixed | `order_status` default is now `'NEW'` (was invalid `'OPEN'`) |
| Idempotency key + `23505` | `orders.idempotency_key UNIQUE`; `sql/failure_tests.sql` |
| FK violation `23503` | `sql/failure_tests.sql` |
| Account `status` + `version` + two identifiers | `004_accounts.sql` matches `trade-api.yaml` |
| Instrument `asset_class`/`currency`/`tradable`/`symbol` | `005_instruments.sql` |
| Positions with `average_cost`, no shorting | `007_positions.sql` |
| Seed as `.sql`, full state coverage | `seed/001_seed.sql`; all four order states, three account states, delisted+FX instruments |
| One-command apply (ON_ERROR_STOP, seeds, no prompt) | `scripts/apply.sh` / `apply.ps1`; Docker one-liner `scripts/setup.sh` |
| Design docs + ≥3 justified indexes + historical design | `DESIGN.md`, `design/{er-diagram,indexes,normalisation}.md` |
| Numbered migrations as the versioning unit | `001_extensions.sql` … `016_integrity_guards.sql`; no aggregator `schema.sql` |

## Requirements partially satisfied

- **Database execution evidence.** The migrations, seed, `verify_queries.sql`
  and `failure_tests.sql` are complete and reviewed, but they were **not run**
  on this host (no Docker, no local `psql`). The `23505`/`23503` demonstrations
  and the six-query outputs must be captured on a machine with Postgres (Path A
  or B in the root README) before the design review.
- **`EXPLAIN ANALYZE` before/after for the indexes.** `design/indexes.md` states
  the expected plan change and write cost per index, but the actual plans are not
  captured (they need a loaded database). This is review-time evidence to add.
- **Live Fauxnance pull.** The client is written for the real API but exercised
  against fixtures; no key is available yet. Flipping to live is a config-only
  change (documented).

## Known limitations

- `TATASTEEL.BO` is served offline by the malformed fixture, so after cleaning it
  contributes only two clean candles. The claims are therefore carried by the two
  NSE names; the Tata Steel trend claim was deliberately withdrawn (see
  `claims.md`).
- The DuckDB store is `market_candles` (market data), not yet the star schema in
  `contracts/analytics-schema.sql`. That mapping is the Sprint 7 repoint, by
  design — the pipeline shape is frozen for it now.
- Seed cash figures reconcile for `ACC-000001` only; other accounts carry an
  opening balance without a full trade history (they exist to reach error paths,
  not to demonstrate reconciliation).

## Assumptions made

- **Re-baseline over additive migrations** (plan open decision 1): justified by
  the pre-first-review state and the base migration that never applied.
- **Account PK `BIGINT identity` + string `account_id`** (decision 2): required
  by `trade-api.yaml` and `analytics-schema.dim_account.source_id`.
- **Seed as `.sql`** (decision 3) and **create `.env` now** (decision 5).
- **Negative volume → null-and-keep** (decision 4): OHLC is valid and charted;
  volume is a separate, non-charted-here measure.
- Instruments use a `BIGINT` surrogate `id` (like accounts) with `symbol UNIQUE`,
  so orders/positions/watchlist_items/price_alerts FK to it consistently.
- `users.full_name` added as the holder-name source alongside `accounts.holder_name`.

## Technical debt

- Capture and commit the DB run evidence (query outputs, the two SQLSTATE
  refusals, `EXPLAIN ANALYZE` plans) once a Postgres is available.
- `reports/report.html` is committed as a generated artefact; consider a make/CI
  target so it is regenerated deterministically rather than by hand.
- The runner seeds `TATASTEEL.BO` from the malformed fixture for demonstration;
  for a "clean" dashboard run, a real BSE pull (or a clean BSE fixture) would
  give it a full series.
- No CI wiring yet (pytest + a lint gate would catch regressions); Sprint 7 adds
  a SonarQube gate for the pipeline.

## Recommendations for Sprint 5 (domain engine)

- Build the Java enums directly from `migrations/002_enums.sql`: `AccountStatus`
  (`ACTIVE/SUSPENDED/CLOSED`), `OrderSide` (`BUY/SELL`), `OrderStatus`
  (`NEW/FILLED/REJECTED/CANCELLED`). They are now authoritative and consistent.
- Model `Account` with both identifiers (numeric `id`, string `accountId`),
  `version` (optimistic lock), `status`, decimal `cashBalance` — the schema
  already exposes exactly what `trade-api.yaml` names.
- Rule 8 (idempotency) in the domain is a seam; the real authority is the DB
  unique constraint on `orders.idempotency_key` (already in place, demonstrated
  by `23505`). Design the domain test to express the intent, not to enforce
  uniqueness itself.
- Keep money as `BigDecimal` to match `DECIMAL(18,2)` throughout the schema; no
  `double`.
- `Position.averageCost` semantics (buy recalculates, sell leaves it unchanged)
  are already reflected in the seed reconciliation — reuse that as a domain test
  fixture.
