-- 002_create_users.sql
CREATE TABLE users
(
    user_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    email VARCHAR(255) NOT NULL UNIQUE,

    password_hash VARCHAR(255) NOT NULL,

    role user_role NOT NULL
        DEFAULT 'CUSTOMER',

    status user_status NOT NULL
        DEFAULT 'ACTIVE',

    phone_number VARCHAR(20),

    date_of_birth DATE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);
