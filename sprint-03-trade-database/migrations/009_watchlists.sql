-- =============================================================================
-- 009_watchlists.sql
-- Sprint 10 superset, retained now. A named list of instruments a customer
-- watches. UNIQUE (user_id, watchlist_name) so a customer cannot have two
-- lists with the same name.
-- =============================================================================

CREATE TABLE watchlists
(
    watchlist_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    watchlist_name VARCHAR(100) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_watchlist
        UNIQUE (user_id, watchlist_name)
);
