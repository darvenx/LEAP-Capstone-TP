-- =============================================================================
-- 001_extensions.sql
-- pgcrypto supplies gen_random_uuid(), used as the default for UUID primary
-- keys (orders, cash_ledger, watchlists, notifications, …).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
