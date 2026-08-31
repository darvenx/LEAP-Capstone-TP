package com.etleap.trading.domain;

import com.etleap.trading.domain.exception.InsufficientFundsException;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Account carries a cash balance in one currency, the holder's name, the trading status, and
 * the only operations that move that balance. It answers whether it can afford an amount.
 *
 * <p>Covers status, debit, credit, affordability, the refusal to go negative, and money that
 * does not drift over many operations - per the Sprint 5 brief, this is the floor this class
 * is named against.
 */
class AccountTest {

    private Account newAccount(AccountStatus status, String balance) {
        return new Account(1L, "ACC-REF-0001", "Ada Lovelace", "USD", new BigDecimal(balance), status, 0L);
    }

    // --- identity and reference data -----------------------------------------------------

    @Test
    void exposesBothIdentifiersDistinctly() {
        Account account = newAccount(AccountStatus.ACTIVE, "100.00");

        // accountId is the numeric key: what the API, the JWT claim and every order mean by
        // accountId. accountReference is the string a support call quotes. Never interchanged.
        assertEquals(1L, account.getAccountId());
        assertEquals("ACC-REF-0001", account.getAccountReference());
    }

    @Test
    void reportsTheVersionItWasLoadedAtWithoutTakingTheLockItself() {
        Account account = new Account(1L, "ACC-REF-0001", "Ada Lovelace", "USD",
                new BigDecimal("100.00"), AccountStatus.ACTIVE, 7L);

        assertEquals(7L, account.getVersion());
        // No mutator for version exists on this type at all - optimistic locking is Sprint 6's
        // job; the domain only ever reports the version it was loaded at.
    }

    // --- status -----------------------------------------------------------------------------

    @Test
    void activeAccountIsActive() {
        assertTrue(newAccount(AccountStatus.ACTIVE, "100.00").isActive());
    }

    @Test
    void suspendedAccountIsNotActive() {
        assertFalse(newAccount(AccountStatus.SUSPENDED, "100.00").isActive());
    }

    @Test
    void closedAccountIsNotActive() {
        assertFalse(newAccount(AccountStatus.CLOSED, "100.00").isActive());
    }

    // --- affordability ------------------------------------------------------------------------

    @Test
    void canAffordAnAmountStrictlyBelowTheBalance() {
        assertTrue(newAccount(AccountStatus.ACTIVE, "100.00").canAfford(new BigDecimal("50.00")));
    }

    @Test
    void canAffordAnAmountExactlyEqualToTheBalance() {
        assertTrue(newAccount(AccountStatus.ACTIVE, "100.00").canAfford(new BigDecimal("100.00")));
    }

    @Test
    void cannotAffordAnAmountOneCentAboveTheBalance() {
        assertFalse(newAccount(AccountStatus.ACTIVE, "100.00").canAfford(new BigDecimal("100.01")));
    }

    // --- debit: refuses to go negative, before subtracting anything -------------------------

    @Test
    void debitReducesTheBalanceByExactlyTheAmount() {
        Account account = newAccount(AccountStatus.ACTIVE, "100.00");

        account.debit(new BigDecimal("30.00"));

        assertEquals(new BigDecimal("70.00"), account.getCashBalance());
    }

    @Test
    void debitOfExactlyTheFullBalanceLeavesItAtZero() {
        Account account = newAccount(AccountStatus.ACTIVE, "100.00");

        account.debit(new BigDecimal("100.00"));

        assertEquals(new BigDecimal("0.00"), account.getCashBalance());
    }

    @Test
    void debitThatWouldLeaveTheBalanceNegativeIsRefusedBeforeAnythingIsSubtracted() {
        Account account = newAccount(AccountStatus.ACTIVE, "100.00");

        InsufficientFundsException ex = assertThrows(InsufficientFundsException.class,
                () -> account.debit(new BigDecimal("100.01")));

        assertEquals("ORD-400", ex.getCode());
        assertEquals(new BigDecimal("100.00"), account.getCashBalance(),
                "balance must be untouched: the check happens before any subtraction, not after");
    }

    @Test
    void debitRejectsAZeroOrNegativeAmount() {
        Account account = newAccount(AccountStatus.ACTIVE, "100.00");

        assertThrows(IllegalArgumentException.class, () -> account.debit(BigDecimal.ZERO));
        assertThrows(IllegalArgumentException.class, () -> account.debit(new BigDecimal("-1.00")));
    }

    // --- credit -------------------------------------------------------------------------------

    @Test
    void creditIncreasesTheBalanceByExactlyTheAmount() {
        Account account = newAccount(AccountStatus.ACTIVE, "100.00");

        account.credit(new BigDecimal("25.50"));

        assertEquals(new BigDecimal("125.50"), account.getCashBalance());
    }

    @Test
    void creditRejectsAZeroOrNegativeAmount() {
        Account account = newAccount(AccountStatus.ACTIVE, "100.00");

        assertThrows(IllegalArgumentException.class, () -> account.credit(BigDecimal.ZERO));
        assertThrows(IllegalArgumentException.class, () -> account.credit(new BigDecimal("-0.01")));
    }

    // --- precision: BigDecimal, never a double -------------------------------------------------

    @Test
    void moneyDoesNotDriftOverManyOperations() {
        // A classic double would accumulate rounding error over 1000 additions of 0.10; a
        // hundredth-of-a-penny defect an auditor finds before you do. BigDecimal must not.
        Account account = newAccount(AccountStatus.ACTIVE, "0.00");

        for (int i = 0; i < 1000; i++) {
            account.credit(new BigDecimal("0.10"));
        }

        assertEquals(new BigDecimal("100.00"), account.getCashBalance());
    }

    @Test
    void balanceIsAlwaysStoredAtExactlyTwoDecimalPlaces() {
        Account account = newAccount(AccountStatus.ACTIVE, "100"); // constructed with scale 0

        assertEquals(new BigDecimal("100.00"), account.getCashBalance());
    }

    @Test
    void rejectsAnOpeningBalanceWithAThirdDecimalPlace() {
        assertThrows(IllegalArgumentException.class,
                () -> new Account(1L, "ACC-REF-0001", "Ada Lovelace", "USD",
                        new BigDecimal("100.001"), AccountStatus.ACTIVE, 0L));
    }

    // --- required fields ------------------------------------------------------------------------

    @Test
    void rejectsABlankAccountReference() {
        assertThrows(IllegalArgumentException.class,
                () -> new Account(1L, "   ", "Ada Lovelace", "USD",
                        new BigDecimal("100.00"), AccountStatus.ACTIVE, 0L));
    }

    @Test
    void rejectsANullStatus() {
        assertThrows(NullPointerException.class,
                () -> new Account(1L, "ACC-REF-0001", "Ada Lovelace", "USD",
                        new BigDecimal("100.00"), null, 0L));
    }
}
