-- Demonstrates real constraint violations against the actual schema.
-- Previous version referenced tables/columns that never existed (accounts,
-- orders.id, orders.idempotency_key, orders.price, an integer instrument_id)
-- and would have failed before it ever reached the constraint it meant to
-- test. Rewritten against database/migrations/.

-- Demonstrate SQLSTATE 23505 (unique_violation) via uq_user_watchlist_name.
-- Uses a name not present in seed/009_watchlists.sql so this runs the same
-- way against a fresh schema or a fully-seeded database.
BEGIN;
INSERT INTO watchlists (user_id, name)
VALUES ('a1000000-0000-0000-0000-000000000001', 'Failure Test Watchlist');
-- Second insert, same (user_id, name) pair -> unique violation
INSERT INTO watchlists (user_id, name)
VALUES ('a1000000-0000-0000-0000-000000000001', 'Failure Test Watchlist');
ROLLBACK;

-- Demonstrate SQLSTATE 23503 (foreign_key_violation): account_id does not exist
BEGIN;
INSERT INTO orders (account_id, instrument_id, side, order_type, quantity, remaining_quantity, limit_price)
VALUES ('00000000-0000-0000-0000-000000000000', 'c3000000-0000-0000-0000-000000000001', 'BUY', 'LIMIT', 1, 1, 150.00);
ROLLBACK;

-- Demonstrate SQLSTATE 23514 (check_violation) via chk_order_quantity: quantity must be > 0
BEGIN;
INSERT INTO orders (account_id, instrument_id, side, order_type, quantity, remaining_quantity, limit_price)
VALUES ('b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000001', 'BUY', 'LIMIT', 0, 0, 150.00);
ROLLBACK;

-- Demonstrate SQLSTATE 23514 (check_violation) via chk_limit_order_price: a
-- LIMIT order requires a positive limit_price
BEGIN;
INSERT INTO orders (account_id, instrument_id, side, order_type, quantity, remaining_quantity, limit_price)
VALUES ('b2000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-000000000001', 'BUY', 'LIMIT', 1, 1, NULL);
ROLLBACK;
