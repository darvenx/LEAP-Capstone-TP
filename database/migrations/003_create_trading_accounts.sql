-- 003_create_trading_accounts.sql
CREATE TABLE trading_accounts
(
    account_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL UNIQUE
        REFERENCES users(user_id),

    account_number VARCHAR(30) NOT NULL UNIQUE,

    cash_balance NUMERIC(18,2)
        NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);
