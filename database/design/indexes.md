# Index justifications

The plans below are the expected PostgreSQL access paths; run each query with
`EXPLAIN (ANALYZE, BUFFERS)` against the seeded database during review.

## Query 1: open orders for an account

`idx_orders_account_status_created (account_id, status, created_at DESC)`
allows an index scan restricted to one account and `NEW` status, already in
newest-first order. Without it PostgreSQL must scan or bitmap-filter orders and
sort the matching rows. The write cost is one index entry on every order
insert and on updates to any indexed column.

## Query 2: last 50 orders for an account

`idx_orders_account_created (account_id, created_at DESC)` supplies the account
filter and ordering, allowing PostgreSQL to stop after 50 rows. Without it,
large accounts require a scan and sort. The cost is maintaining a second
account-based index, paid on every order insert and relevant update.

## Query 3: current holdings for an account

The primary key on `holdings.holding_id` does not serve the account predicate;
`idx_holdings_account (account_id)` enables a direct scan of one account's
positions before the instrument join. Without it, PostgreSQL must scan all
holdings. Its cost is one additional index entry per holding insert/update.

## Query 4: orders since a timestamp

`idx_orders_created_at (created_at)` enables a range scan for the incremental
extract. Without it, PostgreSQL must scan the whole orders table as history
accumulates. The cost is maintaining one timestamp index for every order write.

## Query 5: account reference lookup

No extra index is required: `trading_accounts.account_number` has a unique
constraint, and PostgreSQL's unique index gives a direct equality lookup. The
cost is already paid for the required uniqueness.

The primary-key and foreign-key supporting indexes already present for the
other tables are similarly retained for referential checks and joins. Query 6
is intentionally served by window functions and receives no special index.
