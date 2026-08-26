-- =============================================================================
-- 001_seed.sql
-- Realistic fixture data (~10 rows per table), applied after the schema by the
-- apply command. Insert order respects the foreign keys:
--   users -> accounts -> instruments -> orders -> positions -> cash_ledger
--   -> watchlists -> watchlist_items -> price_alerts -> notifications
--   -> portfolio_snapshots -> audit_logs
--
-- The data is internally consistent:
--   * every account's cash_balance equals the sum of its cash_ledger rows;
--   * every position reconciles against the account's FILLED orders
--     (quantity = filled buys - filled sells; average_cost = weighted average of
--      buy fills; a sell reduces quantity and leaves average_cost unchanged);
--   * suspended/closed accounts placed no orders after losing ACTIVE status.
--
-- Surrogate keys (accounts.id, instruments.id) are GENERATED ALWAYS AS IDENTITY,
-- so children resolve their parent by business reference (accounts.account_id)
-- or instruments.symbol. Users and watchlists carry explicit UUIDs so the
-- dependent rows can reference them.
-- =============================================================================


-- --- users (10): a spread of ACTIVE, SUSPENDED and CLOSED holders -------------
INSERT INTO users (user_id, email, full_name, password_hash, role, status, phone_number, date_of_birth, created_at, updated_at) VALUES
  ('10000000-0000-0000-0000-000000000001', 'priya.menon@example.com',   'Priya Menon',   'x-not-a-real-hash-01', 'CUSTOMER', 'ACTIVE',    '+91-98000-00001', '1988-04-12', '2026-01-05T04:00:00Z', '2026-01-05T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000002', 'rahul.verma@example.com',   'Rahul Verma',   'x-not-a-real-hash-02', 'CUSTOMER', 'ACTIVE',    '+91-98000-00002', '1985-09-02', '2026-01-06T04:00:00Z', '2026-01-06T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000003', 'anita.rao@example.com',     'Anita Rao',     'x-not-a-real-hash-03', 'CUSTOMER', 'ACTIVE',    '+91-98000-00003', '1992-07-21', '2026-01-07T04:00:00Z', '2026-01-07T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000004', 'vikram.singh@example.com',  'Vikram Singh',  'x-not-a-real-hash-04', 'CUSTOMER', 'ACTIVE',    '+91-98000-00004', '1995-02-02', '2026-01-08T04:00:00Z', '2026-01-08T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000005', 'meera.nair@example.com',    'Meera Nair',    'x-not-a-real-hash-05', 'CUSTOMER', 'ACTIVE',    '+91-98000-00005', '1990-12-15', '2026-01-09T04:00:00Z', '2026-01-09T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000006', 'arjun.iyer@example.com',    'Arjun Iyer',    'x-not-a-real-hash-06', 'CUSTOMER', 'ACTIVE',    '+1-415-555-0006', '1983-06-30', '2026-01-10T04:00:00Z', '2026-01-10T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000007', 'kavya.reddy@example.com',   'Kavya Reddy',   'x-not-a-real-hash-07', 'CUSTOMER', 'SUSPENDED', '+91-98000-00007', '1998-03-19', '2026-01-11T04:00:00Z', '2026-06-01T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000008', 'sanjay.gupta@example.com',  'Sanjay Gupta',  'x-not-a-real-hash-08', 'CUSTOMER', 'SUSPENDED', '+91-98000-00008', '1975-11-05', '2026-01-12T04:00:00Z', '2026-06-10T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000009', 'deepa.shah@example.com',    'Deepa Shah',    'x-not-a-real-hash-09', 'CUSTOMER', 'CLOSED',    '+91-98000-00009', '1980-08-08', '2026-01-13T04:00:00Z', '2026-05-20T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000010', 'rohan.das@example.com',     'Rohan Das',     'x-not-a-real-hash-10', 'ADMIN',    'CLOSED',    '+91-98000-00010', '1987-01-25', '2026-01-14T04:00:00Z', '2026-05-25T04:00:00Z');


