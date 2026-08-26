# Current Sprint Analysis — Sprint 4: Analytics & ETL

> Analysis artefact only. Produced by reading `reference-repo/` (Sprint 3, 4, 5, 6, 7
> briefs; `contracts/`; `infra/`) against our implementation in `Our-project/`.
> No source code, schema, contract or infrastructure definition was modified.

## Current sprint

**Sprint 4 — Analytics & ETL pipeline** (`sprint-04-analytics-etl`, 8 marks).
Prior sprint delivered: Sprint 3 — Trade database (`Our-project/database/`).

---

## 1. Sprint objective

Build an installable Python project that extracts end-of-day **candles** from the
Fauxnance API, transforms/cleans them, loads them into a **DuckDB** analytical store,
and produces an **offline HTML dashboard** backing **three business claims**. The
pipeline is split into **extract / transform / load** functions in three modules,
wired by a fourth runner, with pytest over the transform (including a malformed-input
case) and four-way error handling (quota / bad-request / network / bad-data-in-200).

The source this week is **market data, not our own trades** — order flow does not exist
until Sprints 6–7. The pipeline is built so that in Sprint 7 the *same* functions are
repointed at the operational database and load the binding star schema in
`contracts/analytics-schema.sql`.

## 2. Business objective

Give the trading desk answers to "what did we trade / how did the market move, over a
period, by instrument or asset class" without slowing the operational database. Deliver
three defensible business claims a non-technical reader can verify from a labelled chart.

## 3. Technical objective

- Installable package: `pip install -e 'sprint-04-analytics-etl[dev]'` works from a
  clean environment; pytest discovered under `tests/`.
- Three importable callables in three distinct modules: **extract** (network + key only),
  **transform** (pure, no I/O), **load** (DuckDB write only), plus a runner entry point.
- Fauxnance client reads the key from `FAUXNANCE_API_KEY`; pulls `GET /candles/{symbol}`.
- Raw pulls cached to `.cache/`, keyed by symbol + range (cache raw, not the cleaned frame).
- Transform handles the six malformed-fixture defects (duplicate date, missing `close`,
  non-numeric value, high < low, negative volume, non-ISO date) with an asserted decision
  (drop / quarantine / raise) for each.
- Load target is DuckDB; SQL kept portable/ANSI in line with `analytics-schema.sql`.
- Dashboard is offline HTML with inlined JS (plotly), one artefact per claim; claims in
  `claims.md`.
