-- Six business queries against the actual schema (database/migrations/).
-- Previous version of this file referenced tables/columns that were never
-- created (orders.state, positions, trades, orders.filled_at, account_ledger,
-- orders.idempotency_key) — rewritten against the real table and column
-- names below.

-- 1) Open (working) orders for an account
SELECT * FROM orders WHERE account_id = $1 AND status = 'NEW' ORDER BY created_at DESC LIMIT 100;

-- 2) Holdings (positions) for an account
SELECT * FROM holdings WHERE account_id = $1;

-- 3) Recently filled orders for an instrument (last N days)
SELECT * FROM orders WHERE instrument_id = $1 AND status = 'FILLED' AND updated_at >= NOW() - ($2 || ' days')::INTERVAL ORDER BY updated_at DESC;

-- 4) Filled orders for an account over a date range
-- NOTE: there is no separate filled_at column — an order's fill time is the
-- same row's updated_at, since status transitions to FILLED there.
SELECT * FROM orders WHERE account_id = $1 AND status = 'FILLED' AND updated_at BETWEEN $2 AND $3;

-- 5) Account cash balance (aggregate ledger)
SELECT account_id, SUM(amount) AS balance FROM cash_ledger WHERE account_id = $1 GROUP BY account_id;

-- 6) Working orders on the book for an instrument, by side and price
-- NOTE: the previous version looked orders up by an idempotency_key column
-- that does not exist anywhere in the schema. Replaced with the book-building
-- query idx_orders_instrument_side_price was actually indexed for.
SELECT * FROM orders WHERE instrument_id = $1 AND side = $2 AND status = 'NEW' ORDER BY limit_price;
