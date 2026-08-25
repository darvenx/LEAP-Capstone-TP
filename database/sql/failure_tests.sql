-- Demonstrate SQLSTATE 23505 for duplicate idempotency key
BEGIN;
INSERT INTO orders(id, idempotency_key, account_id, instrument_id, side, order_type, quantity, price)
SELECT gen_random_uuid(), 'DUP-KEY-TEST', a.id, i.instrument_id, 'BUY', 'MARKET', 1, 1
FROM accounts a, instruments i LIMIT 1;

-- Second insert should fail with unique violation
INSERT INTO orders(id, idempotency_key, account_id, instrument_id, side, order_type, quantity, price)
SELECT gen_random_uuid(), 'DUP-KEY-TEST', a.id, i.instrument_id, 'BUY', 'MARKET', 1, 1
FROM accounts a, instruments i LIMIT 1;
ROLLBACK;

-- Demonstrate SQLSTATE 23503 for FK violation (referencing non-existent account)
BEGIN;
INSERT INTO orders(id, idempotency_key, account_id, instrument_id, side, order_type, quantity, price)
VALUES (gen_random_uuid(), 'FK-TEST', '00000000-0000-0000-0000-000000000000', 1, 'BUY', 'MARKET', 1, 1);
ROLLBACK;
