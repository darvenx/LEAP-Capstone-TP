# Seed data

Fixture rows in a single file, `001_seed.sql`, applied after the schema by the
apply command (`scripts/apply.sh`). The file inserts in foreign-key order:
users → accounts → instruments → orders → positions → cash_ledger.

| Section (in `001_seed.sql`) | Loads |
|---|---|
| users | 10 holders across ACTIVE / SUSPENDED / CLOSED |
| accounts | 10 accounts (states covered; `ACC-000004` low-cash; `ACC-000006` USD) |
| instruments | 10 instruments: NSE/BSE/US equities, an FX pair, a crypto pair, one delisted |
| orders | 15 orders across all four states, several accounts, spread Feb–Jul 2026 |
| positions | 10 positions, each reconciled against the account's FILLED orders |
| cash_ledger | 20 rows; each account's rows sum to its stored `cash_balance` |
| watchlists / watchlist_items | 10 / 10 |
| price_alerts | 10 |
| notifications | 10 (PENDING / SENT / FAILED) |
| portfolio_snapshots | 10 (value over time for trading accounts) |
| audit_logs | 10 |

Consistency guarantees baked into the data: every position reconciles against
the filled orders that produced it (a sell reduces quantity and leaves average
cost unchanged), and every account's `cash_balance` equals the sum of its
`cash_ledger` rows. Suspended/closed accounts placed no orders after losing
`ACTIVE` status.

Surrogate keys (`accounts.id`, `instruments.id`) are `GENERATED ALWAYS AS
IDENTITY`, so they are never written literally. Child rows resolve their parent
by the business reference (`accounts.account_id`) or the `instruments.symbol`,
which is exactly the mapping the Sprint 6 Trade API performs at runtime. The
apply command globs `seed/*.sql`, so additional seed files can be added later
without changing the command.

## Coverage (from the brief) and where it lives

| Coverage required | Seeded as |
|---|---|
| Accounts in all three states | `ACC-000001` ACTIVE, `ACC-000002` SUSPENDED, `ACC-000003` CLOSED |
| An account that cannot afford a realistic order | `ACC-000004`, cash 50.00 |
| An account holding a position | `ACC-000001` holds INFY.NS, AAPL, YESBANK.NS |
| Several instruments, one not an equity | `FX:EURUSD` (asset class FX) |
| A delisted instrument still referenced | `YESBANK.NS` (`tradable = FALSE`), held and traded |
| Orders in all four lifecycle states | FILLED, NEW, REJECTED, CANCELLED (orders section of `001_seed.sql`) |
| Holdings that reconcile against filled orders | positions section of `001_seed.sql` (see the derivation comments) |
| Timestamps spread across months | May–July 2026 |

## Reloading

The apply command loads these into a known empty state. Inserts that collide
with rows already present will fail, which is correct. Reload by starting from
an empty database (drop/recreate, or reset the Docker volume).
