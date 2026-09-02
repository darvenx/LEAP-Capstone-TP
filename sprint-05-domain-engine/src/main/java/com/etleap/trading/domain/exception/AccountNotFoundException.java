package com.etleap.trading.domain.exception;

import java.util.Objects;

/**
 * Case 1: no account exists with the key on the request. Rule 1.
 */
public final class AccountNotFoundException extends TradingDomainException {

    private static final String CODE = "ACC-404";
    private static final String MESSAGE = "Account not found";

    private final Long accountId;

    public AccountNotFoundException(Long accountId) {
        super(CODE, MESSAGE);
        this.accountId = Objects.requireNonNull(accountId, "accountId must not be null");
    }

    /** The numeric account key that was looked up. For server-side logging only. */
    public Long getAccountId() {
        return accountId;
    }
}
