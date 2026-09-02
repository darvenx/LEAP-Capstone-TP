# Design decisions

The brief leaves two decisions to the team explicitly, and says the review will ask about
them. This is where the answers live, alongside the reasoning the review will want to walk.

## 1. Rules 4 and 5: is a seventh exception type warranted?

The six specified cases have no member for "quantity or price out of range." The brief allows
two answers: add a type, or argue validation alone covers it — provided we can say what
happens when the caller is the Trade Executor replaying an order and never ran a validator.

**We added a type: `OrderValidationException`, code `VAL-422`.**

Validation-alone does not survive the Trade Executor test. `PlaceOrderRequestValidator`
enforces the DTO's six constraints, but it is only ever *called* from the HTTP path Sprint 6
builds around `PlaceOrderRequest`. Sprint 7's Trade Executor replays an order against a live
quote in a different process, with no HTTP request, no DTO binding, and therefore nothing to
run a validator over. If quantity-and-price-in-range were expressed only as a
`jakarta.validation` constraint, that replay path would have no way to enforce rules 4 and 5 at
all — the very failure mode the brief's phrasing is pointing at.

Making it a domain exception, thrown by `OrderPlacementRules` — the same evaluator that runs
the other six checks — means every caller enforces rules 4 and 5 identically, for the same
reason business rules live in the domain rather than in a controller in the first place. This
is also why rules 4 and 5 are checked twice across the system on purpose: once as a
`PlaceOrderRequest` constraint (cheap, fails fast, gives the HTTP caller a body before the
domain is even touched) and once here (authoritative, holds for every caller, DTO-validated or
not).

`OrderValidationException` extends the same `TradingDomainException` base as the six specified
cases, so Sprint 6 still catches one base type in one place, and it carries `VAL-422` for both
rules — the offending field name is a typed detail (`getField()`), not the message, consistent
with how the other six exceptions keep investigation detail out of the response body.

## 2. Rule 8: making the idempotency check testable without a database

In Sprint 6 the actual authority on an idempotency key is the unique constraint on
`orders.idempotency_key` (built in Sprint 3) — not a read followed by a write. Two concurrent
requests carrying the same key both pass a read-then-write check (`SELECT ... WHERE key = ?`
finds nothing for either, so both proceed to `INSERT`), and the second `INSERT` either
duplicates the trade or arrives after the first has already settled. A unique constraint
closes that window because it is enforced at the point of write, atomically, by the database
itself.

Sprint 5 has no database. The rule still has to be expressible and testable here, so we
introduced the seam: `IdempotencyKeyRegistry`, with a single method,

```java
boolean register(String idempotencyKey);
```

`register` is deliberately one atomic operation that both checks and claims the key — modelling
the unique constraint's semantics directly, rather than splitting it into a check and a
separate claim the way a naive in-memory `Set` plus an `if (!set.contains(key))` would.
`InMemoryIdempotencyKeyRegistry` backs it with `ConcurrentHashMap.newKeySet().add(...)`, which
is itself a single compare-and-set at the JDK level: there is no window between checking and
claiming for two threads to both slip through.

`InMemoryIdempotencyKeyRegistryTest.exactlyOneOfManyConcurrentRegistrationsOfTheSameKeyWins`
proves this survives concurrency, not just single-threaded use: 64 threads are held at a
`CountDownLatch` gate and released together to race for the same key, and the test asserts
exactly one of the 64 calls returns `true`. That is the property a read-then-write check cannot
guarantee and a unique constraint can — the seam is built to make the same guarantee before
there is a database to enforce it.

Sprint 6's job is narrower than it looks: implement `IdempotencyKeyRegistry` against
`orders.idempotency_key`, where `register` reports `false` when the `INSERT` raises a
constraint-violation, not by issuing a `SELECT` first.

## Why `evaluate()` never calls `debit`/`applyBuy`/`applySell`

ETLEAPCP-1282 names a test path, "buy succeeds and updates cash and position," and it would be
a mistake to read that as an instruction to make `OrderPlacementRules.evaluate()` call
`Account.debit` or `Position.applyBuy` itself. The brief settles this directly, in two places:

> Rules 9 and 10 carry no error code and are not countable criteria this sprint, but leave room
> for them: cash and position move together or neither moves, and every order is recorded,
> including a rejected one...

> Its limit price is what the customer submitted; its executed price is what the Trade Executor
> achieves against a live quote in Sprint 7 and does not exist until the order is filled.

"Cash and position move together" is rule 9 - uncounted, and explicitly future work ("leave
room for them"), not one of the eight rules `evaluate()` is scored against. More concretely: the
amount that should actually move is the order's *executed* price, and that price "does not
exist until the order is filled" - which happens in a different process, in Sprint 7, against a
live quote. `evaluate()` only ever sees the customer's *limit* price. If it debited the account
or updated the position here, it would be moving money at a price the order was never actually
filled at, and Sprint 7 would then have no correct way to reconcile the difference.

So settlement stays exactly where the brief puts it: outside this sprint. What `evaluate()`
does instead is accept the order into `NEW` once all eight rules pass, and stop. The test path
the ticket names is proven a different way -
`OrderLogicTest.aSuccessfulBuyComposesWithAccountDebitAndPositionApplyBuy` and
`...aSuccessfulSellComposesWithPositionApplySellAndAccountCredit` - by asserting `evaluate()`
moves neither the account nor the position, and then driving `Account.debit`/`credit` and
`Position.applyBuy`/`applySell` directly against the values the accepted `Order` carries. That
demonstrates the entity operations a settler needs already exist and already compose correctly,
without this module guessing at a price it cannot yet know.

## Why the evaluation order is what it is

Rules 1 to 8 run in the fixed order the brief specifies, and the reasoning generalises past
just "that's the order in the table":

1. **Existence before state (1 → 2 → 3).** You cannot ask whether an account is active, or an
   instrument is tradable, before confirming either exists. `ACC-404` before `ACC-403`,
   `INS-404` after both, because knowing *who* is trading matters before knowing *what*.
2. **Structural validity before business affordability (4, 5 → 6, 7).** A quantity or price
   that is not even a valid number is a defect in the request itself; checking whether the
   account can afford an invalid quantity is nonsensical, so 4 and 5 run before 6 and 7 can
   even compute a meaningful cost.
3. **Side-effect-free checks before the one rule with a side effect (6, 7 → 8).** Rules 1
   through 7 are all pure: given the same inputs, they always give the same answer, and none of
   them change anything. Rule 8 is the only one that claims a resource (the idempotency key).
   Running it last means nothing is claimed unless every other reason to reject the order has
   already been ruled out — an order that fails for insufficient funds never burns its
   idempotency key, so a legitimate retry with a corrected amount and the *same* key is not
   itself treated as a duplicate.

`OrderLogicTest` asserts this ordering directly rather than trusting it will fall out of
correct rules in isolation: a suspended account with a zero balance breaks both rule 2 and rule
6 at once and must get `ACC-403`, not `ORD-400`
(`firstFailureWins_accountStatusBeforeFunds_...`); a request with both quantity and price
invalid must get `VAL-422` on `quantity`, not `price`
(`firstFailureWins_quantityBeforePrice_...`); and a request naming neither a real account nor a
real instrument must get `ACC-404`, not `INS-404`
(`firstFailureWins_accountExistenceBeforeInstrumentExistence`).
