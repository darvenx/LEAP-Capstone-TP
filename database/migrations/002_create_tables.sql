-- 002_create_tables.sql
CREATE TABLE users
(
    user_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    email VARCHAR(255) NOT NULL UNIQUE,

    password_hash VARCHAR(255) NOT NULL,

    role user_role NOT NULL
        DEFAULT 'CUSTOMER',

    status user_status NOT NULL
        DEFAULT 'ACTIVE',

    phone_number VARCHAR(20),

    date_of_birth DATE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


-- 003_create_trading_accounts.sql
CREATE TABLE trading_accounts
(
    account_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL UNIQUE
        REFERENCES users(user_id),

    account_number VARCHAR(30) NOT NULL UNIQUE,

    holder_name VARCHAR(255) NOT NULL,

    status account_status NOT NULL DEFAULT 'ACTIVE',

    currency CHAR(3) NOT NULL DEFAULT 'EUR',

    CONSTRAINT chk_account_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    cash_balance NUMERIC(18,2)
        NOT NULL DEFAULT 0
        CHECK (cash_balance >= 0),

    version BIGINT NOT NULL DEFAULT 0
        CHECK (version >= 0),

    CONSTRAINT chk_account_status
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


-- 004_create_instruments.sql
CREATE TABLE instruments
(
    instrument_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    ticker VARCHAR(20) NOT NULL UNIQUE,

    display_name VARCHAR(255) NOT NULL,

    asset_class asset_class NOT NULL,

    quote_currency CHAR(3) NOT NULL,

    is_tradable BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_instrument_quote_currency
        CHECK (quote_currency ~ '^[A-Z]{3}$'),

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_instrument_ticker
        CHECK (btrim(ticker) <> '')
);


-- 005_create_holdings.sql
CREATE TABLE holdings
(
    holding_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    account_id UUID NOT NULL
        REFERENCES trading_accounts(account_id),

    instrument_id UUID NOT NULL
        REFERENCES instruments(instrument_id),

    quantity NUMERIC(18,4) NOT NULL,

    average_buy_price NUMERIC(18,4) NOT NULL,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_holding_account_instrument
        UNIQUE(account_id, instrument_id),

    CONSTRAINT chk_holding_quantity
        CHECK (quantity >= 0),

    CONSTRAINT chk_holding_average_price
        CHECK (average_buy_price >= 0)
);


-- 006_create_portfolio_snapshots.sql
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


-- 007_create_orders.sql
CREATE TABLE orders
(
    order_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    account_id UUID NOT NULL
        REFERENCES trading_accounts(account_id),

    instrument_id UUID NOT NULL
        REFERENCES instruments(instrument_id),

    idempotency_key VARCHAR(128) NOT NULL UNIQUE,

    side order_side NOT NULL,

    order_type order_type NOT NULL,

    quantity NUMERIC(18,4) NOT NULL,

    remaining_quantity NUMERIC(18,4) NOT NULL,

    limit_price NUMERIC(18,4),

    status order_status NOT NULL
        DEFAULT 'NEW',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_order_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_order_idempotency_key
        CHECK (btrim(idempotency_key) <> ''),

    CONSTRAINT chk_remaining_quantity
        CHECK (
            remaining_quantity >= 0
            AND remaining_quantity <= quantity
        ),

    CONSTRAINT chk_limit_order_price
        CHECK (
            (order_type = 'MARKET' AND limit_price IS NULL)
            OR (order_type = 'LIMIT' AND limit_price > 0)
        ),

    CONSTRAINT chk_order_terminal_quantity
        CHECK (
            (status = 'NEW' AND remaining_quantity = quantity)
            OR (status IN ('FILLED', 'REJECTED', 'CANCELLED') AND remaining_quantity = 0)
        )
);


-- 008_create_cash_ledger.sql
CREATE TABLE cash_ledger
(
    ledger_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    account_id UUID NOT NULL
        REFERENCES trading_accounts(account_id),

    entry_type ledger_entry_type NOT NULL,

    reference_id UUID,

    amount NUMERIC(18,2) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_ledger_amount
        CHECK (amount <> 0),

    CONSTRAINT chk_ledger_entry_sign
        CHECK (
            (entry_type = 'INITIAL_BALANCE' AND amount > 0)
            OR (entry_type = 'BUY_TRADE' AND amount < 0)
            OR (entry_type = 'SELL_TRADE' AND amount > 0)
        )
);



-- 009_create_watchlists.sql
CREATE TABLE watchlists
(
    watchlist_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    watchlist_name VARCHAR(100) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_watchlist
        UNIQUE(user_id, watchlist_name)
);


-- 010_create_watchlist_items.sql
CREATE TABLE watchlist_items
(
    watchlist_item_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    watchlist_id UUID NOT NULL
        REFERENCES watchlists(watchlist_id),

    instrument_id UUID NOT NULL
        REFERENCES instruments(instrument_id),
    
    target_high_price NUMERIC(18, 4),
    target_low_price NUMERIC(18, 4),

    CONSTRAINT uq_watchlist_instrument
        UNIQUE(watchlist_id, instrument_id)
);


-- 012_create_notifications.sql
CREATE TABLE notifications
(
    notification_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    title VARCHAR(255),

    message TEXT NOT NULL,

    status notification_status NOT NULL
        DEFAULT 'PENDING',

    sent_at TIMESTAMPTZ,

    provider_reference VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


-- 013_create_audit_logs.sql
CREATE TABLE audit_logs
(
    audit_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID
        REFERENCES users(user_id),

    action VARCHAR(100) NOT NULL,

    entity_type VARCHAR(100) NOT NULL,

    entity_id UUID,

    old_values JSONB,

    new_values JSONB,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


