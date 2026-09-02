package com.etleap.trading.domain.exception;

import java.math.BigDecimal;
import java.util.Objects;

/**
 * Case 4: a buy costs more than the available cash balance. Rule 6.
 */
public final class InsufficientFundsException extends TradingDomainException {

    private static final String CODE = "ORD-400";
    private static final String MESSAGE = "Insufficient funds";

    private final Long accountId;
    private final BigDecimal required;
    private final BigDecimal available;

    public InsufficientFundsException(Long accountId, BigDecimal required, BigDecimal available) {
        super(CODE, MESSAGE);
        this.accountId = Objects.requireNonNull(accountId, "accountId must not be null");
        this.required = Objects.requireNonNull(required, "required must not be null");
        this.available = Objects.requireNonNull(available, "available must not be null");
    }

    public Long getAccountId() {
        return accountId;
    }

    /** What the order would have cost. For logging only. */
    public BigDecimal getRequired() {
        return required;
    }

    /** The cash balance actually available at the time. For logging only. */
    public BigDecimal getAvailable() {
        return available;
    }
}