-- --- accounts (10): states covered; ACC-000004 is low-cash; ACC-000006 is USD -
-- cash_balance values reconcile against the cash_ledger section below.
INSERT INTO accounts (account_id, user_id, holder_name, cash_balance, currency, status, version, created_at, updated_at) VALUES
  ('ACC-000001', '10000000-0000-0000-0000-000000000001', 'Priya Menon',  111330.00, 'INR', 'ACTIVE',    9, '2026-01-05T04:00:00Z', '2026-07-09T04:00:00Z'),
  ('ACC-000002', '10000000-0000-0000-0000-000000000002', 'Rahul Verma',  107700.00, 'INR', 'ACTIVE',    6, '2026-01-06T04:00:00Z', '2026-06-20T04:00:00Z'),
  ('ACC-000003', '10000000-0000-0000-0000-000000000003', 'Anita Rao',     47800.00, 'INR', 'ACTIVE',    4, '2026-01-07T04:00:00Z', '2026-05-28T04:00:00Z'),
  ('ACC-000004', '10000000-0000-0000-0000-000000000004', 'Vikram Singh',     50.00, 'INR', 'ACTIVE',    1, '2026-01-08T04:00:00Z', '2026-07-01T04:00:00Z'),
  ('ACC-000005', '10000000-0000-0000-0000-000000000005', 'Meera Nair',    25000.00, 'INR', 'ACTIVE',    0, '2026-01-09T04:00:00Z', '2026-01-09T04:00:00Z'),
  ('ACC-000006', '10000000-0000-0000-0000-000000000006', 'Arjun Iyer',    45120.00, 'USD', 'ACTIVE',    5, '2026-01-10T04:00:00Z', '2026-05-03T04:00:00Z'),
  ('ACC-000007', '10000000-0000-0000-0000-000000000007', 'Kavya Reddy',    8000.00, 'INR', 'SUSPENDED', 2, '2026-01-11T04:00:00Z', '2026-06-01T04:00:00Z'),
  ('ACC-000008', '10000000-0000-0000-0000-000000000008', 'Sanjay Gupta',   3200.00, 'INR', 'SUSPENDED', 1, '2026-01-12T04:00:00Z', '2026-06-10T04:00:00Z'),
  ('ACC-000009', '10000000-0000-0000-0000-000000000009', 'Deepa Shah',        0.00, 'INR', 'CLOSED',    3, '2026-01-13T04:00:00Z', '2026-05-20T04:00:00Z'),
  ('ACC-000010', '10000000-0000-0000-0000-000000000010', 'Rohan Das',         0.00, 'INR', 'CLOSED',    2, '2026-01-14T04:00:00Z', '2026-05-25T04:00:00Z');


-- --- instruments (10): NSE/BSE/US equities, an FX pair, a crypto pair, and a
-- delisted name (YESBANK.NS, tradable = FALSE) still referenced by orders/positions.
INSERT INTO instruments (symbol, name, asset_class, currency, exchange, tradable, created_at) VALUES
  ('INFY.NS',      'Infosys Ltd',                    'EQUITY', 'INR', 'NSE',    TRUE,  '2026-01-01T00:00:00Z'),
  ('RELIANCE.NS',  'Reliance Industries Ltd',        'EQUITY', 'INR', 'NSE',    TRUE,  '2026-01-01T00:00:00Z'),
  ('TCS.NS',       'Tata Consultancy Services Ltd',  'EQUITY', 'INR', 'NSE',    TRUE,  '2026-01-01T00:00:00Z'),
  ('HDFCBANK.NS',  'HDFC Bank Ltd',                  'EQUITY', 'INR', 'NSE',    TRUE,  '2026-01-01T00:00:00Z'),
  ('TATASTEEL.BO', 'Tata Steel Ltd',                 'EQUITY', 'INR', 'BSE',    TRUE,  '2026-01-01T00:00:00Z'),
  ('TATAMOTORS.BO','Tata Motors Ltd',                'EQUITY', 'INR', 'BSE',    TRUE,  '2026-01-01T00:00:00Z'),
  ('AAPL',         'Apple Inc',                      'EQUITY', 'USD', 'NASDAQ', TRUE,  '2026-01-01T00:00:00Z'),
  ('FX:EURUSD',    'Euro / US Dollar',               'FX',     'USD', 'FX',     TRUE,  '2026-01-01T00:00:00Z'),
  ('X:BTCINR',     'Bitcoin / Indian Rupee',         'CRYPTO', 'INR', 'CRYPTO', TRUE,  '2026-01-01T00:00:00Z'),
  ('YESBANK.NS',   'Yes Bank Ltd',                   'EQUITY', 'INR', 'NSE',    FALSE, '2026-01-01T00:00:00Z');


