-- Six inferred business queries

-- 1) Open orders for an account
SELECT * FROM orders WHERE account_id = $1 AND state = 'NEW' ORDER BY created_at DESC LIMIT 100;

-- 2) Positions for an account
SELECT * FROM positions WHERE account_id = $1;

-- 3) Recent trades for an instrument (last N days)
SELECT * FROM trades WHERE instrument_id = $1 AND executed_at >= NOW() - ($2 || ' days')::INTERVAL ORDER BY executed_at DESC;

-- 4) Filled orders for an account over a date range
SELECT * FROM orders WHERE account_id = $1 AND state = 'FILLED' AND filled_at BETWEEN $2 AND $3;

-- 5) Account cash balance (aggregate ledger)
SELECT account_id, SUM(amount) AS balance FROM account_ledger WHERE account_id = $1 GROUP BY account_id;

-- 6) Lookup order by idempotency_key
SELECT * FROM orders WHERE idempotency_key = $1;
