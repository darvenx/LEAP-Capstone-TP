-- =============================================================================
-- 013_portfolio_snapshots.sql
-- Sprint 10 Portfolio & P&L. Point-in-time valued snapshots of an account.
-- Operational trading tables stay the source of truth; this is the module's
-- own store for priced history.
-- =============================================================================

CREATE TABLE portfolio_snapshots
(
    snapshot_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    account_id BIGINT NOT NULL
        REFERENCES accounts(id),

    portfolio_value DECIMAL(18,2) NOT NULL,

    unrealized_pnl DECIMAL(18,2),

    snapshot_time TIMESTAMPTZ NOT NULL
);
