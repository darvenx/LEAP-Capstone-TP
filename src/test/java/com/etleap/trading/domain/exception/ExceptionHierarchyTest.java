package com.etleap.trading.domain.exception;

import com.etleap.trading.domain.AccountStatus;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Six cases, one type each, all extending {@link TradingDomainException} so that the Sprint 6
 * service catches the base type in one place and maps it. The base type carries the catalogue
 * code, never an HTTP status, and the exception message is the catalogue message and nothing
 * else - anything an investigation needs is a typed field on the exception, logged on the
 * server rather than leaked in a response body (OWASP A05).
 */
class ExceptionHierarchyTest {

    @Test
    void allSixCasesDescendFromTheSameDomainBaseType() {
        assertTrue(TradingDomainException.class.isAssignableFrom(AccountNotFoundException.class));
        assertTrue(TradingDomainException.class.isAssignableFrom(AccountNotActiveException.class));
        assertTrue(TradingDomainException.class.isAssignableFrom(InstrumentNotFoundException.class));
        assertTrue(TradingDomainException.class.isAssignableFrom(InsufficientFundsException.class));
        assertTrue(TradingDomainException.class.isAssignableFrom(InsufficientHoldingsException.class));
        assertTrue(TradingDomainException.class.isAssignableFrom(DuplicateOrderException.class));
        // Our documented answer to the rule 4/5 decision: a seventh type, same base.
        assertTrue(TradingDomainException.class.isAssignableFrom(OrderValidationException.class));
    }

    @Test
    void accountNotFoundCarriesAccCode404AndTheAccountIdForInvestigation() {
        AccountNotFoundException ex = new AccountNotFoundException(42L);
        assertEquals("ACC-404", ex.getCode());
        assertEquals("Account not found", ex.getMessage());
        assertEquals(42L, ex.getAccountId());
    }

    @Test
    void accountNotActiveCarriesAccCode403AndTheOffendingStatus() {
        AccountNotActiveException ex = new AccountNotActiveException(7L, AccountStatus.SUSPENDED);
        assertEquals("ACC-403", ex.getCode());
        assertEquals("Account is not active", ex.getMessage());
        assertEquals(7L, ex.getAccountId());
        assertEquals(AccountStatus.SUSPENDED, ex.getStatus());
    }

    @Test
    void instrumentNotFoundCarriesInsCode404AndTheSymbol() {
        InstrumentNotFoundException ex = new InstrumentNotFoundException("XYZ-USD");
        assertEquals("INS-404", ex.getCode());
        assertEquals("XYZ-USD", ex.getSymbol());
    }

    @Test
    void insufficientFundsCarriesOrdCode400AndTheAmounts() {
        InsufficientFundsException ex =
                new InsufficientFundsException(1L, new BigDecimal("150.00"), new BigDecimal("100.00"));
        assertEquals("ORD-400", ex.getCode());
        assertEquals(new BigDecimal("150.00"), ex.getRequired());
        assertEquals(new BigDecimal("100.00"), ex.getAvailable());
    }

    @Test
    void insufficientHoldingsCarriesOrdCode409AndTheQuantities() {
        InsufficientHoldingsException ex = new InsufficientHoldingsException(1L, "XYZ-USD", 50L, 10L);
        assertEquals("ORD-409", ex.getCode());
        assertEquals(50L, ex.getRequested());
        assertEquals(10L, ex.getHeld());
    }

    @Test
    void duplicateOrderCarriesOrdCode409AndTheIdempotencyKey() {
        DuplicateOrderException ex = new DuplicateOrderException("client-key-00001");
        assertEquals("ORD-409", ex.getCode());
        assertEquals("client-key-00001", ex.getIdempotencyKey());
    }

    @Test
    void orderValidationCarriesValCode422AndTheOffendingField() {
        OrderValidationException ex = OrderValidationException.quantityMustBePositive(0L);
        assertEquals("VAL-422", ex.getCode());
        assertEquals("quantity", ex.getField());

        OrderValidationException priceEx = OrderValidationException.priceMustBePositive(BigDecimal.ZERO);
        assertEquals("VAL-422", priceEx.getCode());
        assertEquals("price", priceEx.getField());
    }

    @Test
    void ordCode409IsDeliberatelyReusedByTwoDistinctCases() {
        // README: "One code can mean two things ... and neither is an accident." ORD-409 means
        // insufficient holdings on one type and duplicate order on the other; the case, not the
        // code, is what the caller must switch on.
        InsufficientHoldingsException holdings = new InsufficientHoldingsException(1L, "XYZ-USD", 5L, 1L);
        DuplicateOrderException duplicate = new DuplicateOrderException("k");
        assertEquals(holdings.getCode(), duplicate.getCode());
        assertTrue(!holdings.getClass().equals(duplicate.getClass()));
    }

    @Test
    void messageIsOnlyTheCatalogueMessageNeverInternalDetail() {
        // The message becomes the response body (OWASP A05): it must never embed the typed
        // investigation detail (account id, amounts, keys...).
        InsufficientFundsException ex =
                new InsufficientFundsException(999L, new BigDecimal("5000.00"), new BigDecimal("1.00"));
        assertEquals("Insufficient funds", ex.getMessage());
        assertTrue(!ex.getMessage().contains("999"));
        assertTrue(!ex.getMessage().contains("5000"));
    }
}
