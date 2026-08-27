-- Deterministic fixtures for the Sprint 3 acceptance paths.

INSERT INTO users (user_id, email, password_hash, role, status, created_at, updated_at)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'alice@example.com', 'hash1', 'CUSTOMER', 'ACTIVE', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('22222222-2222-2222-2222-222222222222', 'bob@example.com', 'hash2', 'CUSTOMER', 'ACTIVE', '2026-01-02T00:00:00Z', '2026-01-02T00:00:00Z'),
    ('33333333-3333-3333-3333-333333333333', 'carol@example.com', 'hash3', 'CUSTOMER', 'ACTIVE', '2026-01-03T00:00:00Z', '2026-01-03T00:00:00Z');

INSERT INTO trading_accounts (account_id, user_id, account_number, holder_name, status, currency, cash_balance, version, created_at, updated_at)
VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'ACC-1001', 'Alice Morgan', 'ACTIVE', 'EUR', 8450.00, 4, '2026-01-01T00:00:00Z', '2026-04-01T00:00:00Z'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'ACC-1002', 'Bob Singh', 'SUSPENDED', 'EUR', 50.00, 0, '2026-01-02T00:00:00Z', '2026-01-02T00:00:00Z'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '33333333-3333-3333-3333-333333333333', 'ACC-1003', 'Carol Wright', 'CLOSED', 'EUR', 0.00, 0, '2026-01-03T00:00:00Z', '2026-01-03T00:00:00Z');

INSERT INTO instruments (instrument_id, ticker, display_name, asset_class, quote_currency, is_tradable, created_at)
VALUES
    ('11111111-aaaa-1111-aaaa-111111111111', 'AAPL', 'Apple Inc.', 'EQUITY', 'USD', TRUE, '2020-01-01T00:00:00Z'),
    ('22222222-bbbb-2222-bbbb-222222222222', 'BTC-USD', 'Bitcoin / US Dollar', 'CRYPTO_PAIR', 'USD', FALSE, '2019-01-01T00:00:00Z'),
    ('33333333-cccc-3333-cccc-333333333333', 'SPY', 'SPDR S&P 500 ETF', 'ETF', 'USD', TRUE, '2021-01-01T00:00:00Z');

INSERT INTO holdings (holding_id, account_id, instrument_id, quantity, average_buy_price, updated_at)
VALUES
    ('44444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-aaaa-1111-aaaa-111111111111', 7.0000, 150.0000, '2026-04-01T00:00:00Z'),
    ('55555555-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-bbbb-2222-bbbb-222222222222', 0.0100, 50000.0000, '2026-01-10T00:30:00Z');

INSERT INTO orders (order_id, account_id, instrument_id, idempotency_key, side, order_type, quantity, remaining_quantity, limit_price, status, created_at, updated_at)
VALUES
    ('10000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-aaaa-1111-aaaa-111111111111', 'seed-new-aapl', 'BUY', 'LIMIT', 2.0000, 2.0000, 155.0000, 'NEW', '2026-04-01T10:00:00Z', '2026-04-01T10:00:00Z'),
    ('10000000-0000-0000-0000-000000000006', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-bbbb-2222-bbbb-222222222222', 'seed-filled-delisted', 'BUY', 'LIMIT', 0.0100, 0.0000, 50000.0000, 'FILLED', '2026-01-10T00:00:00Z', '2026-01-10T00:30:00Z'),
    ('10000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-aaaa-1111-aaaa-111111111111', 'seed-filled-buy', 'BUY', 'LIMIT', 10.0000, 0.0000, 150.0000, 'FILLED', '2026-02-01T10:00:00Z', '2026-02-01T10:30:00Z'),
    ('10000000-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-aaaa-1111-aaaa-111111111111', 'seed-filled-sell', 'SELL', 'LIMIT', 3.0000, 0.0000, 150.0000, 'FILLED', '2026-03-01T10:00:00Z', '2026-03-01T10:30:00Z'),
    ('10000000-0000-0000-0000-000000000004', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-bbbb-2222-bbbb-222222222222', 'seed-rejected-delisted', 'BUY', 'LIMIT', 1.0000, 0.0000, 50000.0000, 'REJECTED', '2026-01-15T10:00:00Z', '2026-01-15T10:01:00Z'),
    ('10000000-0000-0000-0000-000000000005', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-cccc-3333-cccc-333333333333', 'seed-cancelled-etf', 'BUY', 'LIMIT', 4.0000, 0.0000, 500.0000, 'CANCELLED', '2026-02-15T10:00:00Z', '2026-02-15T10:05:00Z');

INSERT INTO cash_ledger (ledger_id, account_id, entry_type, reference_id, amount, created_at)
VALUES
    ('20000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'INITIAL_BALANCE', NULL, 10000.00, '2026-01-01T00:00:00Z'),
    ('20000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'BUY_TRADE', '10000000-0000-0000-0000-000000000006', -500.00, '2026-01-10T00:30:00Z'),
    ('20000000-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'BUY_TRADE', '10000000-0000-0000-0000-000000000002', -1500.00, '2026-02-01T10:30:00Z'),
    ('20000000-0000-0000-0000-000000000004', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'SELL_TRADE', '10000000-0000-0000-0000-000000000003', 450.00, '2026-03-01T10:30:00Z'),
    ('20000000-0000-0000-0000-000000000005', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'INITIAL_BALANCE', NULL, 50.00, '2026-01-02T00:00:00Z');