-- --- orders (15): all four states, several accounts, spread Feb-Jul 2026 ------
-- ACC-000001/2/3/6 trade (and their fills produce the positions below);
-- ACC-000004 is rejected for insufficient funds; suspended/closed accounts do
-- not trade.
INSERT INTO orders (idempotency_key, account_id, instrument_id, side, quantity, price, executed_price, status, created_on, updated_at) VALUES
  -- ACC-000001 (Priya)
  ('idem-0001-infy-buy',     (SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='INFY.NS'),      'BUY',  40, 1585.00, 1578.00, 'FILLED',    '2026-03-04T09:20:00Z', '2026-03-04T09:20:05Z'),
  ('idem-0002-reliance-buy', (SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  'BUY',  25, 2860.00, 2850.00, 'FILLED',    '2026-04-10T10:05:00Z', '2026-04-10T10:05:04Z'),
  ('idem-0003-infy-sell',    (SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='INFY.NS'),      'SELL', 15, 1600.00, 1610.00, 'FILLED',    '2026-05-12T13:15:00Z', '2026-05-12T13:15:03Z'),
  ('idem-0004-yesbank-buy',  (SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='YESBANK.NS'),   'BUY',  30,   15.00,   15.00, 'FILLED',    '2026-05-15T11:00:00Z', '2026-05-15T11:00:02Z'),
  ('idem-0005-tcs-buy',      (SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='TCS.NS'),       'BUY',  20, 3920.00, 3900.00, 'FILLED',    '2026-06-02T09:45:00Z', '2026-06-02T09:45:06Z'),
  ('idem-0006-reliance-new', (SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  'BUY',  10, 2900.00, NULL,    'NEW',       '2026-07-09T08:45:00Z', '2026-07-09T08:45:00Z'),
  -- ACC-000002 (Rahul)
  ('idem-0007-hdfc-buy',     (SELECT id FROM accounts WHERE account_id='ACC-000002'), (SELECT id FROM instruments WHERE symbol='HDFCBANK.NS'),  'BUY',  50, 1655.00, 1650.00, 'FILLED',    '2026-03-18T10:30:00Z', '2026-03-18T10:30:05Z'),
  ('idem-0008-tatasteel-buy',(SELECT id FROM accounts WHERE account_id='ACC-000002'), (SELECT id FROM instruments WHERE symbol='TATASTEEL.BO'), 'BUY', 100,  169.00,  168.00, 'FILLED',    '2026-04-22T12:10:00Z', '2026-04-22T12:10:04Z'),
  ('idem-0009-tatasteel-sell',(SELECT id FROM accounts WHERE account_id='ACC-000002'),(SELECT id FROM instruments WHERE symbol='TATASTEEL.BO'), 'SELL', 40,  174.00,  175.00, 'FILLED',    '2026-06-05T14:00:00Z', '2026-06-05T14:00:03Z'),
  ('idem-0010-tatamotors-can',(SELECT id FROM accounts WHERE account_id='ACC-000002'),(SELECT id FROM instruments WHERE symbol='TATAMOTORS.BO'),'BUY',  30,  980.00, NULL,    'CANCELLED', '2026-06-20T11:20:00Z', '2026-06-20T15:00:00Z'),
  -- ACC-000003 (Anita)
  ('idem-0011-reliance-buy', (SELECT id FROM accounts WHERE account_id='ACC-000003'), (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  'BUY',  10, 2830.00, 2820.00, 'FILLED',    '2026-02-14T09:35:00Z', '2026-02-14T09:35:05Z'),
  ('idem-0012-infy-buy',     (SELECT id FROM accounts WHERE account_id='ACC-000003'), (SELECT id FROM instruments WHERE symbol='INFY.NS'),      'BUY',  15, 1610.00, 1600.00, 'FILLED',    '2026-05-28T10:50:00Z', '2026-05-28T10:50:04Z'),
  -- ACC-000006 (Arjun, USD)
  ('idem-0013-aapl-buy',     (SELECT id FROM accounts WHERE account_id='ACC-000006'), (SELECT id FROM instruments WHERE symbol='AAPL'),         'BUY',  20,  192.00,  190.00, 'FILLED',    '2026-04-01T15:30:00Z', '2026-04-01T15:30:03Z'),
  ('idem-0014-eurusd-buy',   (SELECT id FROM accounts WHERE account_id='ACC-000006'), (SELECT id FROM instruments WHERE symbol='FX:EURUSD'),    'BUY',1000,    1.09,    1.08, 'FILLED',    '2026-05-03T16:00:00Z', '2026-05-03T16:00:02Z'),
  -- ACC-000004 (Vikram, low cash) - refused for insufficient funds
  ('idem-0015-reliance-rej', (SELECT id FROM accounts WHERE account_id='ACC-000004'), (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  'BUY',   5, 2900.00, NULL,    'REJECTED',  '2026-07-01T07:15:00Z', '2026-07-01T07:15:01Z');


-- --- positions (10): reconciled against the FILLED orders above ---------------
INSERT INTO positions (account_id, instrument_id, quantity, average_cost, updated_at) VALUES
  -- ACC-000001: INFY 40 buy - 15 sell = 25 @ 1578.00; RELIANCE 25 @ 2850.00;
  --             YESBANK 30 @ 15.00; TCS 20 @ 3900.00
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='INFY.NS'),      25, 1578.00, '2026-05-12T13:15:03Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  25, 2850.00, '2026-04-10T10:05:04Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='YESBANK.NS'),   30,   15.00, '2026-05-15T11:00:02Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), (SELECT id FROM instruments WHERE symbol='TCS.NS'),       20, 3900.00, '2026-06-02T09:45:06Z'),
  -- ACC-000002: HDFCBANK 50 @ 1650.00; TATASTEEL 100 buy - 40 sell = 60 @ 168.00
  ((SELECT id FROM accounts WHERE account_id='ACC-000002'), (SELECT id FROM instruments WHERE symbol='HDFCBANK.NS'),  50, 1650.00, '2026-03-18T10:30:05Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000002'), (SELECT id FROM instruments WHERE symbol='TATASTEEL.BO'), 60,  168.00, '2026-06-05T14:00:03Z'),
  -- ACC-000003: RELIANCE 10 @ 2820.00; INFY 15 @ 1600.00
  ((SELECT id FROM accounts WHERE account_id='ACC-000003'), (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  10, 2820.00, '2026-02-14T09:35:05Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000003'), (SELECT id FROM instruments WHERE symbol='INFY.NS'),      15, 1600.00, '2026-05-28T10:50:04Z'),
  -- ACC-000006: AAPL 20 @ 190.00; EURUSD 1000 @ 1.08
  ((SELECT id FROM accounts WHERE account_id='ACC-000006'), (SELECT id FROM instruments WHERE symbol='AAPL'),         20,  190.00, '2026-04-01T15:30:03Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000006'), (SELECT id FROM instruments WHERE symbol='FX:EURUSD'),  1000,    1.08, '2026-05-03T16:00:02Z');


