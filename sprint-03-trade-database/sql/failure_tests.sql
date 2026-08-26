-- failure_tests.sql
-- The two rejections Sprint 3 must demonstrate live, against the corrected
-- schema and the loaded seed. Run from the sprint-03-trade-database folder:
--
--   psql "$TARGET_DATABASE" -v ON_ERROR_STOP=0 -f sql/failure_tests.sql
--
-- ON_ERROR_STOP is intentionally OFF here: we WANT to see the database refuse
-- each row and print its SQLSTATE, rather than aborting the whole script.

\echo '== 23505: duplicate idempotency key =='
-- 'idem-0001-infy-buy' already exists from the seed. Re-using it must fail with
-- SQLSTATE 23505 (unique_violation) raised by the UNIQUE constraint on
-- orders.idempotency_key. This is how business rule 8 is enforced.
BEGIN;
INSERT INTO orders (idempotency_key, account_id, instrument_id, side, quantity, price, status)
VALUES (
    'idem-0001-infy-buy',
    (SELECT id FROM accounts    WHERE account_id = 'ACC-000001'),
    (SELECT id FROM instruments WHERE symbol     = 'INFY.NS'),
    'BUY', 1, 1.00, 'NEW'
);  -- expected: ERROR ... duplicate key value violates unique constraint ... SQLSTATE 23505
ROLLBACK;

\echo '== 23503: foreign key violation (account does not exist) =='
-- account_id 999999 has no parent row. The FK orders.account_id -> accounts.id
-- must refuse it with SQLSTATE 23503 (foreign_key_violation).
BEGIN;
INSERT INTO orders (idempotency_key, account_id, instrument_id, side, quantity, price, status)
VALUES (
    'idem-fk-violation-test',
    999999,
    (SELECT id FROM instruments WHERE symbol = 'INFY.NS'),
    'BUY', 1, 1.00, 'NEW'
);  -- expected: ERROR ... violates foreign key constraint ... SQLSTATE 23503
ROLLBACK;

\echo '== failure_tests.sql complete =='
