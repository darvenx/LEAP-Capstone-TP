package com.etleap.trading.domain;

import com.etleap.trading.domain.exception.InsufficientFundsException;
import com.etleap.trading.domain.support.Money;

import java.math.BigDecimal;
import java.util.Objects;

/**
 * A trading account: a cash balance in one currency, the holder's name, the trading status,
 * and the only operations that move that balance. Answers whether it can afford an amount.
 *
 * <p>Carries two identifiers, kept distinct on purpose: {@link #getAccountId()} is the numeric
 * key - what {@code accountId} means on every order, in the JWT claim, and in
 * {@code contracts/trade-api.yaml} - while {@link #getAccountReference()} is the string a
 * support call quotes. They are never interchanged.
 *
 * <p>Also carries the optimistic-locking {@link #getVersion()} it was loaded at. This class
 * only ever reports that version; it does not take the lock itself, because compare-and-swap
 * against a persisted row is Sprint 6's job, not the domain's.
 *
 * <p>Money is {@link BigDecimal}, normalized to exactly two decimal places by
 * {@link Money#normalize(BigDecimal)}, and never a {@code double}. A debit that would leave the
 * balance negative is refused by {@link #canAfford(BigDecimal)} <em>before</em> anything is
 * subtracted - {@link #debit(BigDecimal)} checks first, then mutates, never the other way
 * around.
 */
public final class Account {

    private final Long accountId;
    private final String accountReference;
    private final String holderName;
    private final String currency;
    private final long version;

    private AccountStatus status;
    private BigDecimal cashBalance;

    public Account(Long accountId, String accountReference, String holderName, String currency,
                    BigDecimal cashBalance, AccountStatus status, long version) {
        this.accountId = Objects.requireNonNull(accountId, "accountId must not be null");
        this.accountReference = requireNonBlank(accountReference, "accountReference");
        this.holderName = requireNonBlank(holderName, "holderName");
        this.currency = requireNonBlank(currency, "currency");
        this.cashBalance = Money.normalize(Objects.requireNonNull(cashBalance, "cashBalance must not be null"));
        this.status = Objects.requireNonNull(status, "status must not be null");
        this.version = version;
    }

    /** Rule 2: only an ACTIVE account may trade. */
    public boolean isActive() {
        return status == AccountStatus.ACTIVE;
    }

    /** Whether the account could pay {@code amount} without its balance going negative. */
    public boolean canAfford(BigDecimal amount) {
        BigDecimal normalized = Money.normalize(requirePositive(amount));
        return cashBalance.compareTo(normalized) >= 0;
    }

    /**
     * Moves {@code amount} out of the account. Refuses - without touching the balance - if
     * that would leave it negative, rather than subtracting and inspecting the result
     * afterwards.
     *
     * @throws InsufficientFundsException if the account cannot afford {@code amount}
     */
    public void debit(BigDecimal amount) {
        BigDecimal normalized = Money.normalize(requirePositive(amount));
        if (cashBalance.compareTo(normalized) < 0) {
            throw new InsufficientFundsException(accountId, normalized, cashBalance);
        }
        cashBalance = cashBalance.subtract(normalized);
    }

    /** Moves {@code amount} into the account. */
    public void credit(BigDecimal amount) {
        BigDecimal normalized = Money.normalize(requirePositive(amount));
        cashBalance = cashBalance.add(normalized);
    }

    public Long getAccountId() {
        return accountId;
    }

    public String getAccountReference() {
        return accountReference;
    }

    public String getHolderName() {
        return holderName;
    }

    public String getCurrency() {
        return currency;
    }

    public AccountStatus getStatus() {
        return status;
    }

    public BigDecimal getCashBalance() {
        return cashBalance;
    }

    /** The optimistic-locking version this account was loaded at. Reported, never taken. */
    public long getVersion() {
        return version;
    }

    private static BigDecimal requirePositive(BigDecimal amount) {
        Objects.requireNonNull(amount, "amount must not be null");
        if (amount.signum() <= 0) {
            throw new IllegalArgumentException("amount must be greater than zero, got: " + amount);
        }
        return amount;
    }

    private static String requireNonBlank(String value, String fieldName) {
        Objects.requireNonNull(value, fieldName + " must not be null");
        if (value.isBlank()) {
            throw new IllegalArgumentException(fieldName + " must not be blank");
        }
        return value;
    }
}
