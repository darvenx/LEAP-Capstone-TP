-- 010_create_watchlist_items.sql
CREATE TABLE watchlist_items
(
    watchlist_item_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    watchlist_id UUID NOT NULL
        REFERENCES watchlists(watchlist_id),

    instrument_id UUID NOT NULL
        REFERENCES instruments(instrument_id),

    target_high_price NUMERIC(18,2),

    target_low_price NUMERIC(18,2),

    added_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_watchlist_instrument
        UNIQUE(watchlist_id, instrument_id)
);