-- --- cash_ledger (20): opening balances + trade movements ---------------------
-- Each account's rows sum to its accounts.cash_balance.
INSERT INTO cash_ledger (account_id, entry_type, reference_id, amount, created_at) VALUES
  -- ACC-000001: 300000 - 63120 - 71250 + 24150 - 450 - 78000 = 111330.00
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 'INITIAL_BALANCE', NULL, 300000.00, '2026-01-05T04:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0001-infy-buy'),      -63120.00, '2026-03-04T09:20:05Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0002-reliance-buy'),  -71250.00, '2026-04-10T10:05:04Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 'SELL_TRADE', (SELECT id FROM orders WHERE idempotency_key='idem-0003-infy-sell'),     24150.00, '2026-05-12T13:15:03Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0004-yesbank-buy'),     -450.00, '2026-05-15T11:00:02Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0005-tcs-buy'),       -78000.00, '2026-06-02T09:45:06Z'),
  -- ACC-000002: 200000 - 82500 - 16800 + 7000 = 107700.00
  ((SELECT id FROM accounts WHERE account_id='ACC-000002'), 'INITIAL_BALANCE', NULL, 200000.00, '2026-01-06T04:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000002'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0007-hdfc-buy'),      -82500.00, '2026-03-18T10:30:05Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000002'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0008-tatasteel-buy'), -16800.00, '2026-04-22T12:10:04Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000002'), 'SELL_TRADE', (SELECT id FROM orders WHERE idempotency_key='idem-0009-tatasteel-sell'), 7000.00, '2026-06-05T14:00:03Z'),
  -- ACC-000003: 100000 - 28200 - 24000 = 47800.00
  ((SELECT id FROM accounts WHERE account_id='ACC-000003'), 'INITIAL_BALANCE', NULL, 100000.00, '2026-01-07T04:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000003'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0011-reliance-buy'),  -28200.00, '2026-02-14T09:35:05Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000003'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0012-infy-buy'),      -24000.00, '2026-05-28T10:50:04Z'),
  -- ACC-000006 (USD): 50000 - 3800 - 1080 = 45120.00
  ((SELECT id FROM accounts WHERE account_id='ACC-000006'), 'INITIAL_BALANCE', NULL,  50000.00, '2026-01-10T04:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000006'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0013-aapl-buy'),       -3800.00, '2026-04-01T15:30:03Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000006'), 'BUY_TRADE',  (SELECT id FROM orders WHERE idempotency_key='idem-0014-eurusd-buy'),     -1080.00, '2026-05-03T16:00:02Z'),
  -- Opening balances only for the non-trading accounts.
  ((SELECT id FROM accounts WHERE account_id='ACC-000004'), 'INITIAL_BALANCE', NULL,      50.00, '2026-01-08T04:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000005'), 'INITIAL_BALANCE', NULL,   25000.00, '2026-01-09T04:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000007'), 'INITIAL_BALANCE', NULL,    8000.00, '2026-01-11T04:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000008'), 'INITIAL_BALANCE', NULL,    3200.00, '2026-01-12T04:00:00Z');


