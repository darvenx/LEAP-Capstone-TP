-- 014_create_indexes.sql
CREATE INDEX IF NOT EXISTS idx_orders_account_status_created
ON orders(account_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_account_created
ON orders(account_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_instrument
ON orders(instrument_id);

CREATE INDEX IF NOT EXISTS idx_orders_created_at
ON orders(created_at);

CREATE INDEX IF NOT EXISTS idx_holdings_account
ON holdings(account_id);

CREATE INDEX IF NOT EXISTS idx_holdings_instrument
ON holdings(instrument_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user
ON notifications(user_id);

CREATE INDEX IF NOT EXISTS idx_portfolio_snapshots_account_time
ON portfolio_snapshots(
    account_id,
    snapshot_time DESC
);

CREATE INDEX IF NOT EXISTS idx_cash_ledger_account_time
ON cash_ledger(
    account_id,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS idx_watchlists_user
ON watchlists(user_id);

CREATE INDEX IF NOT EXISTS idx_watchlist_items_watchlist
ON watchlist_items(watchlist_id);

CREATE INDEX IF NOT EXISTS idx_watchlist_items_instrument
ON watchlist_items(instrument_id);
