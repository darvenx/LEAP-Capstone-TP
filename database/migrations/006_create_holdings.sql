-- 006_create_holdings.sql
CREATE TABLE holdings
(
    holding_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    account_id UUID NOT NULL
        REFERENCES trading_accounts(account_id),

    instrument_id UUID NOT NULL
        REFERENCES instruments(instrument_id),

    quantity NUMERIC(18,4) NOT NULL,

    average_buy_price NUMERIC(18,2) NOT NULL,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_holding_account_instrument
        UNIQUE(account_id, instrument_id),

    CONSTRAINT chk_holding_quantity
        CHECK (quantity >= 0),

    CONSTRAINT chk_holding_average_price
        CHECK (average_buy_price >= 0)
);