-- --- watchlists (10): one per user, explicit UUIDs so items can reference them
INSERT INTO watchlists (watchlist_id, user_id, watchlist_name, created_at) VALUES
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Tech Picks',   '2026-02-01T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Banking Watch','2026-02-02T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'Blue Chips',   '2026-02-03T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000004', 'Penny Watch',  '2026-02-04T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000005', 'Metals',       '2026-02-05T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000006', 'US Tech',      '2026-02-06T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000007', 'Crypto',       '2026-02-07T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000008', 'FX',           '2026-02-08T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000009', 'Retirement',   '2026-02-09T04:00:00Z'),
  ('20000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000010', 'Speculative',  '2026-02-10T04:00:00Z');


-- --- watchlist_items (10): instruments resolved by symbol --------------------
INSERT INTO watchlist_items (watchlist_id, instrument_id, target_high_price, target_low_price) VALUES
  ('20000000-0000-0000-0000-000000000001', (SELECT id FROM instruments WHERE symbol='INFY.NS'),      1700.00, 1550.00),
  ('20000000-0000-0000-0000-000000000001', (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  3000.00, 2700.00),
  ('20000000-0000-0000-0000-000000000002', (SELECT id FROM instruments WHERE symbol='HDFCBANK.NS'),  1750.00, 1600.00),
  ('20000000-0000-0000-0000-000000000002', (SELECT id FROM instruments WHERE symbol='TATASTEEL.BO'),  185.00,  160.00),
  ('20000000-0000-0000-0000-000000000003', (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  3050.00, 2750.00),
  ('20000000-0000-0000-0000-000000000004', (SELECT id FROM instruments WHERE symbol='YESBANK.NS'),     22.00,   12.00),
  ('20000000-0000-0000-0000-000000000005', (SELECT id FROM instruments WHERE symbol='TATAMOTORS.BO'),1050.00,  900.00),
  ('20000000-0000-0000-0000-000000000006', (SELECT id FROM instruments WHERE symbol='AAPL'),          210.00,  175.00),
  ('20000000-0000-0000-0000-000000000007', (SELECT id FROM instruments WHERE symbol='X:BTCINR'),  6500000.00, 4500000.00),
  ('20000000-0000-0000-0000-000000000008', (SELECT id FROM instruments WHERE symbol='FX:EURUSD'),       1.15,    1.02);


-- --- price_alerts (10) -------------------------------------------------------
INSERT INTO price_alerts (user_id, instrument_id, target_price, direction, is_active, created_at) VALUES
  ('10000000-0000-0000-0000-000000000001', (SELECT id FROM instruments WHERE symbol='INFY.NS'),      1650.00, 'ABOVE', TRUE,  '2026-03-01T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000001', (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  2800.00, 'BELOW', TRUE,  '2026-03-01T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000002', (SELECT id FROM instruments WHERE symbol='HDFCBANK.NS'),  1700.00, 'ABOVE', TRUE,  '2026-03-05T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000002', (SELECT id FROM instruments WHERE symbol='TATASTEEL.BO'),  160.00, 'BELOW', FALSE, '2026-03-05T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000003', (SELECT id FROM instruments WHERE symbol='RELIANCE.NS'),  3000.00, 'ABOVE', TRUE,  '2026-03-10T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000004', (SELECT id FROM instruments WHERE symbol='YESBANK.NS'),     20.00, 'ABOVE', TRUE,  '2026-03-12T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000005', (SELECT id FROM instruments WHERE symbol='TCS.NS'),        4000.00, 'ABOVE', TRUE,  '2026-03-15T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000006', (SELECT id FROM instruments WHERE symbol='AAPL'),           200.00, 'ABOVE', TRUE,  '2026-03-18T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000006', (SELECT id FROM instruments WHERE symbol='FX:EURUSD'),        1.10, 'ABOVE', TRUE,  '2026-03-18T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000007', (SELECT id FROM instruments WHERE symbol='X:BTCINR'),   5000000.00, 'BELOW', TRUE,  '2026-03-20T04:00:00Z');


-- --- notifications (10): a mix of PENDING / SENT / FAILED ---------------------
INSERT INTO notifications (user_id, title, message, status, sent_at, provider_reference, created_at) VALUES
  ('10000000-0000-0000-0000-000000000001', 'Order filled',      'Your BUY order for 40 INFY.NS was filled at 1578.00.',            'SENT',    '2026-03-04T09:20:10Z', 'prov-0001', '2026-03-04T09:20:06Z'),
  ('10000000-0000-0000-0000-000000000001', 'Price alert',       'INFY.NS crossed above your 1650.00 alert.',                       'PENDING', NULL,                    NULL,        '2026-06-30T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000002', 'Order filled',      'Your BUY order for 50 HDFCBANK.NS was filled at 1650.00.',        'SENT',    '2026-03-18T10:30:10Z', 'prov-0002', '2026-03-18T10:30:06Z'),
  ('10000000-0000-0000-0000-000000000002', 'Order cancelled',   'Your order for 30 TATAMOTORS.BO was cancelled.',                  'SENT',    '2026-06-20T15:00:05Z', 'prov-0003', '2026-06-20T15:00:01Z'),
  ('10000000-0000-0000-0000-000000000003', 'Welcome',           'Welcome to the Enterprise Trading Platform.',                     'SENT',    '2026-01-07T04:05:00Z', 'prov-0004', '2026-01-07T04:00:10Z'),
  ('10000000-0000-0000-0000-000000000004', 'Order rejected',    'Your BUY order for 5 RELIANCE.NS was rejected: insufficient funds.','FAILED', NULL,                   'prov-0005', '2026-07-01T07:15:02Z'),
  ('10000000-0000-0000-0000-000000000005', 'Statement ready',   'Your monthly statement is ready to view.',                        'PENDING', NULL,                    NULL,        '2026-07-01T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000006', 'Order filled',      'Your BUY order for 20 AAPL was filled at 190.00.',                'SENT',    '2026-04-01T15:30:08Z', 'prov-0006', '2026-04-01T15:30:04Z'),
  ('10000000-0000-0000-0000-000000000007', 'Account suspended', 'Your account has been suspended. Please contact support.',        'SENT',    '2026-06-01T04:05:00Z', 'prov-0007', '2026-06-01T04:00:05Z'),
  ('10000000-0000-0000-0000-000000000009', 'Account closed',    'Your account has been closed. History remains available.',        'SENT',    '2026-05-20T04:05:00Z', 'prov-0008', '2026-05-20T04:00:05Z');


-- --- portfolio_snapshots (10): value over time for the trading accounts -------
INSERT INTO portfolio_snapshots (account_id, portfolio_value, unrealized_pnl, snapshot_time) VALUES
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 280000.00,  3200.00, '2026-04-30T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 295000.00,  4100.00, '2026-05-31T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000001'), 300480.00,  5200.00, '2026-06-30T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000002'), 198000.00,  1500.00, '2026-05-31T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000002'), 200280.00,  1800.00, '2026-06-30T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000003'), 100000.00,   600.00, '2026-05-31T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000003'), 100600.00,  1200.00, '2026-06-30T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000006'),  49000.00,   300.00, '2026-05-31T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000006'),  49960.00,   450.00, '2026-06-30T18:00:00Z'),
  ((SELECT id FROM accounts WHERE account_id='ACC-000005'),  25000.00,     0.00, '2026-06-30T18:00:00Z');


-- --- audit_logs (10) ---------------------------------------------------------
INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_values, new_values, created_at) VALUES
  ('10000000-0000-0000-0000-000000000001', 'ACCOUNT_CREATED',    'account', 'ACC-000001',            NULL,                          '{"status":"ACTIVE"}',                 '2026-01-05T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000001', 'ORDER_PLACED',       'order',   'idem-0001-infy-buy',    NULL,                          '{"status":"NEW"}',                    '2026-03-04T09:20:00Z'),
  ('10000000-0000-0000-0000-000000000001', 'ORDER_FILLED',       'order',   'idem-0001-infy-buy',    '{"status":"NEW"}',            '{"status":"FILLED","price":1578.00}', '2026-03-04T09:20:05Z'),
  ('10000000-0000-0000-0000-000000000002', 'ORDER_PLACED',       'order',   'idem-0007-hdfc-buy',    NULL,                          '{"status":"NEW"}',                    '2026-03-18T10:30:00Z'),
  ('10000000-0000-0000-0000-000000000002', 'ORDER_CANCELLED',    'order',   'idem-0010-tatamotors-can','{"status":"NEW"}',          '{"status":"CANCELLED"}',              '2026-06-20T15:00:00Z'),
  ('10000000-0000-0000-0000-000000000003', 'ORDER_FILLED',       'order',   'idem-0011-reliance-buy','{"status":"NEW"}',            '{"status":"FILLED","price":2820.00}', '2026-02-14T09:35:05Z'),
  ('10000000-0000-0000-0000-000000000004', 'ORDER_REJECTED',     'order',   'idem-0015-reliance-rej','{"status":"NEW"}',            '{"status":"REJECTED","reason":"funds"}','2026-07-01T07:15:01Z'),
  ('10000000-0000-0000-0000-000000000007', 'ACCOUNT_SUSPENDED',  'account', 'ACC-000007',            '{"status":"ACTIVE"}',         '{"status":"SUSPENDED"}',              '2026-06-01T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000008', 'ACCOUNT_SUSPENDED',  'account', 'ACC-000008',            '{"status":"ACTIVE"}',         '{"status":"SUSPENDED"}',              '2026-06-10T04:00:00Z'),
  ('10000000-0000-0000-0000-000000000009', 'ACCOUNT_CLOSED',     'account', 'ACC-000009',            '{"status":"ACTIVE"}',         '{"status":"CLOSED"}',                 '2026-05-20T04:00:00Z');
