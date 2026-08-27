-- 013_create_audit_logs.sql
CREATE TABLE audit_logs
(
    audit_log_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID
        REFERENCES users(user_id),

    entity_type VARCHAR(50) NOT NULL,

    entity_id UUID NOT NULL,

    action VARCHAR(50) NOT NULL,

    details TEXT,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);
