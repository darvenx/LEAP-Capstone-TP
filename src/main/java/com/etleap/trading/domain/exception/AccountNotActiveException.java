package com.etleap.trading.domain.exception;

import com.etleap.trading.domain.AccountStatus;

import java.util.Objects;

/**
 * Case 2: the account exists and is {@code SUSPENDED} or {@code CLOSED}. Rule 2.
 */
public final class AccountNotActiveException extends TradingDomainException {

    private static final String CODE = "ACC-403";
    private static final String MESSAGE = "Account is not active";

    private final Long accountId;
    private final AccountStatus status;

    public AccountNotActiveException(Long accountId, AccountStatus status) {
        super(CODE, MESSAGE);
        this.accountId = Objects.requireNonNull(accountId, "accountId must not be null");
        this.status = Objects.requireNonNull(status, "status must not be null");
    }

    public Long getAccountId() {
        return accountId;
    }

    /** The account's actual status ({@code SUSPENDED} or {@code CLOSED}). For logging only. */
    public AccountStatus getStatus() {
        return status;
    }
}
