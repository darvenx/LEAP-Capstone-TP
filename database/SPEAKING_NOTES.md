# Sprint 3 Database Speaking Notes

## 1. Opening

This database is the platform's system of record. It stores customer accounts,
tradable instruments, orders, current holdings, and cash movements. Later
services write to it, execute trades against it, extract analytical data from
it, and display its results.

The design focuses on two expensive failure modes: impossible financial rows
and a schema that later services cannot use safely.

## 2. Show the ER diagram

Open `design/er-diagram.md`.

Explain the relationships:

- A user owns one trading account in this scope.
- An account can place many orders.
- Every order references one account and one instrument.
- An account can hold many instruments.
- The unique `(account_id, instrument_id)` key means one current position per instrument.
- The cash ledger records account cash movements.
- Watchlists, notifications, snapshots, and audit logs support surrounding platform workflows.
- Instruments are retained after delisting so old orders and holdings remain readable.

Explain the two account identifiers:

- `account_id` is the internal UUID used by the platform.
- `account_number` is the customer-facing reference used by support and statements.

## 3. Explain the migrations

Show the files in this order:

1. `migrations/001_extensions_and_enums.sql`
2. `migrations/002_create_tables.sql`
3. `migrations/003_create_indexes.sql`
4. `migrations/004_order_guards.sql`

Key points:

- The numbered files provide stable, repeatable schema history.
- Enums restrict roles, account states, order sides, order types, order states, and ledger entry types.
- Primary keys identify rows and foreign keys protect relationships.
- Money and prices use exact `NUMERIC` types instead of floating point.
- `trading_accounts.version` supports optimistic concurrency checks.
- `orders.idempotency_key` is required and unique.
- Terminal orders are `FILLED`, `REJECTED`, or `CANCELLED` and cannot be reopened.

## 4. Explain the important constraints

The database enforces business rules instead of relying only on application
code:

- Account state is `ACTIVE`, `SUSPENDED`, or `CLOSED`.
- Suspended and closed accounts cannot place orders.
- New orders require a tradable instrument.
- Historical terminal orders may still reference delisted instruments.
- Order quantity must be positive.
- Remaining quantity cannot be negative or exceed the original quantity.
- A new order has its full remaining quantity; a terminal order has zero remaining quantity.
- Market orders cannot contain a limit price.
- Limit orders require a positive limit price.
- Blank idempotency keys are rejected.
- Holding quantities and average prices cannot be negative.
- Ledger amounts cannot be zero and must have the correct sign for their entry type.

## 5. Show the seed data

Open `seed/001_core.sql`.

The fixtures intentionally cover the required error paths:

- Accounts in `ACTIVE`, `SUSPENDED`, and `CLOSED` states
- An account with only a small cash balance
- Equity, ETF, and crypto instruments
- A delisted `BTC-USD` instrument
- New, filled, rejected, and cancelled orders
- A holding in the delisted instrument
- Holdings that reconcile with filled orders
- Cash ledger entries for buys, sells, and initial balances

Run these checks in pgAdmin:

```sql
SELECT status, COUNT(*)
FROM trading_accounts
GROUP BY status
ORDER BY status;

SELECT status, COUNT(*)
FROM orders
GROUP BY status
ORDER BY status;

SELECT account_number, holder_name, status, cash_balance
FROM trading_accounts
ORDER BY account_number;

SELECT i.ticker,
       i.asset_class,
       i.is_tradable,
       h.quantity,
       h.average_buy_price
FROM holdings h
JOIN instruments i ON i.instrument_id = h.instrument_id
ORDER BY i.ticker;
```

Expected account states are `ACTIVE`, `SUSPENDED`, and `CLOSED`.
Expected order states are `NEW`, `FILLED`, `REJECTED`, and `CANCELLED`.

## 6. Demonstrate idempotency and foreign-key rejection

Open `sql/failure_tests.sql`.

Say:

> These invalid statements demonstrate that the database itself rejects duplicate instructions and invalid relationships.

Execute the file with error continuation enabled. The errors are intentional.

Expected results:

- Duplicate `idempotency_key`: SQLSTATE `23505`
- Non-existent account reference: SQLSTATE `23503`

The duplicate key is enforced by the database unique constraint. A read-first,
insert-later application check would not be sufficient under concurrency.

## 7. Run the six business queries

Open `sql/verify_queries.sql` and execute each query separately.

Use these values:

```text
Account UUID: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
Account number: ACC-1001
Timestamp: 2026-02-01T00:00:00Z
```

Use single quotes around values in PostgreSQL:

```sql
'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
'ACC-1001'
'2026-02-01T00:00:00Z'
```

Explain each query:

1. Finds all open orders for one account, newest first, for the blotter.
2. Finds the last 50 orders in any state for order history.
3. Finds current holdings with instrument details, quantity, and average cost.
4. Finds every order created since a timestamp for the incremental extract.
5. Resolves an internal account from the customer-facing account number.
6. Finds filled orders oldest first and calculates running cash commitment and rank by instrument value using window functions.

For query 6, explain that cash commitment comes from `cash_ledger`, while
current holdings and `cash_balance` are stored projections that can be
reconciled against historical facts.

## 8. Explain the indexes

Open `design/indexes.md`.

The main query-backed indexes are:

- `idx_orders_account_status_created` supports open orders for an account.
- `idx_orders_account_created` supports the latest 50 orders for an account.
- `idx_orders_created_at` supports incremental extraction by creation time.
- `idx_holdings_account` supports the portfolio query.

The unique index created for `account_number` already supports account lookup,
so no additional index is needed for that query.

Every extra index has a write cost because inserts and relevant updates must
maintain it. The indexes were added only when tied to a named business query.

Optional plan demonstration:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE account_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  AND status = 'NEW'
ORDER BY created_at DESC;
```

## 9. Explain normalization and historical data

Open `design/normalization.md` and `DESIGN.md`.

Key points:

- Users, accounts, instruments, orders, holdings, and ledger entries have separate responsibilities.
- Foreign keys store relationships without repeating names and descriptions.
- `cash_balance` and `holdings` are deliberate denormalized projections for fast dashboard reads.
- The cash ledger and execution history remain available for reconciliation.
- Future executed trades should be stored at one immutable row per execution.
- Sprint 7 can extract executions incrementally using `(executed_at, execution_id)` as a high-water mark.
- At larger volumes, execution history can be partitioned by month or quarter and archived according to retention policy.

## 10. Explain how to rebuild

The database can be rebuilt from migrations and seeds alone.

For pgAdmin:

1. Create an empty database named `trade_db`.
2. Open Query Tool.
3. Execute migrations `001` through `004` in filename order.
4. Execute `seed/001_core.sql`.
5. Run the verification queries.
6. Run the failure tests.

For a local PostgreSQL server from the VS Code PowerShell terminal:

```powershell
cd C:\Users\Administrator\Documents\LEAP-Capstone-TP
.\setup-database.ps1
```

The script reads the local `manifest.env` settings and stops on the first
failure. PostgreSQL credentials should not be displayed during the review.

## 11. Closing statement

The main design decisions are:

1. Idempotency is enforced by a database unique constraint.
2. Account and instrument lifecycle states are explicit and enforced.
3. Terminal orders remain immutable and historical records are retained.
4. Money and prices use exact numeric types.
5. Current holdings and cash are fast projections that remain reconcilable from historical facts.
6. Migrations, seed data, verification queries, and documentation provide a repeatable reviewable build.
