-- 007_create_orders.sql
CREATE TABLE orders
(
    order_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    account_id UUID NOT NULL
        REFERENCES trading_accounts(account_id),

    instrument_id UUID NOT NULL
        REFERENCES instruments(instrument_id),

    side order_side NOT NULL,

    order_type order_type NOT NULL,

    quantity NUMERIC(18,4) NOT NULL,

    remaining_quantity NUMERIC(18,4) NOT NULL,

    limit_price NUMERIC(18,2),

    status order_status NOT NULL
        DEFAULT 'OPEN',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_order_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_remaining_quantity
        CHECK (
            remaining_quantity >= 0
            AND remaining_quantity <= quantity
        ),

    CONSTRAINT chk_limit_order_price
        CHECK (
            order_type = 'MARKET'
            OR (
                order_type = 'LIMIT'
                AND limit_price IS NOT NULL
                AND limit_price > 0
            )
        )
);
