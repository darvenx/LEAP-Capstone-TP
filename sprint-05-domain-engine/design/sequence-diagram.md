# Sequence diagram — order placement

One order arriving at `OrderPlacementRules.evaluate(...)` and the eight business rules being
evaluated against it, in order. Each `break` fragment is a refusal path: the moment its
condition is true, evaluation stops and the exception on that line is thrown back to the
caller — nothing after it runs. A `break` fragment was chosen deliberately over eight
nested `alt` blocks: "first failure wins" is a short-circuit, and `break` is mermaid's fragment
for exactly that, rather than a diagram that reads as though every rule that follows a failure
still gets a chance to run.

The caller is deliberately generic — "Sprint 6 controller / Sprint 7 Trade Executor" — because
both call this exact method with the exact same rules, which is the whole point of the rules
living here rather than in a controller.

```mermaid
sequenceDiagram
    actor Caller as Caller (Sprint 6 controller / Sprint 7 Trade Executor)
    participant Rules as OrderPlacementRules
    participant Acc as Account
    participant Ins as Instrument
    participant Pos as Position
    participant Idem as IdempotencyKeyRegistry
    participant Ord as Order

    Caller->>Rules: evaluate(request, account, instrument, position)

    break Rule 1: account is null
        Rules-->>Caller: throw AccountNotFoundException (ACC-404)
    end

    Rules->>Acc: isActive()
    break Rule 2: account is not ACTIVE
        Rules-->>Caller: throw AccountNotActiveException (ACC-403)
    end

    Rules->>Ins: isTradable()
    break Rule 3: instrument is null or not tradable
        Rules-->>Caller: throw InstrumentNotFoundException (INS-404)
    end

    break Rule 4: quantity is null or <= 0
        Rules-->>Caller: throw OrderValidationException (VAL-422, field=quantity)
    end

    break Rule 5: price is null or <= 0
        Rules-->>Caller: throw OrderValidationException (VAL-422, field=price)
    end

    alt side is BUY
        Rules->>Acc: canAfford(quantity * price)
        break Rule 6: cannot afford
            Rules-->>Caller: throw InsufficientFundsException (ORD-400)
        end
    else side is SELL
        Rules->>Pos: getQuantity()
        break Rule 7: held quantity < order quantity
            Rules-->>Caller: throw InsufficientHoldingsException (ORD-409)
        end
    end

    Rules->>Idem: register(idempotencyKey)
    break Rule 8: key already registered
        Rules-->>Caller: throw DuplicateOrderException (ORD-409)
    end

    Note over Rules,Ord: All eight rules passed - the order is accepted, not yet executed.
    Rules->>Ord: receive(accountId, symbol, side, quantity, price, idempotencyKey)
    Ord-->>Rules: order (status = NEW)
    Rules-->>Caller: return order (status = NEW)
```

## Reading notes for the review

- Rules 6 and 7 are mutually exclusive by side (`alt side is BUY / else side is SELL`), not
  sequential — a `SELL` never touches `Account.canAfford`, and a `BUY` never touches
  `Position.getQuantity()`, which is exactly what `OrderLogicTest`'s
  `rule6DoesNotApply_toASellRegardlessOfCashBalance` and
  `rule7DoesNotApply_toABuyRegardlessOfPosition` assert.
- Rule 8 is the only rule with a side effect (`register` claims the key), which is why it runs
  last: every rule before it is a pure check, so nothing is claimed unless the order would
  otherwise be fully accepted.
- The one path with no `break` box reached is the very bottom: all eight rules passed, and the
  order that started this call still gets recorded — via `Order.receive` — exactly once, in
  `NEW`.
