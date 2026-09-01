-- =============================================================================
-- 008_cash_ledger.sql
-- Immutable record of every cash movement. Moves atomically with a position in
-- one transaction (Sprint 7). FK points at the BIGINT accounts.id.
-- The amount sign must agree with the entry type: INITIAL_BALANCE / SELL_TRADE
-- add cash (> 0); BUY_TRADE removes it (< 0). Without this, a mistyped sign
-- would silently corrupt the running balance the Sprint 7 settlement relies on.
-- =============================================================================

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
        CHECK (amount <> 0),

    CONSTRAINT chk_ledger_entry_sign
        CHECK (
            (entry_type = 'INITIAL_BALANCE' AND amount > 0)
            OR (entry_type = 'BUY_TRADE'     AND amount < 0)
            OR (entry_type = 'SELL_TRADE'    AND amount > 0)
        )
);
