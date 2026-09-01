-- =============================================================================
-- 012_notifications.sql
-- Email delivery ledger. Channel is not stored: this sprint (and Sprint 10
-- until Preferences exists) delivers email only, using users.email. A
-- notification quotes an order's numbers as prose in `message` (what was sent).
-- The canonical price / quantity / status live once, on orders:
-- related_order_id REFERENCES the order rather than copying a price column that
-- would drift. event_id is UNIQUE so a replayed at-least-once trade event is
-- delivered at most once (NULL for notices not born from an event; Postgres
-- allows many NULLs under UNIQUE).
-- =============================================================================

CREATE TABLE notifications
(
    notification_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    -- The account this notification concerns (NULL for purely user-level notices).
    account_id BIGINT
        REFERENCES accounts(id),

    -- The order that triggered this notification, if any.
    related_order_id UUID
        REFERENCES orders(id),

    -- Idempotency for the Sprint 7/10 at-least-once feed.
    event_id VARCHAR(100) UNIQUE,

    title VARCHAR(255),

    message TEXT NOT NULL,

    status notification_status NOT NULL
        DEFAULT 'PENDING',

    -- Why a delivery failed. Only a FAILED row may carry a reason.
    failure_reason TEXT,

    sent_at TIMESTAMPTZ,

    provider_reference VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_notification_failure_reason
        CHECK (failure_reason IS NULL OR status = 'FAILED')
);
