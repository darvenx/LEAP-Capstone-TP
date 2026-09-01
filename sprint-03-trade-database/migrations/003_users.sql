-- =============================================================================
-- 003_users.sql
-- The identity record. In Sprint 8 the auth service owns credentials and links
-- a user to an account via ACCOUNTS.id. Kept here so watchlists, price alerts,
-- notifications and audit logs have an owner to reference.
-- =============================================================================

CREATE TABLE users
(
    user_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    email VARCHAR(255) NOT NULL UNIQUE,

    full_name VARCHAR(255) NOT NULL,

    password_hash VARCHAR(255) NOT NULL,

    role user_role NOT NULL
        DEFAULT 'CUSTOMER',

    status account_status NOT NULL
        DEFAULT 'ACTIVE',

    phone_number VARCHAR(20),

    date_of_birth DATE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);
