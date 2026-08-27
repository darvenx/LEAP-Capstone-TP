-- Docker initialization wrapper. Canonical files remain under database/.
\set ON_ERROR_STOP on
\i /docker-entrypoint-initdb.d/migrations/001_extensions_and_enums.sql
\i /docker-entrypoint-initdb.d/migrations/002_create_tables.sql
\i /docker-entrypoint-initdb.d/migrations/003_create_indexes.sql
\i /docker-entrypoint-initdb.d/migrations/004_order_guards.sql
\i /docker-entrypoint-initdb.d/seed/001_core.sql
