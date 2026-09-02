-- =============================================================================
-- 011_price_alerts.sql
-- Sprint 10 Watchlists & price alerts. A threshold + direction + active flag
-- per (user, instrument). The poller evaluates these against market-data;
-- delivery goes through Notifications, never to a log.
-- =============================================================================

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
