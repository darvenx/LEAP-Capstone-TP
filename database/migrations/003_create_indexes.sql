-- 014_create_indexes.sql
CREATE INDEX IF NOT EXISTS idx_orders_account
ON orders(account_id);

CREATE INDEX IF NOT EXISTS idx_orders_status
ON orders(status);

CREATE INDEX IF NOT EXISTS idx_orders_instrument
ON orders(instrument_id);

CREATE INDEX IF NOT EXISTS idx_orders_instrument_side_price
ON orders(
    instrument_id,
    side,
    limit_price
);

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

CREATE INDEX IF NOT EXISTS idx_price_alerts_user
ON price_alerts(user_id);

CREATE INDEX IF NOT EXISTS idx_price_alerts_instrument
ON price_alerts(instrument_id);
