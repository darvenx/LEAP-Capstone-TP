-- 013_create_audit_logs.sql
CREATE TABLE audit_logs
(
    audit_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID
        REFERENCES users(user_id),

    action VARCHAR(100) NOT NULL,

    entity_type VARCHAR(100) NOT NULL,

    entity_id UUID,

    old_values JSONB,

    new_values JSONB,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);