- ≥ 2 NSE/BSE symbols in scope (e.g. `INFY.NS`, `RELIANCE.NS`, `TATASTEEL.BO`).
- Error handling distinguishes 429 (stop), other 4xx (fail that symbol, continue),
  network (retry with backoff), and 200-with-bad-data (transform's problem). No bare `try`.
- Never log the key; key never in source, tests or fixtures.

## 4. Required inputs

| Input | Source | Status in our repo |
|---|---|---|
| Fauxnance candles (`GET /candles/{symbol}`) | Fauxnance API | External; available now |
| `FAUXNANCE_API_KEY`, `FAUXNANCE_BASE_URL` | `.env` (from `.env.example`) | **Missing** — no `.env.example` in `Our-project/` |
| Canned fixtures incl. malformed payload | `reference-repo/sprint-04-analytics-etl/fixtures/` | Present in reference repo |
| DuckDB target model (for Sprint 7 repoint) | `contracts/analytics-schema.sql` | Binding contract; our schema must be able to feed it |

**Note on Sprint 3 as an input:** Sprint 4's pipeline does **not** read the Sprint 3
database. Sprint 3 is a *forward* dependency: in Sprint 7 the pipeline is repointed at
our operational tables, so their shape must be able to produce `fact_trades` and the
dimensions.

## 5. Required outputs (what Sprints 5, 6, 7 need from us)

The star schema in `contracts/analytics-schema.sql` fixes what our operational schema must
eventually expose. Mapping the target back to Sprint 3:

| Star-schema need | Operational source required | Consumed by |
|---|---|---|
| `dim_account.account_id` (business ref), `holder_name`, `status`, SCD2 versioning | account business ref + holder name + `status` + `version` | S6, S7 ETL |
| `dim_instrument.symbol`, `name`, `asset_class`, `currency`, `exchange`, `tradable` | instrument symbol, name, **asset_class**, **currency**, tradable flag | S4 claim (by asset class), S7 ETL |
| `fact_trades.side`, `quantity`, `price`, `executed_price`, `status`, `trade_value`, `source_order_id` (unique) | orders with side/qty/limit price/status + **idempotency/order id** + executed price | S7 ETL |
| Fill-rate analytic | orders in all four states (`NEW/FILLED/REJECTED/CANCELLED`) retained | S4/S7 |

Additional forward outputs:
- **Sprint 5 (domain):** entities/enums (`AccountStatus`, `OrderSide`, `OrderStatus`),
  rule 8 idempotency — needs account `status`, `version`, order idempotency key.
- **Sprint 6 (Trade API):** both account identifiers, decimal cash, `status`, optimistic
  lock `version` (`ORD-409`), positions w/ average cost, order history all statuses,
  unique idempotency key (`23505`).
- **Sprint 7 (executor + ETL):** `version` for optimistic lock, guarded `status='NEW'`
  transition, executor migration adds `executed_price`/`executed_on`/`rejection_reason`,
  ETL merges on unique `source_order_id`.

## 6. Future dependencies

- **S5 → S6:** domain package copied as source; entities built on Sprint 3 shapes.
- **S6 → S7:** executor re-uses rules; S7 changes S6 to publish `ORDER_PLACED` and adds
  executed-price migration in the Sprint 3 style.
- **S4 → S7:** the same extract/transform/load functions are repointed from candles to
  operational trades and load the full star schema. **This is the reason Sprint 3 schema
  gaps matter now.**
- **Contracts:** `analytics-schema.sql` (S4/S7), `trade-api.yaml` (S6/S9) are binding.

## 7. Gaps found

### 7a. Sprint 4 (not yet started)
- No Python project (`pyproject.toml`, package, `extract`/`transform`/`load` modules, runner).
- No Fauxnance client, no `.cache/` strategy.
- No DuckDB load, no `claims.md`, no offline dashboard artefacts.
- No pytest suite / malformed-input test.
- No `.env.example` carrying `FAUXNANCE_API_KEY` / `FAUXNANCE_BASE_URL` in `Our-project/`.

### 7b. Sprint 3 defects that will block Sprint 6/7 (fix now, cheap)
| # | Defect | Impact | Severity |
|---|---|---|---|
| 1 | `orders` has **no `idempotency_key`** and no unique constraint | Violates S3 acceptance (must demo `23505`); blocks S6 rule-8 / duplicate defence; `fact_trades.source_order_id` uniqueness | **Blocker** |
| 2 | `trading_accounts` has **no `status`** and **no `version`** (status only on `users`) | Blocks S6 optimistic lock (`ORD-409`), "suspended can't trade", `dim_account` SCD2; violates S3 "check constraint on account state" | **Blocker** |
| 3 | `instruments` **missing `asset_class` and `currency`** (has `sector` instead) | `dim_instrument` requires both; S4 "by asset class" claim; trade-api currency | **High** |
| 4 | `orders` models `order_type` (MARKET/LIMIT), `remaining_quantity` / partial fills | Contradicts domain (single limit price, no partial fills, one terminal state); MARKET → null price vs `fact_trades.price NOT NULL` | **Medium** |
| 5 | No `holderName` source (users has no name field) | `AccountResponse.holderName` and `dim_account.holder_name` unsourced | **Medium** |
| 6 | Separate `order_executions` (buy/sell matching) table | Diverges from the platform model (executor fills vs market price, not order matching) | **Low / review** |
| 7 | Missing S3 design docs (`design/er-diagram`, `design/indexes.md`, `DESIGN.md`) | S3 acceptance completeness | **Low** |

**These do not block the Sprint 4 dashboard demo** (source is Fauxnance), but items 1–3
must be fixed before the Sprint 7 repoint and Sprint 6.

## 8. Recommended changes

**Sprint 4 (build):**
1. Scaffold `sprint-04-analytics-etl` Python project (`pyproject.toml`, `[dev]` → pytest,
   deps: `requests`, `pandas`, `plotly`, `python-dotenv`, `duckdb`).
2. Implement `extract` (candles + `.cache/`), `transform` (pure cleaning + the 6 defect
   decisions), `load` (DuckDB), and a runner entry point; document it in `claims.md`.
3. Add four-way error handling; never log the key.
4. Write pytest over the transform incl. `test_rejects_a_high_below_a_low` etc.
5. Choose ≥ 2 NSE/BSE symbols; produce offline HTML dashboard + three claims.
6. Add `.env.example` with `FAUXNANCE_BASE_URL` / `FAUXNANCE_API_KEY` placeholders.

**Sprint 3 (fix via NEW numbered migrations — do not edit `001`–`014`):**
1. Add `orders.idempotency_key` + `UNIQUE`; add a `23505`/`23503` demo script.
2. Add `trading_accounts.status` (enum, CHECK) + `version` (int, optimistic lock);
   add a holder-name source (account or a name column on users).
3. Add `instruments.asset_class` + `currency`; keep tradable as the delist flag.
4. Reconcile `orders` with the domain: single limit price, drop partial-fill columns
   (or document the deliberate divergence in a decision log).
5. Backfill seed CSVs to cover all three account states + a non-equity instrument with
   asset_class/currency + orders in all four states.

> Sprint 4 work can start immediately in parallel; the Sprint 3 fixes are raised as a
> separate change so the pipeline designed this week repoints cleanly in Sprint 7.
