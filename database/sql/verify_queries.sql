-- 1) All open orders for one account, newest first.
SELECT *
FROM orders
WHERE account_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
	AND status = 'NEW'
ORDER BY created_at DESC;

-- 2) The last 50 orders for one account in any state, newest first.
SELECT *
FROM orders
WHERE account_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
ORDER BY created_at DESC
LIMIT 50;

-- 3) Everything one account currently holds, with quantity and average cost.
SELECT h.account_id,
	   h.instrument_id,
	   i.ticker,
	i.display_name,
	   h.quantity,
	   h.average_buy_price
FROM holdings AS h
JOIN instruments AS i ON i.instrument_id = h.instrument_id
WHERE h.account_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
ORDER BY i.ticker;

-- 4) Every order created since a given timestamp, across all accounts.
SELECT *
FROM orders
WHERE created_at >= '2026-02-01T00:00:00Z'
ORDER BY created_at ASC;

-- 5) Resolve an account from its customer-facing reference.
SELECT account_id,
	   user_id,
	   account_number,
	   cash_balance
FROM trading_accounts
WHERE account_number = 'ACC-1001';

-- 6) Filled orders for one account, oldest first, with running cash committed
-- and rank by order value within its instrument. Cash commitment comes from
-- the signed cash ledger, which also supports market orders.
WITH filled_orders AS (
	SELECT o.order_id,
		   o.account_id,
		   o.instrument_id,
		   o.side,
		   o.quantity,
		   o.limit_price,
		   o.created_at,
		   o.quantity * COALESCE(o.limit_price, 0) AS order_value,
		   COALESCE(SUM(cl.amount), 0) AS cash_committed
	FROM orders AS o
	LEFT JOIN cash_ledger AS cl ON cl.reference_id = o.order_id
	WHERE o.account_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
	  AND o.status = 'FILLED'
	GROUP BY o.order_id, o.account_id, o.instrument_id, o.side,
			 o.quantity, o.limit_price, o.created_at
)
SELECT filled_orders.*,
	   SUM(cash_committed) OVER (
		   PARTITION BY account_id
		   ORDER BY created_at, order_id
		   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
	   ) AS running_cash_committed,
	   RANK() OVER (
		   PARTITION BY instrument_id
		   ORDER BY order_value DESC
	   ) AS instrument_value_rank
FROM filled_orders
ORDER BY created_at ASC, order_id;
