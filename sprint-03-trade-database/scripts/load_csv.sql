-- load_csv.sql
-- Bulk-load seed/csv/*.csv with COPY, in foreign-key order, then advance the
-- identity sequences the CSVs supplied explicit ids for.
--
-- Paths are relative to sprint-03-trade-database/ (the client's cwd). Used by
-- the Docker init hook, docker compose, and the local create_db one-liners.
-- Must be run with psql ( \copy is a client meta-command).

\copy users (user_id,email,full_name,password_hash,role,status,phone_number,date_of_birth,created_at,updated_at) FROM 'seed/csv/users.csv' WITH (FORMAT csv, HEADER true)
\copy accounts (id,account_id,user_id,holder_name,cash_balance,currency,status,version,created_at,updated_at) FROM 'seed/csv/accounts.csv' WITH (FORMAT csv, HEADER true)
\copy instruments (id,symbol,name,asset_class,currency,exchange,tradable,created_at) FROM 'seed/csv/instruments.csv' WITH (FORMAT csv, HEADER true)
\copy orders (id,idempotency_key,account_id,instrument_id,side,quantity,price,executed_price,status,created_on,updated_at) FROM 'seed/csv/orders.csv' WITH (FORMAT csv, HEADER true)
\copy positions (account_id,instrument_id,quantity,average_cost,updated_at) FROM 'seed/csv/positions.csv' WITH (FORMAT csv, HEADER true)
\copy cash_ledger (account_id,entry_type,reference_id,amount,created_at) FROM 'seed/csv/cash_ledger.csv' WITH (FORMAT csv, HEADER true)
\copy watchlists (watchlist_id,user_id,watchlist_name,created_at) FROM 'seed/csv/watchlists.csv' WITH (FORMAT csv, HEADER true)
\copy watchlist_items (watchlist_id,instrument_id,target_high_price,target_low_price) FROM 'seed/csv/watchlist_items.csv' WITH (FORMAT csv, HEADER true)
\copy price_alerts (user_id,instrument_id,target_price,direction,is_active,created_at) FROM 'seed/csv/price_alerts.csv' WITH (FORMAT csv, HEADER true)
\copy notifications (user_id,account_id,related_order_id,event_id,title,message,status,failure_reason,sent_at,provider_reference,created_at) FROM 'seed/csv/notifications.csv' WITH (FORMAT csv, HEADER true)
\copy portfolio_snapshots (account_id,portfolio_value,unrealized_pnl,snapshot_time) FROM 'seed/csv/portfolio_snapshots.csv' WITH (FORMAT csv, HEADER true)
\copy audit_logs (user_id,action,entity_type,entity_id,old_values,new_values,created_at) FROM 'seed/csv/audit_logs.csv' WITH (FORMAT csv, HEADER true)

SELECT setval(pg_get_serial_sequence('accounts','id'),    (SELECT MAX(id) FROM accounts));
SELECT setval(pg_get_serial_sequence('instruments','id'), (SELECT MAX(id) FROM instruments));
