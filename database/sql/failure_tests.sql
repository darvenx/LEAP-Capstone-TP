-- Demonstrate SQLSTATE 23505 for duplicate idempotency key.
BEGIN;
INSERT INTO orders(order_id, account_id, instrument_id, idempotency_key, side, order_type, quantity, remaining_quantity, limit_price)
VALUES (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-aaaa-1111-aaaa-111111111111', 'DUP-KEY-TEST', 'BUY', 'LIMIT', 1, 1, 1);

-- Second insert should fail with unique violation
INSERT INTO orders(order_id, account_id, instrument_id, idempotency_key, side, order_type, quantity, remaining_quantity, limit_price)
VALUES (gen_random_uuid(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-aaaa-1111-aaaa-111111111111', 'DUP-KEY-TEST', 'BUY', 'LIMIT', 1, 1, 1);
ROLLBACK;

-- Demonstrate SQLSTATE 23503 for FK violation (referencing non-existent account)
BEGIN;
INSERT INTO orders(order_id, account_id, instrument_id, idempotency_key, side, order_type, quantity, remaining_quantity, limit_price)
VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', '11111111-aaaa-1111-aaaa-111111111111', 'FK-TEST', 'BUY', 'LIMIT', 1, 1, 1);
ROLLBACK;
