-- =============================================================================
-- 001_schema.sql
-- The complete trade-database schema in one file, applied first (and, for now,
-- only) by the apply command. Sections run top to bottom in dependency order:
-- extensions, enums, tables (parents before children), then indexes.
--
-- Note on versioning: the Sprint 3 brief treats numbered migrations as the unit
-- of change. This project has been consolidated into a single schema file by
-- request; from here, schema changes are made by adding a new numbered file
-- (002_..., 003_...), never by editing this one after the first design review.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Extensions
-- pgcrypto supplies gen_random_uuid(), used as the orders primary key default.
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- -----------------------------------------------------------------------------
-- Enums
-- The values the rest of the platform is built against: the Sprint 5 domain
-- enums (AccountStatus, OrderSide, OrderStatus) and the trade-api.yaml contract
-- mirror these exactly.
-- -----------------------------------------------------------------------------
CREATE TYPE user_role AS ENUM (
    'CUSTOMER',
    'ADMIN'
);

-- One state machine serves both users and accounts: ACTIVE trades, SUSPENDED is
-- frozen but readable and reversible, CLOSED is finished but never deleted
-- (history must remain readable).
CREATE TYPE account_status AS ENUM (
    'ACTIVE',
    'SUSPENDED',
    'CLOSED'
);

CREATE TYPE order_side AS ENUM (
    'BUY',
    'SELL'
);

-- NEW is the working state; FILLED / REJECTED / CANCELLED are the three terminal
-- states. There is no partial-fill state, and there is no order_type: the
-- platform models a single limit price, not MARKET vs LIMIT.
CREATE TYPE order_status AS ENUM (
    'NEW',
    'FILLED',
    'REJECTED',
    'CANCELLED'
);

CREATE TYPE ledger_entry_type AS ENUM (
    'INITIAL_BALANCE',
    'BUY_TRADE',
    'SELL_TRADE'
);

CREATE TYPE alert_direction AS ENUM (
    'ABOVE',
    'BELOW'
);

CREATE TYPE notification_status AS ENUM (
    'PENDING',
    'SENT',
    'FAILED'
);


-- -----------------------------------------------------------------------------
-- users
-- The identity record. In Sprint 8 the auth service owns credentials and links
-- a user to an account via ACCOUNTS.id. Kept here so watchlists, price alerts,
-- notifications and audit logs have an owner to reference.
-- -----------------------------------------------------------------------------
CREATE TABLE users
(
    user_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    email VARCHAR(255) NOT NULL UNIQUE,

    full_name VARCHAR(255) NOT NULL,

    password_hash VARCHAR(255) NOT NULL,

    role user_role NOT NULL
        DEFAULT 'CUSTOMER',

    status account_status NOT NULL
        DEFAULT 'ACTIVE',

    phone_number VARCHAR(20),

    date_of_birth DATE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


-- -----------------------------------------------------------------------------
-- accounts
-- Carries the two identifiers trade-api.yaml requires and are not interchangeable:
--   id         numeric surrogate key (ACCOUNTS.id). The int64 the contract path,
--              request body and JWT accountId claim all mean.
--   account_id customer-facing business reference (e.g. ACC-000001), returned as
--              AccountResponse.accountId and the dim_account natural key.
-- -----------------------------------------------------------------------------
CREATE TABLE accounts
(
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    account_id VARCHAR(32) NOT NULL UNIQUE,

    user_id UUID UNIQUE
        REFERENCES users(user_id),

    holder_name VARCHAR(255) NOT NULL,

    cash_balance DECIMAL(18,2) NOT NULL
        DEFAULT 0,

    currency CHAR(3) NOT NULL
        DEFAULT 'INR',

    -- Account state machine. Only ACTIVE may trade (rule 2, ACC-403).
    status account_status NOT NULL
        DEFAULT 'ACTIVE',

    -- Optimistic lock. Sprint 6 increments this on every write and rejects a
    -- stale update with ORD-409 (NFR-02).
    version INT NOT NULL
        DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_account_cash_non_negative
        CHECK (cash_balance >= 0),

    CONSTRAINT chk_account_currency
        CHECK (currency ~ '^[A-Z]{3}$')
);


-- -----------------------------------------------------------------------------
-- instruments
-- A tradable instrument. symbol follows the Fauxnance scheme (.NS = NSE,
-- .BO = BSE, FX: = currency pair, X: = crypto, bare ticker = US venue). Delisting
-- is the tradable flag, never a delete: old orders still reference the row.
-- -----------------------------------------------------------------------------
CREATE TABLE instruments
(
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    symbol VARCHAR(20) NOT NULL UNIQUE,

    name VARCHAR(255) NOT NULL,

    asset_class VARCHAR(20) NOT NULL,

    currency CHAR(3) NOT NULL
        DEFAULT 'INR',

    exchange VARCHAR(20),

    tradable BOOLEAN NOT NULL
        DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_instrument_currency
        CHECK (currency ~ '^[A-Z]{3}$')
);


-- -----------------------------------------------------------------------------
-- orders
-- Recorded on receipt, before anyone knows whether it will succeed, because the
-- instruction is the thing the firm is legally on the hook for.
--   id              UUID, displayed ORD-<uuid>. Becomes fact_trades.source_order_id.
--   idempotency_key UNIQUE NOT NULL. Makes rule 8 / the 23505 demo a constraint
--                   refusal, not a read-then-write.
--   executed_price  NULL until the Sprint 7 executor fills it.
--   created_on      the watermark the Sprint 7 incremental extract pulls by.
-- -----------------------------------------------------------------------------
CREATE TABLE orders
(
    id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    idempotency_key VARCHAR(100) NOT NULL UNIQUE,

    account_id BIGINT NOT NULL
        REFERENCES accounts(id),

    instrument_id BIGINT NOT NULL
        REFERENCES instruments(id),

    side order_side NOT NULL,

    quantity INTEGER NOT NULL,

    price DECIMAL(18,2) NOT NULL,

    executed_price DECIMAL(18,2),

    status order_status NOT NULL
        DEFAULT 'NEW',

    created_on TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_order_quantity_positive
        CHECK (quantity > 0),

    CONSTRAINT chk_order_price_positive
        CHECK (price > 0),

    CONSTRAINT chk_order_executed_price_positive
        CHECK (executed_price IS NULL OR executed_price > 0)
);


-- -----------------------------------------------------------------------------
-- positions
-- What an account currently holds in one instrument: a whole quantity and the
-- weighted average cost. An account holds each instrument at most once (UNIQUE),
-- quantity never goes negative (no short selling). Derived-but-stored.
-- -----------------------------------------------------------------------------
CREATE TABLE positions
(
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    account_id BIGINT NOT NULL
        REFERENCES accounts(id),

    instrument_id BIGINT NOT NULL
        REFERENCES instruments(id),

    quantity INTEGER NOT NULL,

    average_cost DECIMAL(18,2) NOT NULL,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_position_account_instrument
        UNIQUE (account_id, instrument_id),

    CONSTRAINT chk_position_quantity_non_negative
        CHECK (quantity >= 0),

    CONSTRAINT chk_position_average_cost_non_negative
        CHECK (average_cost >= 0)
);


-- -----------------------------------------------------------------------------
-- cash_ledger
-- Immutable record of every cash movement. Moves atomically with a position in
-- one transaction (Sprint 7). FK points at the BIGINT accounts.id.
-- -----------------------------------------------------------------------------
CREATE TABLE cash_ledger
(
    ledger_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    account_id BIGINT NOT NULL
        REFERENCES accounts(id),

    entry_type ledger_entry_type NOT NULL,

    -- The order (or other event) that caused the movement, for lineage.
    reference_id UUID,

    amount DECIMAL(18,2) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_ledger_amount_non_zero
        CHECK (amount <> 0)
);


-- -----------------------------------------------------------------------------
-- watchlists (Sprint 10 superset, retained now)
-- -----------------------------------------------------------------------------
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
        UNIQUE (user_id, watchlist_name)
);


