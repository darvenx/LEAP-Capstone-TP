-- Convenience script to run migrations in order (from canonical DDL)
\i migrations/001_extensions_and_enums.sql
\i migrations/002_create_users.sql
\i migrations/003_create_trading_accounts.sql
\i migrations/004_create_instruments.sql
\i migrations/005_create_orders.sql
\i migrations/006_create_holdings.sql
\i migrations/007_create_portfolio_snapshots.sql
\i migrations/008_create_cash_ledger.sql
\i migrations/009_create_watchlists.sql
\i migrations/010_create_watchlist_items.sql
\i migrations/011_create_price_alerts.sql
\i migrations/012_create_notifications.sql
\i migrations/013_create_audit_logs.sql
\i migrations/014_create_indexes.sql
