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
        CHECK (amount <> 0)
);
