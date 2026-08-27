-- 014_create_indexes.sql
CREATE INDEX idx_trading_accounts_user
    ON trading_accounts(user_id);

CREATE INDEX idx_orders_account_status
    ON orders(account_id, status);

CREATE INDEX idx_orders_instrument_side_price
    ON orders(instrument_id, side, limit_price);

CREATE INDEX idx_holdings_account
    ON holdings(account_id);

CREATE INDEX idx_holdings_instrument
    ON holdings(instrument_id);

CREATE INDEX idx_portfolio_snapshots_account_time
    ON portfolio_snapshots(account_id, snapshot_time);

CREATE INDEX idx_cash_ledger_account_created
    ON cash_ledger(account_id, created_at);

CREATE INDEX idx_watchlist_items_watchlist
    ON watchlist_items(watchlist_id);

CREATE INDEX idx_price_alerts_user
    ON price_alerts(user_id);

CREATE INDEX idx_price_alerts_instrument
    ON price_alerts(instrument_id);

CREATE INDEX idx_notifications_user_status
    ON notifications(user_id, status);

CREATE INDEX idx_audit_logs_entity
    ON audit_logs(entity_type, entity_id);
