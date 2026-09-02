-- =============================================================================
-- 006_orders.sql
-- Recorded on receipt, before anyone knows whether it will succeed, because the
-- instruction is the thing the firm is legally on the hook for.
--   id              UUID, displayed ORD-<uuid>. Becomes fact_trades.source_order_id.
--   idempotency_key UNIQUE NOT NULL. Makes rule 8 / the 23505 demo a constraint
--                   refusal, not a read-then-write.
--   executed_price  NULL until the Sprint 7 executor fills it.
--   created_on      the watermark the Sprint 7 incremental extract pulls by.
-- =============================================================================

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
