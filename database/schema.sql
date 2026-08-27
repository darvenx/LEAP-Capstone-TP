-- Convenience script for psql users. The setup script is the canonical
-- migrate-and-seed command.
\i migrations/001_extensions_and_enums.sql
\i migrations/002_create_users.sql
\i migrations/003_create_indexes.sql
\i migrations/004_order_guards.sql
