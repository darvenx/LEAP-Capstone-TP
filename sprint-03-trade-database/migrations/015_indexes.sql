-- =============================================================================
-- 015_indexes.sql
-- Justified against the six named queries in design/indexes.md. Only indexes
-- with a query behind them are created; those a declared key already serves
-- are documented there, not duplicated here.
-- =============================================================================

-- Query 1 (blotter: open orders for one account, newest first) and
-- Query 2 (order history: last 50 for one account, any state, newest first).
CREATE INDEX IF NOT EXISTS idx_orders_account_created
    ON orders (account_id, created_on DESC);

-- Query 4 (nightly Sprint 7 extract: every order created since a timestamp).
CREATE INDEX IF NOT EXISTS idx_orders_created_on
    ON orders (created_on);

-- Query 3 (portfolio panel): the UNIQUE (account_id, instrument_id) already
-- covers account-scoped lookups via its leftmost column; this explicit index is
-- for clarity and documented in design/indexes.md.
CREATE INDEX IF NOT EXISTS idx_positions_account
    ON positions (account_id);

-- Extension-table indexes (Sprint 10 consumers). Cheap now, needed later.
CREATE INDEX IF NOT EXISTS idx_cash_ledger_account_time
    ON cash_ledger (account_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user
    ON notifications (user_id);

CREATE INDEX IF NOT EXISTS idx_portfolio_snapshots_account_time
    ON portfolio_snapshots (account_id, snapshot_time DESC);

CREATE INDEX IF NOT EXISTS idx_watchlists_user
    ON watchlists (user_id);

CREATE INDEX IF NOT EXISTS idx_watchlist_items_watchlist
    ON watchlist_items (watchlist_id);

CREATE INDEX IF NOT EXISTS idx_price_alerts_instrument
    ON price_alerts (instrument_id);

-- Notifications for one account, newest first (the customer's notice feed).
CREATE INDEX IF NOT EXISTS idx_notifications_account
    ON notifications (account_id, created_at DESC);

-- Trace every notification produced by one order.
CREATE INDEX IF NOT EXISTS idx_notifications_related_order
    ON notifications (related_order_id);
