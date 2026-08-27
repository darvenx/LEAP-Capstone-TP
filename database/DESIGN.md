# Trade database design

## Rebuild command

From `database/`, run `TARGET_DATABASE=trade_db ./scripts/setup_db_and_seed.sh`.
The script reads `TARGET_DATABASE`, falls back to `POSTGRES_DB` from the root
`.env`, applies sorted migrations, then sorted SQL seed files. It passes
`ON_ERROR_STOP=1` and never prompts; PostgreSQL credentials must come from the
normal environment, `.pgpass`, or `PGSERVICE` configuration.

## Historical trade data

Operational `orders` records the customer's instruction and lifecycle. A
future `trade_executions` table should retain one immutable row per execution
at this grain: execution id, order id, account id, instrument id, side,
executed quantity, executed price, execution timestamp, venue, and executor
correlation id. `cash_ledger` retains the signed cash movement and references
the order or execution. The order is the legal instruction; the execution is
the immutable fact of what matched.

The Trade Executor writes execution, ledger, order status, cash balance, and
holding changes in one transaction. It locks the account and checks
`trading_accounts.version` so a concurrent writer discovers a lost update.
The order idempotency key prevents a retry from creating another instruction.

Sprint 7 extracts executions incrementally with a durable high-water mark on
`(executed_at, execution_id)`, using a strict tuple comparison and stable
ordering. The watermark advances only after the analytical load succeeds, so
a retry is safe and the entire history is not scanned nightly.

At one hundred times current volume, partition executions by month or quarter.
Archive immutable old partitions after the firm's retention period while
keeping the legal record. This adds partition creation, archive verification,
and reconciliation operations, but suits append-heavy time-bounded queries.
The write cost is one execution row, one ledger row, and their indexes per
fill. `cash_balance` and `holdings` are deliberate denormalized projections for
fast dashboards; reconciliation rebuilds them from the historical facts.
