-- 012_create_notifications.sql
CREATE TABLE notifications
(
    notification_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    price_alert_id UUID
        REFERENCES price_alerts(price_alert_id),

    message VARCHAR(500) NOT NULL,

    status notification_status NOT NULL
        DEFAULT 'PENDING',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);
