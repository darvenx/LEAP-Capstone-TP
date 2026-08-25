-- 011_create_price_alerts.sql
CREATE TABLE price_alerts
(
    alert_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    instrument_id UUID NOT NULL
        REFERENCES instruments(instrument_id),

    target_price NUMERIC(18,2) NOT NULL,

    direction alert_direction NOT NULL,

    is_active BOOLEAN NOT NULL
        DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_alert_target_price
        CHECK (target_price > 0)
);
