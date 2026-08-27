-- 005_holdings.sql
-- AAPL: bought 10 @150.00 (o1), sold 3 @160.00 (o3) -> 7 units held, average
-- price unaffected by the sale.
-- WDXY: bought 5 @80.00 (o2), instrument is now delisted (is_active = FALSE)
-- but the holding remains, as does the order that produced it.
INSERT INTO holdings (holding_id, account_id, instrument_id, quantity, average_buy_price, updated_at)
VALUES
    ('f6000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000001', 7, 150.00, '2026-04-05 14:02:00+00'),
    ('f6000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000003', 5,  80.00, '2026-02-10 09:31:00+00');
