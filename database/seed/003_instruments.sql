-- 003_instruments.sql
INSERT INTO instruments (instrument_id, ticker, company_name, exchange, stocks, sector, is_active, created_at)
VALUES
    ('c3000000-0000-0000-0000-000000000001', 'AAPL',    'Apple Inc.',   'NASDAQ', 1000000000, 'Technology',  TRUE,  '2015-01-01 00:00:00+00'),
    ('c3000000-0000-0000-0000-000000000002', 'BTC-USD', 'Bitcoin',      'CRYPTO', 0,           'Blockchain',  TRUE,  '2019-06-01 00:00:00+00'),
    -- delisted: still referenced by an older order and a current holding below
    ('c3000000-0000-0000-0000-000000000003', 'WDXY',    'Widget Corp.', 'NASDAQ', 5000000,     'Industrials', FALSE, '2012-03-01 00:00:00+00');
