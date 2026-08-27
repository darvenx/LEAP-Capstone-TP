-- 004_orders.sql
INSERT INTO orders (order_id, account_id, instrument_id, side, order_type, quantity, remaining_quantity, limit_price, status, created_at, updated_at)
VALUES
    -- o1: alice buys 10 AAPL, fully filled
    ('d4000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000001', 'BUY',  'LIMIT',  10, 0, 150.00, 'FILLED',    '2026-01-15 10:00:00+00', '2026-01-15 10:05:00+00'),
    -- o2: alice buys 5 WDXY while it still traded, fully filled (instrument is delisted now, order/holding remain)
    ('d4000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000003', 'BUY',  'MARKET',  5, 0, NULL,   'FILLED',    '2026-02-10 09:30:00+00', '2026-02-10 09:31:00+00'),
    -- o3: alice sells 3 of her 10 AAPL, fully filled -> holding drops to 7, average price unchanged
    ('d4000000-0000-0000-0000-000000000003', 'b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000001', 'SELL', 'LIMIT',   3, 0, 160.00, 'FILLED',    '2026-04-05 14:00:00+00', '2026-04-05 14:02:00+00'),
    -- o4: alice tries to sell 50 AAPL while holding only 7 -> refused, no execution
    ('d4000000-0000-0000-0000-000000000004', 'b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000001', 'SELL', 'LIMIT',  50, 50, 160.00, 'REJECTED',  '2026-05-01 11:00:00+00', '2026-05-01 11:00:00+00'),
    -- o5: alice has a working limit order still open on the book
    ('d4000000-0000-0000-0000-000000000005', 'b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000002', 'BUY',  'LIMIT',   1,  1, 30000.00, 'NEW',     '2026-08-20 09:00:00+00', '2026-08-20 09:00:00+00'),
    -- o6: alice cancels a limit order before it fills
    ('d4000000-0000-0000-0000-000000000006', 'b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000001', 'BUY',  'LIMIT',   2,  2, 140.00, 'CANCELLED', '2026-06-12 10:00:00+00', '2026-06-12 15:00:00+00'),
    -- o7: dave's account only holds 100.00 cash, order value is 750.00 at market -> refused for insufficient funds
    ('d4000000-0000-0000-0000-000000000007', 'b2000000-0000-0000-0000-000000000004', 'c3000000-0000-0000-0000-000000000001', 'BUY',  'MARKET',  5,  5, NULL,   'REJECTED',  '2026-03-03 09:15:00+00', '2026-03-03 09:15:00+00');
