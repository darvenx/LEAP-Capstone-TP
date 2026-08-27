-- 011_create_price_alerts.sql
-- NOTE: alert_direction was defined in 001_extensions_and_enums.sql but no
-- table ever used it, and the old indexes migration indexed a price_alerts
-- table that didn't exist anywhere. This migration adds the missing table.
CREATE TABLE price_alerts
(
    price_alert_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    instrument_id UUID NOT NULL
        REFERENCES instruments(instrument_id),

    direction alert_direction NOT NULL,

    target_price NUMERIC(18,2) NOT NULL,

    is_active BOOLEAN NOT NULL
        DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_price_alert_target
        CHECK (target_price > 0)
);
