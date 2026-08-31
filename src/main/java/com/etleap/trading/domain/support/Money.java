package com.etleap.trading.domain.support;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Objects;

/**
 * Money is decimal at two places and never a {@code double}: binary floating point cannot
 * represent 0.10 exactly, and a balance out by a hundredth of a penny after a thousand trades
 * is a defect an auditor finds before you do.
 *
 * <p>This is a normalization helper, not a value type of its own - Account, Order and
 * Position each store plain {@link BigDecimal} amounts, always passed through
 * {@link #normalize(BigDecimal)} first so a stray third decimal place is refused rather than
 * silently rounded away.
 */
public final class Money {

    private Money() {
    }

    /**
     * Returns {@code value} scaled to exactly two decimal places, padding with zeros if it has
     * fewer. Throws if {@code value} carries a third decimal place - that is a caller error
     * (an upstream amount was never validated), not something to round silently.
     */
    public static BigDecimal normalize(BigDecimal value) {
        Objects.requireNonNull(value, "amount must not be null");
        try {
            return value.setScale(2, RoundingMode.UNNECESSARY);
        } catch (ArithmeticException ex) {
            throw new IllegalArgumentException(
                    "amount must have at most two decimal places, got: " + value, ex);
        }
    }
}
