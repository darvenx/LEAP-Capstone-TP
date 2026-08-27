-- 004_create_instruments.sql
CREATE TABLE instruments
(
    instrument_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    ticker VARCHAR(20) NOT NULL UNIQUE,

    company_name VARCHAR(255) NOT NULL,

    exchange VARCHAR(20),

    stocks INT NOT NULL
        DEFAULT 0,

    sector VARCHAR(100),

    is_active BOOLEAN NOT NULL
        DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_instrument_stocks
        CHECK (stocks >= 0)
);
