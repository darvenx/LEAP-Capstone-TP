package com.etleap.trading.domain;

import com.etleap.trading.domain.support.Money;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * An instruction to buy or sell a quantity of one instrument at a stated price, against one
 * account, in exactly one status.
 *
 * <p>An order is recorded when it is received - {@link #receive} - before anyone knows whether
 * it will succeed: it exists in {@link OrderStatus#NEW} the instant it arrives, holding
 * exactly what was requested, not a validated version of it. {@link OrderPlacementRules} then
 * evaluates the eight business rules against it and calls {@link #reject()} on the first one
 * that fails, or leaves it {@code NEW} - the working state, awaiting execution - if all eight
 * pass.
 *
 * <p>The order reaches exactly one terminal state ({@link OrderStatus#FILLED},
 * {@link OrderStatus#REJECTED} or {@link OrderStatus#CANCELLED}), and a disallowed transition
 * is refused by the order itself, not by its caller: {@link #fill}, {@link #reject} and
 * {@link #cancel} all throw once the order has already left {@code NEW}.
 *
 * <p>Its limit price is what the customer submitted; its executed price is what the Trade
 * Executor achieves against a live quote in Sprint 7, and does not exist until the order is
 * filled.
 */
public final class Order {

    private final String orderId;
    private final Long accountId;
    private final String symbol;
    private final OrderSide side;
    private final long quantity;
    private final BigDecimal limitPrice;
    private final String idempotencyKey;
    private final Instant receivedAt;

    private OrderStatus status;
    private BigDecimal executedPrice;

    private Order(String orderId, Long accountId, String symbol, OrderSide side, long quantity,
                   BigDecimal limitPrice, String idempotencyKey, Instant receivedAt) {
        this.orderId = orderId;
        this.accountId = accountId;
        this.symbol = symbol;
        this.side = side;
        this.quantity = quantity;
        this.limitPrice = limitPrice;
        this.idempotencyKey = idempotencyKey;
        this.receivedAt = receivedAt;
        this.status = OrderStatus.NEW;
        this.executedPrice = null;
    }

    /**
     * Records an order exactly as requested - structurally sane data, not yet a validated
     * order. Whether quantity and price are actually positive (rules 4 and 5) is a business
     * rule {@link OrderPlacementRules} evaluates next, deliberately not an invariant enforced
     * here: the audit trail should reflect what was actually asked for.
     */
    public static Order receive(Long accountId, String symbol, OrderSide side, long quantity,
                                 BigDecimal limitPrice, String idempotencyKey) {
        Objects.requireNonNull(accountId, "accountId must not be null");
        Objects.requireNonNull(symbol, "symbol must not be null");
        Objects.requireNonNull(side, "side must not be null");
        Objects.requireNonNull(limitPrice, "limitPrice must not be null");
        Objects.requireNonNull(idempotencyKey, "idempotencyKey must not be null");
        return new Order(UUID.randomUUID().toString(), accountId, symbol, side, quantity,
                Money.normalize(limitPrice), idempotencyKey, Instant.now());
    }

    /** Terminal: settles the order at the executed price achieved by the Trade Executor. */
    public void fill(BigDecimal executedPrice) {
        transitionTo(OrderStatus.FILLED);
        this.executedPrice = Money.normalize(Objects.requireNonNull(executedPrice, "executedPrice must not be null"));
    }

    /** Terminal: a business rule refused the order before it ever traded. */
    public void reject() {
        transitionTo(OrderStatus.REJECTED);
    }

    /** Terminal: the order is withdrawn before it filled. */
    public void cancel() {
        transitionTo(OrderStatus.CANCELLED);
    }

    public boolean isTerminal() {
        return status != OrderStatus.NEW;
    }

    private void transitionTo(OrderStatus target) {
        if (status != OrderStatus.NEW) {
            throw new IllegalStateException(
                    "Order " + orderId + " is already " + status + "; cannot transition to " + target);
        }
        this.status = target;
    }

    public String getOrderId() {
        return orderId;
    }

    public Long getAccountId() {
        return accountId;
    }

    public String getSymbol() {
        return symbol;
    }

    public OrderSide getSide() {
        return side;
    }

    public long getQuantity() {
        return quantity;
    }

    public BigDecimal getLimitPrice() {
        return limitPrice;
    }

    public String getIdempotencyKey() {
        return idempotencyKey;
    }

    public Instant getReceivedAt() {
        return receivedAt;
    }

    public OrderStatus getStatus() {
        return status;
    }

    /** The price the Trade Executor achieved. {@code null} until the order is {@code FILLED}. */
    public BigDecimal getExecutedPrice() {
        return executedPrice;
    }
}
