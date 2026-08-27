-- 007_create_portfolio_snapshots.sql
CREATE TABLE portfolio_snapshots
(
    snapshot_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    account_id UUID NOT NULL
        REFERENCES trading_accounts(account_id),

    portfolio_value NUMERIC(18,2) NOT NULL,

    unrealized_pnl NUMERIC(18,2),

    snapshot_time TIMESTAMPTZ NOT NULL
);
