-- 002_trading_accounts.sql
-- cash_balance is the running total after every cash_ledger entry seeded in
-- 007_cash_ledger.sql for that account — kept in sync by hand since there is
-- no trigger deriving it.
INSERT INTO trading_accounts (account_id, user_id, account_number, cash_balance, created_at, updated_at)
VALUES
    -- alice: 10000.00 initial - 1500.00 (buy AAPL) - 400.00 (buy WDXY) + 480.00 (sell AAPL) = 8580.00
    ('b2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'ACC-100001', 8580.00, '2026-01-01 00:00:00+00', '2026-04-05 14:02:00+00'),
    -- bob: SUSPENDED, thin balance, never traded
    ('b2000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000002', 'ACC-100002',   50.00, '2026-01-02 00:00:00+00', '2026-01-02 00:00:00+00'),
    -- carol: CLOSED, balance frozen at closure
    ('b2000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000003', 'ACC-100003',  500.00, '2026-01-03 00:00:00+00', '2026-03-15 00:00:00+00'),
    -- dave: ACTIVE but too thin to afford the order he attempts in 004_orders.sql
    ('b2000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000004', 'ACC-100004',  100.00, '2026-03-01 00:00:00+00', '2026-03-01 00:00:00+00');
