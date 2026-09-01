-- =============================================================================
-- 010_watchlist_items.sql
-- Instruments on a watchlist. instrument_id references BIGINT instruments.id.
-- Optional target_high / target_low are display hints only; price-alert state
-- lives on price_alerts, not here.
-- =============================================================================

CREATE TABLE watchlist_items
(
    watchlist_item_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    watchlist_id UUID NOT NULL
        REFERENCES watchlists(watchlist_id),

    instrument_id BIGINT NOT NULL
        REFERENCES instruments(id),

    target_high_price DECIMAL(18,2),
    target_low_price DECIMAL(18,2),

    CONSTRAINT uq_watchlist_instrument
        UNIQUE (watchlist_id, instrument_id)
);
