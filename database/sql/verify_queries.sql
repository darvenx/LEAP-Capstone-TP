-- The six named queries from the Sprint 3 brief.

-- 1) All open orders for one account, newest first.
-- The current model has one non-terminal status: NEW.
SELECT *
FROM orders
WHERE account_id = $1
	AND status = 'NEW'
ORDER BY created_at DESC;

-- 2) The last 50 orders for one account in any state, newest first.
SELECT *
FROM orders
WHERE account_id = $1
ORDER BY created_at DESC
LIMIT 50;

-- 3) Everything one account currently holds, with quantity and average cost.
SELECT h.account_id,
	   h.instrument_id,
	   i.ticker,
	   i.company_name,
	   h.quantity,
	   h.average_buy_price
FROM holdings AS h
JOIN instruments AS i ON i.instrument_id = h.instrument_id
WHERE h.account_id = $1
ORDER BY i.ticker;

-- 4) Every order created since a given timestamp, across all accounts.
SELECT *
FROM orders
WHERE created_at >= $1
ORDER BY created_at ASC;

-- 5) Resolve an account from its customer-facing reference.
SELECT account_id,
	   user_id,
	   account_number,
	   cash_balance
FROM trading_accounts
WHERE account_number = $1;

-- 6) Filled orders for one account, oldest first, with running cash committed
-- and rank by order value within the instrument. The current schema stores a
-- stated limit price rather than a separate execution price.
WITH filled_orders AS (
	SELECT o.order_id,
		   o.account_id,
		   o.instrument_id,
		   o.side,
		   o.quantity,
		   o.limit_price,
		   o.created_at,
		   o.quantity * COALESCE(o.limit_price, 0) AS order_value,
		   CASE
			   WHEN o.side = 'BUY'
			   THEN o.quantity * COALESCE(o.limit_price, 0)
			   ELSE 0
		   END AS cash_committed
	FROM orders AS o
	WHERE o.account_id = $1
	  AND o.status = 'FILLED'
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
