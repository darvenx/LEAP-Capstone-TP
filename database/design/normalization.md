# Normalization notes

The model is in third normal form for the operational facts:

- `users` contains customer identity and authentication attributes.
- `trading_accounts` contains account identity, lifecycle state, currency, and
  its current cash projection. The customer-facing `account_number` is unique
  and separate from the internal UUID.
- `instruments` contains market reference data and tradability.
- `orders` contains one customer instruction and its lifecycle attributes.
- `holdings` contains one current position per account/instrument pair.
- `cash_ledger` contains immutable signed cash events rather than repeating a
  running balance on every event.

Foreign keys store relationships instead of duplicating holder, instrument, or
account details. The enum values constrain finite domain vocabularies, while
`NUMERIC` stores money and prices exactly.

`trading_accounts.cash_balance` and `holdings` are deliberate denormalized
projections. Cash can be rebuilt by summing the ledger and holdings can be
rebuilt from filled executions. They are stored because dashboard reads are
frequent and replaying an entire history for every page would be expensive.
The executor updates each projection in the same transaction as its source
fact; reconciliation queries should periodically verify them.

`orders.remaining_quantity` is retained because it is an operational state
needed by the executor. Sprint 3's policy is full fill or reject, so it is
zero for terminal rows and equals `quantity` for `NEW` rows. The trigger keeps
terminal statuses terminal. Historical terminal orders can still point to an
instrument that is no longer tradable.
