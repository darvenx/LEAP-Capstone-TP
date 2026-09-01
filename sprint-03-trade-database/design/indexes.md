# Index justifications

An index is paid for on every insert and update to the columns it covers, and
`orders` is the most write-heavy table. So no index goes in without a query
behind it. The queries are the six named in the sprint brief.

Run `EXPLAIN ANALYZE` for each query before and after the index against loaded
data to confirm the plan change; the seed set is small, so also reason about the
plan at scale (orders grows without bound).

## Indexes created (`migrations/015_indexes.sql`)

### 1. `idx_orders_account_created` on `orders (account_id, created_on DESC)`

- **Serves query 1** (blotter: open orders for one account, newest first) and
  **query 2** (order history: last 50 for one account, any state, newest first).
- **Without it:** a sequential scan of every order in the table, filtered to one
  `account_id`, followed by a sort on `created_on`. Cost grows linearly with the
  whole `orders` table, on the query the dashboard runs on every load.
- **With it:** an index range scan on a single account's rows, already in
  `created_on DESC` order, so query 2's `LIMIT 50` stops after 50 index entries
  and query 1 adds only a cheap `status = 'NEW'` filter.
- **Write cost:** one composite index maintained per order insert/update. Both
  columns are set at insert and rarely change, so update churn is low.

### 2. `idx_orders_created_on` on `orders (created_on)`

- **Serves query 4** (the nightly Sprint 7 extract: every order created since a
  timestamp, across all accounts).
- **Without it:** a full scan of `orders` every night, growing with history even
  though each run only wants the last day.
- **With it:** a range scan from the watermark to now — the incremental,
  watermark-driven read `contracts/analytics-schema.sql` requires.
- **Write cost:** a single-column b-tree on an append-mostly, monotonic column,
  which is the cheapest index shape to maintain (inserts land at the right edge).

### 3. `idx_positions_account` on `positions (account_id)`

- **Serves query 3** (portfolio panel: everything one account holds).
- Note: `UNIQUE(account_id, instrument_id)` already indexes `account_id` as its
  leftmost column, so query 3 is served even without this index. It is created
  explicitly for clarity and to keep the account-only lookup optimal if the
  unique constraint is ever reshaped. **This does not count towards the three
  justified indexes** — see "Indexes a declared key already serves" below.

The three justified indexes are #1 (queries 1 and 2), #2 (query 4), plus the
`orders.idempotency_key` unique index below (query for rule 8 lookup).

## Indexes a declared key already serves (the cheapest indexes there are)

- **`orders.idempotency_key` UNIQUE** — enforces rule 8 and answers "find the
  order for this idempotency key" with an index unique scan. No separate index
  needed; the constraint is the index. This is what makes the `23505`
  demonstration a constraint refusal rather than a race.
- **`accounts.account_id` UNIQUE** — serves **query 5** (resolve an account from
  the customer-facing reference) with a unique scan. No separate index needed.
- **`positions (account_id, instrument_id)` UNIQUE** — serves query 3 via its
  leftmost column, as noted above.

## Extension indexes (also in `015_indexes.sql`)

These are Sprint 10 consumer paths, not one of the six named queries, so they do
not count towards the three justified indexes; they are listed for completeness
and are cheap on tables written far less often than `orders`.

- **`idx_notifications_account` on `notifications (account_id, created_at DESC)`**
  — the customer's notice feed (an account's notifications, newest first).
- **`idx_notifications_related_order` on `notifications (related_order_id)`** —
  trace every notification a given order produced.

`notifications.event_id` is `UNIQUE`, so the idempotency lookup ("has this event
already been delivered?") is served by the constraint's index with no separate
index needed — the same pattern as `orders.idempotency_key`.

## Query 6 earns no index

Query 6 (running total of cash committed and rank by value within instrument) is
answered with window functions over one account's filled orders. It is small per
account and deliberately not indexed; it exists to show the model answers a hard
analytical question cleanly, not to be fast at scale (that is the analytical
store's job, Sprint 4/7).
