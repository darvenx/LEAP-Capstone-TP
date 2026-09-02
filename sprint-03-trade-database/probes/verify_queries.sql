-- verify_queries.sql
-- The six named queries from the Sprint 3 brief, written against the real
-- corrected schema and runnable against the loaded seed. Each is wrapped in a
-- \echo so the output is self-labelling. ACC-000001 is used as the worked
-- account because it carries orders in every state and three positions.
--
--   psql "$TARGET_DATABASE" -v ON_ERROR_STOP=1 -f probes/verify_queries.sql

\echo '== Q1: all open (NEW) orders for one account, newest first (blotter) =='
SELECT o.id, i.symbol, o.side, o.quantity, o.price, o.status, o.created_on
FROM orders o
JOIN instruments i ON i.id = o.instrument_id
WHERE o.account_id = (SELECT id FROM accounts WHERE account_id = 'ACC-000001')
  AND o.status = 'NEW'
ORDER BY o.created_on DESC;

\echo '== Q2: last 50 orders for one account, any state, newest first (history) =='
SELECT o.id, i.symbol, o.side, o.quantity, o.price, o.status, o.created_on
FROM orders o
JOIN instruments i ON i.id = o.instrument_id
WHERE o.account_id = (SELECT id FROM accounts WHERE account_id = 'ACC-000001')
ORDER BY o.created_on DESC
LIMIT 50;

\echo '== Q3: everything one account holds, with quantity and average cost (portfolio) =='
SELECT i.symbol, p.quantity, p.average_cost
FROM positions p
JOIN instruments i ON i.id = p.instrument_id
WHERE p.account_id = (SELECT id FROM accounts WHERE account_id = 'ACC-000001')
ORDER BY i.symbol;

\echo '== Q4: every order created since a timestamp, across all accounts (Sprint 7 extract) =='
SELECT o.id, a.account_id AS account_ref, i.symbol, o.status, o.created_on
FROM orders o
JOIN accounts    a ON a.id = o.account_id
JOIN instruments i ON i.id = o.instrument_id
WHERE o.created_on >= TIMESTAMPTZ '2026-07-01T00:00:00Z'
ORDER BY o.created_on;

\echo '== Q5: resolve an account from the customer-facing reference (support / auth) =='
SELECT id, account_id, holder_name, status, cash_balance, currency
FROM accounts
WHERE account_id = 'ACC-000001';

\echo '== Q6: filled orders oldest first, running cash committed, rank by value within instrument (statement) =='
SELECT
    i.symbol,
    o.side,
    o.quantity,
    COALESCE(o.executed_price, o.price)                             AS fill_price,
    o.quantity * COALESCE(o.executed_price, o.price)               AS trade_value,
    SUM(o.quantity * COALESCE(o.executed_price, o.price))
        OVER (ORDER BY o.created_on
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)     AS running_cash_committed,
    RANK() OVER (PARTITION BY o.instrument_id
                 ORDER BY o.quantity * COALESCE(o.executed_price, o.price) DESC) AS rank_within_instrument,
    o.created_on
FROM orders o
JOIN instruments i ON i.id = o.instrument_id
WHERE o.account_id = (SELECT id FROM accounts WHERE account_id = 'ACC-000001')
  AND o.status = 'FILLED'
ORDER BY o.created_on;

\echo '== verify_queries.sql complete =='
