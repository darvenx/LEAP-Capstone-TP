package com.etleap.trading.domain.exception;

import java.util.Objects;

/**
 * Case 5: a sell is larger than the quantity held. Rule 7.
 *
 * <p>Shares its catalogue code, {@code ORD-409}, with {@link DuplicateOrderException} - see
 * that type's Javadoc for why the sharing is deliberate.
 */
public final class InsufficientHoldingsException extends TradingDomainException {

    private static final String CODE = "ORD-409";
    private static final String MESSAGE = "Insufficient holdings";

    private final Long accountId;
    private final String symbol;
    private final long requested;
    private final long held;

    public InsufficientHoldingsException(Long accountId, String symbol, long requested, long held) {
        super(CODE, MESSAGE);
        this.accountId = Objects.requireNonNull(accountId, "accountId must not be null");
        this.symbol = Objects.requireNonNull(symbol, "symbol must not be null");
        this.requested = requested;
        this.held = held;
    }

    public Long getAccountId() {
        return accountId;
    }

    public String getSymbol() {
        return symbol;
    }

    /** The quantity the order asked to sell. For logging only. */
    public long getRequested() {
        return requested;
    }

    /** The quantity actually held at the time. For logging only. */
    public long getHeld() {
        return held;
    }
}
