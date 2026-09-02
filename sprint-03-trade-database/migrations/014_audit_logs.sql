-- =============================================================================
-- 014_audit_logs.sql
-- entity_id is text so it can hold either a UUID (orders) or a numeric
-- surrogate / business ref (accounts, instruments) without a type clash.
-- =============================================================================

CREATE TABLE audit_logs
(
    audit_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID
        REFERENCES users(user_id),

    action VARCHAR(100) NOT NULL,

    entity_type VARCHAR(100) NOT NULL,

    entity_id VARCHAR(64),

    old_values JSONB,

    new_values JSONB,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);