-- -----------------------------------------------------------------------------
-- watchlist_items (instrument_id references BIGINT instruments.id)
-- -----------------------------------------------------------------------------
CREATE TABLE watchlist_items
(
    watchlist_item_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    watchlist_id UUID NOT NULL
        REFERENCES watchlists(watchlist_id),

    instrument_id BIGINT NOT NULL
        REFERENCES instruments(id),

    target_high_price DECIMAL(18,2),
    target_low_price DECIMAL(18,2),

    CONSTRAINT uq_watchlist_instrument
        UNIQUE (watchlist_id, instrument_id)
);


-- -----------------------------------------------------------------------------
-- price_alerts (instrument_id references BIGINT instruments.id)
-- -----------------------------------------------------------------------------
CREATE TABLE price_alerts
(
    alert_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    instrument_id BIGINT NOT NULL
        REFERENCES instruments(id),

    target_price DECIMAL(18,2) NOT NULL,

    direction alert_direction NOT NULL,

    is_active BOOLEAN NOT NULL
        DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_alert_target_price
        CHECK (target_price > 0)
);


-- -----------------------------------------------------------------------------
-- notifications (Sprint 10 superset, retained now)
-- -----------------------------------------------------------------------------
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


-- -----------------------------------------------------------------------------
-- portfolio_snapshots (Sprint 10 superset; FK at BIGINT accounts.id)
-- -----------------------------------------------------------------------------
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


-- -----------------------------------------------------------------------------
-- audit_logs
-- entity_id is text so it can hold either a UUID (orders) or a numeric surrogate
-- (accounts, instruments) without a type clash.
-- -----------------------------------------------------------------------------
CREATE TABLE audit_logs
(
    audit_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID
        REFERENCES users(user_id),

    action VARCHAR(100) NOT NULL,

    entity_type VARCHAR(100) NOT NULL,

    entity_id VARCHAR(64),

    old_values JSONB,

    new_values JSONB,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


-- -----------------------------------------------------------------------------
-- Indexes
-- Justified against the six named queries in design/indexes.md. Only indexes
-- with a query behind them are created; those a declared key already serves are
-- documented there, not duplicated here.
-- -----------------------------------------------------------------------------

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
