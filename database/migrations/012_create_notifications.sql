-- 012_create_notifications.sql
CREATE TABLE notifications
(
    notification_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    title VARCHAR(255),

    message TEXT NOT NULL,

    status notification_status NOT NULL
        DEFAULT 'PENDING',

    sent_at TIMESTAMPTZ,

    provider_reference VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);
