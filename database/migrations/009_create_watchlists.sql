-- 009_create_watchlists.sql
CREATE TABLE watchlists
(
    watchlist_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    name VARCHAR(100) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_watchlist_name
        UNIQUE(user_id, name)
);
