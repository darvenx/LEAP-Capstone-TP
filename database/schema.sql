-- Convenience script to run migrations in order (from canonical DDL)
\i migrations/001_extensions_and_enums.sql
\i migrations/002_create_users.sql
\i migrations/003_create_indexes.sql
