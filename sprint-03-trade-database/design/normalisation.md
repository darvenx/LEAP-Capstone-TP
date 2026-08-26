# Normalisation notes

The operational schema is in third normal form. This note records why, and the
one deliberate, documented denormalisation.

## Third normal form

- **1NF** — every column holds a single atomic value. There are no repeating
  groups or arrays in the trading tables; a watchlist's instruments are rows in
  `watchlist_items`, not a list column.
- **2NF** — every table has a single-column primary key (`id`, a UUID, or the
  natural surrogate), so there are no partial dependencies on part of a
  composite key. The one composite key, `positions(account_id, instrument_id)`,
  is a `UNIQUE` constraint, not the primary key, and every non-key column
  (`quantity`, `average_cost`) depends on the whole business key.
- **3NF** — no non-key column depends on another non-key column. `exchange` on
  `instruments` is derivable from `symbol` in principle (`.NS` → NSE), but it is
  stored, not transitively dependent through a third table; it is a directly
  recorded attribute of the instrument, kept because the market-data authority
  assigns it. `holder_name` lives on `accounts`, sourced from the account, not
  transitively via `users` (an account is the holder-of-record even before a
  `users` row links to it).

The two account identifiers are **not** a normalisation violation. `id`
(surrogate) and `account_id` (business reference) both identify the account, but
neither derives from the other: the surrogate is database-assigned and the
business reference is externally meaningful. Carrying both is what
`trade-api.yaml` requires, and each has a `UNIQUE`/`PK` constraint.

## Deliberate denormalisation: positions

`positions` is derived state. Every row could be rebuilt by replaying the
`FILLED` orders for that `(account_id, instrument_id)`:

- `quantity` = sum of filled BUY quantities minus filled SELL quantities.
- `average_cost` = weighted average of filled BUY executed prices; a SELL
  reduces quantity and leaves `average_cost` unchanged.

Storing it duplicates information already in `orders`, which is a denormalisation.
It is deliberate because the portfolio panel and the balance/positions endpoints
read holdings on every dashboard load, and replaying an unbounded order history
per page load does not scale. The trade-off is that a write to `orders` that
fills must also update `positions` in the same transaction (Sprint 7's job), or
the two drift. The positions and orders sections of `seed/001_seed.sql`
demonstrate the reconciliation (positions rebuilt from the filled orders), and
the `DESIGN.md` reconciliation query shows it can be rederived — the check that
the denormalisation is honest.

## Money and quantity types

`DECIMAL(18,2)` for money everywhere (never binary floating point, which cannot
represent 0.10 and drifts over thousands of trades). `INTEGER` for share
quantities (whole units; no fractional shares, no shorting). This is consistent
across `accounts`, `orders`, `positions` and `cash_ledger`, and matches the
`DECIMAL` used by `contracts/analytics-schema.sql`.
