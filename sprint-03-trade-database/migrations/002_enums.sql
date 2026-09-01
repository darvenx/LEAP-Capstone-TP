-- =============================================================================
-- 002_enums.sql
-- The values the rest of the platform is built against. The Sprint 5 domain
-- enums (AccountStatus, OrderSide, OrderStatus) and the trade-api.yaml contract
-- mirror these exactly. There is no order_type: the platform models a single
-- limit price, not MARKET vs LIMIT.
-- =============================================================================

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
-- states. There is no partial-fill state.
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
