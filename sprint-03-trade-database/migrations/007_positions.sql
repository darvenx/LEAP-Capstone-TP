-- =============================================================================
-- 007_positions.sql
-- What an account currently holds in one instrument: a whole quantity and the
-- weighted average cost. An account holds each instrument at most once (UNIQUE),
-- quantity never goes negative (no short selling). Derived-but-stored.
-- =============================================================================

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
