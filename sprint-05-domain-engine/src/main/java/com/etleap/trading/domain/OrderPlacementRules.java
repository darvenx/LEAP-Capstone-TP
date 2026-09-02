package com.etleap.trading.domain;

import com.etleap.trading.domain.dto.PlaceOrderRequest;
import com.etleap.trading.domain.exception.AccountNotActiveException;
import com.etleap.trading.domain.exception.AccountNotFoundException;
import com.etleap.trading.domain.exception.DuplicateOrderException;
import com.etleap.trading.domain.exception.InstrumentNotFoundException;
import com.etleap.trading.domain.exception.InsufficientFundsException;
import com.etleap.trading.domain.exception.InsufficientHoldingsException;
import com.etleap.trading.domain.exception.OrderValidationException;
import com.etleap.trading.domain.support.Money;

import java.math.BigDecimal;
import java.util.Objects;

/**
 * Business rules 1 to 8. Enforced in this exact order; the first failure wins - a request that
 * breaks two rules gets the code of the first one, and a suspended account holding no cash
 * gets {@code ACC-403} rather than {@code ORD-400}. They live here, in the domain, and not in
 * a controller, so that Sprint 6's HTTP layer and Sprint 7's Trade Executor (which replays an
 * order without ever running a validator) enforce the identical rules for the identical
 * reasons.
 *
 * <p>Rules 4 and 5 are checked twice on purpose across the system as a whole: once as a
 * {@link PlaceOrderRequest} constraint (for the HTTP caller, in
 * {@code PlaceOrderRequestValidator}) and once here, because the domain has to hold for a
 * caller that never ran a validator.
 *
 * <p>Scope note on "an order is recorded when it is received, before anyone knows whether it
 * will succeed": {@link Order#receive} supports exactly that - it has no positivity
 * precondition on quantity or price, proven in {@code OrderTest}. This evaluator's own job is
 * narrower and is what Sprint 5 is scored against: decide, rule by rule, whether the order that
 * <em>would</em> be recorded is accepted, and hand back a {@link Order} in
 * {@link OrderStatus#NEW} only once it has passed all eight. Sprint 6 is where the moment of
 * HTTP receipt and the moment of rule evaluation actually separate (the audit-trail row is
 * written first, rules run second, a rejection is written back) - a persistence concern this
 * module deliberately has no dependency to express.
 */
public final class OrderPlacementRules {

    private final IdempotencyKeyRegistry idempotencyKeys;

    public OrderPlacementRules(IdempotencyKeyRegistry idempotencyKeys) {
        this.idempotencyKeys = Objects.requireNonNull(idempotencyKeys, "idempotencyKeys must not be null");
    }

    /**
     * Evaluates rules 1 to 8 against {@code request}, given the account, instrument and
     * position already resolved by the caller (fetching them is a persistence concern, not the
     * domain's). Returns the accepted order, in {@link OrderStatus#NEW}, if every rule passes.
     *
     * @param account    the account on the request, or {@code null} if none exists (rule 1)
     * @param instrument the instrument on the request, or {@code null} if none exists (rule 3)
     * @param position   the account's current position in the instrument, or {@code null} if
     *                   it holds none at all (rule 7 then treats the holding as zero)
     * @throws com.etleap.trading.domain.exception.TradingDomainException on the first rule that fails
     */
    public Order evaluate(PlaceOrderRequest request, Account account, Instrument instrument, Position position) {
        Objects.requireNonNull(request, "request must not be null");

        // Rule 1: the account must exist.
        if (account == null) {
            throw new AccountNotFoundException(request.accountId());
        }

        // Rule 2: the account must be ACTIVE.
        if (!account.isActive()) {
            throw new AccountNotActiveException(account.getAccountId(), account.getStatus());
        }

        // Rule 3: the instrument must exist and be tradable.
        if (instrument == null || !instrument.isTradable()) {
            throw new InstrumentNotFoundException(request.symbol());
        }

        // Rule 4: quantity must be greater than zero.
        if (request.quantity() == null || request.quantity() <= 0) {
            throw OrderValidationException.quantityMustBePositive(request.quantity());
        }

        // Rule 5: price must be greater than zero.
        if (request.price() == null || request.price().signum() <= 0) {
            throw OrderValidationException.priceMustBePositive(request.price());
        }

        // Rule 6: on a BUY, the cash balance must be at least quantity * price.
        if (request.side() == OrderSide.BUY) {
            BigDecimal cost = Money.normalize(request.price()).multiply(BigDecimal.valueOf(request.quantity()));
            if (!account.canAfford(cost)) {
                throw new InsufficientFundsException(account.getAccountId(), cost, account.getCashBalance());
            }
        }

        // Rule 7: on a SELL, the held quantity must be at least the order quantity.
        if (request.side() == OrderSide.SELL) {
            long held = position == null ? 0L : position.getQuantity();
            if (held < request.quantity()) {
                throw new InsufficientHoldingsException(
                        account.getAccountId(), request.symbol(), request.quantity(), held);
            }
        }

        // Rule 8: the idempotency key must not already have been used. Last, on purpose - the
        // rules above are all rejections that leave the world unchanged; this one has a side
        // effect (claiming the key), so everything that could still fail for a business reason
        // fails before we commit to it.
        if (!idempotencyKeys.register(request.idempotencyKey())) {
            throw new DuplicateOrderException(request.idempotencyKey());
        }

        return Order.receive(request.accountId(), request.symbol(), request.side(),
                request.quantity(), request.price(), request.idempotencyKey());
    }
}
