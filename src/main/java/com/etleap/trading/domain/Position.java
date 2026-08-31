package com.etleap.trading.domain;

import com.etleap.trading.domain.exception.InsufficientHoldingsException;
import com.etleap.trading.domain.support.Money;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Objects;

/**
 * The net holding of one instrument in one account, with its average cost, moved by a buy or a
 * sell.
 *
 * <p>The average cost rule is asymmetric, on purpose: {@link #applyBuy(long, BigDecimal)}
 * recalculates the average across the old holding and the new units at the price they were
 * bought at, while {@link #applySell(long)} only reduces the quantity and leaves the average
 * alone. That asymmetry is what makes realised profit and loss computable at the point of
 * sale - if a sell also touched the average, "cost basis at the moment sold" would already be
 * gone by the time anyone asked for it.
 *
 * <p>A position never goes negative: short selling is out of scope for this domain.
 */
public final class Position {

    private final Long accountId;
    private final String symbol;
    private long quantity;
    private BigDecimal averageCost;

    private Position(Long accountId, String symbol, long quantity, BigDecimal averageCost) {
        this.accountId = Objects.requireNonNull(accountId, "accountId must not be null");
        this.symbol = requireNonBlank(symbol, "symbol");
        if (quantity < 0) {
            throw new IllegalArgumentException("quantity must not be negative, got: " + quantity);
        }
        this.quantity = quantity;
        this.averageCost = Money.normalize(Objects.requireNonNull(averageCost, "averageCost must not be null"));
    }

    /** A holding of zero, before any trade has moved it. */
    public static Position empty(Long accountId, String symbol) {
        return new Position(accountId, symbol, 0L, BigDecimal.ZERO);
    }

    /** Reconstructs a position at a known quantity and average cost (e.g. when loaded). */
    public static Position of(Long accountId, String symbol, long quantity, BigDecimal averageCost) {
        return new Position(accountId, symbol, quantity, averageCost);
    }

    /**
     * A buy: recalculates the average cost across the old holding and the newly bought units,
     * at the price they were bought at.
     */
    public void applyBuy(long boughtQuantity, BigDecimal price) {
        if (boughtQuantity <= 0) {
            throw new IllegalArgumentException("boughtQuantity must be greater than zero, got: " + boughtQuantity);
        }
        BigDecimal normalizedPrice = Money.normalize(Objects.requireNonNull(price, "price must not be null"));

        BigDecimal oldTotalCost = averageCost.multiply(BigDecimal.valueOf(quantity));
        BigDecimal boughtCost = normalizedPrice.multiply(BigDecimal.valueOf(boughtQuantity));
        long newQuantity = quantity + boughtQuantity;

        this.averageCost = oldTotalCost.add(boughtCost)
                .divide(BigDecimal.valueOf(newQuantity), 2, RoundingMode.HALF_UP);
        this.quantity = newQuantity;
    }

    /**
     * A sell: reduces the quantity by {@code soldQuantity} and leaves the average cost
     * untouched. Refuses - without touching the holding - if that would leave the position
     * negative.
     *
     * @throws InsufficientHoldingsException if {@code soldQuantity} exceeds the current holding
     */
    public void applySell(long soldQuantity) {
        if (soldQuantity <= 0) {
            throw new IllegalArgumentException("soldQuantity must be greater than zero, got: " + soldQuantity);
        }
        if (soldQuantity > quantity) {
            throw new InsufficientHoldingsException(accountId, symbol, soldQuantity, quantity);
        }
        this.quantity -= soldQuantity;
        // averageCost is deliberately left alone.
    }

    public Long getAccountId() {
        return accountId;
    }

    public String getSymbol() {
        return symbol;
    }

    public long getQuantity() {
        return quantity;
    }

    public BigDecimal getAverageCost() {
        return averageCost;
    }

    private static String requireNonBlank(String value, String fieldName) {
        Objects.requireNonNull(value, fieldName + " must not be null");
        if (value.isBlank()) {
            throw new IllegalArgumentException(fieldName + " must not be blank");
        }
        return value;
    }
}
