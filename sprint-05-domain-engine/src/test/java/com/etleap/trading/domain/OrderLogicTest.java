package com.etleap.trading.domain;

import com.etleap.trading.domain.dto.PlaceOrderRequest;
import com.etleap.trading.domain.exception.AccountNotActiveException;
import com.etleap.trading.domain.exception.AccountNotFoundException;
import com.etleap.trading.domain.exception.DuplicateOrderException;
import com.etleap.trading.domain.exception.InstrumentNotFoundException;
import com.etleap.trading.domain.exception.InsufficientFundsException;
import com.etleap.trading.domain.exception.InsufficientHoldingsException;
import com.etleap.trading.domain.exception.OrderValidationException;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Business rules 1 to 8, enforced in this order, the first failure wins. Covers each rule
 * firing and each rule not firing (16 minimum per the brief's own arithmetic), plus the
 * evaluation order itself: a request that breaks two rules receives the code of the first, and
 * a suspended account holding no cash gets ACC-403 rather than ORD-400.
 */
class OrderLogicTest {

    private static final Long ACCOUNT_ID = 1L;
    private static final String SYMBOL = "FXN:ACME";

    private Account activeAccount(String balance) {
        return new Account(ACCOUNT_ID, "ACC-REF-0001", "Ada Lovelace", "USD",
                new BigDecimal(balance), AccountStatus.ACTIVE, 0L);
    }

    private Account accountWithStatus(AccountStatus status, String balance) {
        return new Account(ACCOUNT_ID, "ACC-REF-0001", "Ada Lovelace", "USD",
                new BigDecimal(balance), status, 0L);
    }

    private Instrument tradableInstrument() {
        return new Instrument(SYMBOL, "Acme Corp", "EQUITY", "USD", "NYSE");
    }

    private Instrument delistedInstrument() {
        Instrument instrument = tradableInstrument();
        instrument.delist();
        return instrument;
    }

    private PlaceOrderRequest buyRequest(long quantity, String price, String idempotencyKey) {
        return new PlaceOrderRequest(ACCOUNT_ID, SYMBOL, OrderSide.BUY, quantity,
                new BigDecimal(price), idempotencyKey);
    }

    private PlaceOrderRequest sellRequest(long quantity, String price, String idempotencyKey) {
        return new PlaceOrderRequest(ACCOUNT_ID, SYMBOL, OrderSide.SELL, quantity,
                new BigDecimal(price), idempotencyKey);
    }

    private OrderPlacementRules newRules() {
        return new OrderPlacementRules(new InMemoryIdempotencyKeyRegistry());
    }

    // === Rule 1: the account must exist ======================================================

    @Test
    void rule1Fires_whenNoAccountExistsForTheRequest() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000001");

        AccountNotFoundException ex = assertThrows(AccountNotFoundException.class,
                () -> rules.evaluate(request, null, tradableInstrument(), null));

        assertEquals("ACC-404", ex.getCode());
    }

    @Test
    void rule1DoesNotFire_whenTheAccountExists() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000002");

        // Account present: rule 1 passes silently and evaluation reaches rule 2, which then
        // fails on its own terms - proving rule 1 itself did not throw.
        AccountNotActiveException ex = assertThrows(AccountNotActiveException.class,
                () -> rules.evaluate(request, accountWithStatus(AccountStatus.SUSPENDED, "1000.00"),
                        tradableInstrument(), null));
        assertEquals("ACC-403", ex.getCode());
    }

    // === Rule 2: the account must be ACTIVE ==================================================

    @Test
    void rule2Fires_whenTheAccountIsSuspended() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000003");

        AccountNotActiveException ex = assertThrows(AccountNotActiveException.class,
                () -> rules.evaluate(request, accountWithStatus(AccountStatus.SUSPENDED, "1000.00"),
                        tradableInstrument(), null));

        assertEquals("ACC-403", ex.getCode());
        assertEquals(AccountStatus.SUSPENDED, ex.getStatus());
    }

    @Test
    void rule2Fires_whenTheAccountIsClosed() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000004");

        AccountNotActiveException ex = assertThrows(AccountNotActiveException.class,
                () -> rules.evaluate(request, accountWithStatus(AccountStatus.CLOSED, "1000.00"),
                        tradableInstrument(), null));

        assertEquals(AccountStatus.CLOSED, ex.getStatus());
    }

    @Test
    void rule2DoesNotFire_whenTheAccountIsActive() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000005");

        // Active account: rule 2 passes and evaluation reaches rule 3, which fails on its own
        // terms - proving rule 2 itself did not throw.
        InstrumentNotFoundException ex = assertThrows(InstrumentNotFoundException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), null, null));
        assertEquals("INS-404", ex.getCode());
    }

    // === Rule 3: the instrument must exist and be tradable ===================================

    @Test
    void rule3Fires_whenTheInstrumentIsUnknown() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000006");

        InstrumentNotFoundException ex = assertThrows(InstrumentNotFoundException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), null, null));

        assertEquals("INS-404", ex.getCode());
    }

    @Test
    void rule3Fires_whenTheInstrumentIsDelisted() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000007");

        InstrumentNotFoundException ex = assertThrows(InstrumentNotFoundException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), delistedInstrument(), null));

        assertEquals("INS-404", ex.getCode());
    }

    @Test
    void rule3DoesNotFire_whenTheInstrumentIsTradable() {
        OrderPlacementRules rules = newRules();
        // quantity 0 trips rule 4 next, proving rule 3 itself let a tradable instrument through.
        PlaceOrderRequest request = buyRequest(0L, "100.00", "key-0000000008");

        OrderValidationException ex = assertThrows(OrderValidationException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null));
        assertEquals("quantity", ex.getField());
    }

    // === Rule 4: quantity must be greater than zero ==========================================

    @Test
    void rule4Fires_whenQuantityIsZero() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(0L, "100.00", "key-0000000009");

        OrderValidationException ex = assertThrows(OrderValidationException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null));

        assertEquals("VAL-422", ex.getCode());
        assertEquals("quantity", ex.getField());
    }

    @Test
    void rule4Fires_whenQuantityIsNegative() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(-5L, "100.00", "key-0000000010");

        OrderValidationException ex = assertThrows(OrderValidationException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null));

        assertEquals("quantity", ex.getField());
    }

    @Test
    void rule4DoesNotFire_whenQuantityIsExactlyOne() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(1L, "100.00", "key-0000000011");

        Order order = rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null);

        assertEquals(OrderStatus.NEW, order.getStatus());
    }

    // === Rule 5: price must be greater than zero =============================================

    @Test
    void rule5Fires_whenPriceIsZero() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "0.00", "key-0000000012");

        OrderValidationException ex = assertThrows(OrderValidationException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null));

        assertEquals("VAL-422", ex.getCode());
        assertEquals("price", ex.getField());
    }

    @Test
    void rule5DoesNotFire_whenPriceIsExactlyOneCent() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(1L, "0.01", "key-0000000013");

        Order order = rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null);

        assertEquals(OrderStatus.NEW, order.getStatus());
    }

    // === Rule 6: on a BUY, cash balance must be at least quantity * price ====================

    @Test
    void rule6Fires_whenABuyCostsOneCentMoreThanTheAvailableBalance() {
        OrderPlacementRules rules = newRules();
        // 10 * 10.00 = 100.00, balance 99.99
        PlaceOrderRequest request = buyRequest(10L, "10.00", "key-0000000014");

        InsufficientFundsException ex = assertThrows(InsufficientFundsException.class,
                () -> rules.evaluate(request, activeAccount("99.99"), tradableInstrument(), null));

        assertEquals("ORD-400", ex.getCode());
        assertEquals(new BigDecimal("100.00"), ex.getRequired());
        assertEquals(new BigDecimal("99.99"), ex.getAvailable());
    }

    @Test
    void rule6DoesNotFire_whenABuyCostsExactlyTheAvailableBalance() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "10.00", "key-0000000015");

        Order order = rules.evaluate(request, activeAccount("100.00"), tradableInstrument(), null);

        assertEquals(OrderStatus.NEW, order.getStatus());
    }

    @Test
    void rule6DoesNotApply_toASellRegardlessOfCashBalance() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = sellRequest(5L, "10.00", "key-0000000016");
        Position position = Position.of(ACCOUNT_ID, SYMBOL, 5L, new BigDecimal("10.00"));

        // Zero cash balance would fail rule 6 for a BUY; for a SELL it must be irrelevant.
        Order order = rules.evaluate(request, activeAccount("0.00"), tradableInstrument(), position);

        assertEquals(OrderStatus.NEW, order.getStatus());
    }

    // === Rule 7: on a SELL, held quantity must be at least the order quantity ================

    @Test
    void rule7Fires_whenASellExceedsTheHeldQuantity() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = sellRequest(10L, "10.00", "key-0000000017");
        Position position = Position.of(ACCOUNT_ID, SYMBOL, 5L, new BigDecimal("8.00"));

        InsufficientHoldingsException ex = assertThrows(InsufficientHoldingsException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), position));

        assertEquals("ORD-409", ex.getCode());
        assertEquals(10L, ex.getRequested());
        assertEquals(5L, ex.getHeld());
    }

    @Test
    void rule7Fires_whenThereIsNoPositionAtAll() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = sellRequest(1L, "10.00", "key-0000000018");

        InsufficientHoldingsException ex = assertThrows(InsufficientHoldingsException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null));

        assertEquals(0L, ex.getHeld());
    }

    @Test
    void rule7DoesNotFire_whenASellExactlyMatchesTheHeldQuantity() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = sellRequest(5L, "10.00", "key-0000000019");
        Position position = Position.of(ACCOUNT_ID, SYMBOL, 5L, new BigDecimal("8.00"));

        Order order = rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), position);

        assertEquals(OrderStatus.NEW, order.getStatus());
    }

    @Test
    void rule7DoesNotApply_toABuyRegardlessOfPosition() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(5L, "10.00", "key-0000000020");

        // No position at all (null) would fail rule 7 for a SELL; for a BUY it must be irrelevant.
        Order order = rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null);

        assertEquals(OrderStatus.NEW, order.getStatus());
    }

    // === Rule 8: the idempotency key must not already have been used =========================

    @Test
    void rule8Fires_onASecondOrderCarryingTheSameIdempotencyKey() {
        OrderPlacementRules rules = newRules();
        String sharedKey = "key-repeated-000001";
        rules.evaluate(buyRequest(1L, "10.00", sharedKey), activeAccount("1000.00"), tradableInstrument(), null);

        DuplicateOrderException ex = assertThrows(DuplicateOrderException.class,
                () -> rules.evaluate(buyRequest(1L, "10.00", sharedKey), activeAccount("1000.00"),
                        tradableInstrument(), null));

        assertEquals("ORD-409", ex.getCode());
        assertEquals(sharedKey, ex.getIdempotencyKey());
    }

    @Test
    void rule8DoesNotFire_forADifferentIdempotencyKey() {
        OrderPlacementRules rules = newRules();
        rules.evaluate(buyRequest(1L, "10.00", "key-a-0000001"), activeAccount("1000.00"),
                tradableInstrument(), null);

        Order order = rules.evaluate(buyRequest(1L, "10.00", "key-b-0000001"), activeAccount("1000.00"),
                tradableInstrument(), null);

        assertEquals(OrderStatus.NEW, order.getStatus());
    }

    // === Evaluation order itself, not only the eight rules in isolation ======================

    @Test
    void firstFailureWins_quantityBeforePrice_whenBothAreInvalid() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(0L, "0.00", "key-0000000021");

        OrderValidationException ex = assertThrows(OrderValidationException.class,
                () -> rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null));

        assertEquals("quantity", ex.getField(), "rule 4 is evaluated before rule 5");
    }

    @Test
    void firstFailureWins_accountStatusBeforeFunds_suspendedAccountWithNoCashGetsAcc403() {
        OrderPlacementRules rules = newRules();
        // Breaks both rule 2 (suspended) and rule 6 (no cash) at once.
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000022");

        AccountNotActiveException ex = assertThrows(AccountNotActiveException.class,
                () -> rules.evaluate(request, accountWithStatus(AccountStatus.SUSPENDED, "0.00"),
                        tradableInstrument(), null));

        assertEquals("ACC-403", ex.getCode(), "rule 2 (account status) is evaluated before rule 6 (funds)");
    }

    @Test
    void firstFailureWins_accountExistenceBeforeInstrumentExistence() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "100.00", "key-0000000023");

        // Neither the account nor the instrument exists: rule 1 must win, not rule 3.
        AccountNotFoundException ex = assertThrows(AccountNotFoundException.class,
                () -> rules.evaluate(request, null, null, null));

        assertEquals("ACC-404", ex.getCode());
    }

    // === Happy path: all eight rules pass =====================================================

    @Test
    void aFullyValidBuyOrderIsPlacedInNewStatus() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "50.00", "key-0000000024");

        Order order = rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), null);

        assertNotNull(order.getOrderId());
        assertEquals(OrderStatus.NEW, order.getStatus());
        assertEquals(OrderSide.BUY, order.getSide());
        assertEquals(10L, order.getQuantity());
        assertEquals(new BigDecimal("50.00"), order.getLimitPrice());
    }

    @Test
    void aFullyValidSellOrderIsPlacedInNewStatus() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = sellRequest(5L, "50.00", "key-0000000025");
        Position position = Position.of(ACCOUNT_ID, SYMBOL, 5L, new BigDecimal("40.00"));

        Order order = rules.evaluate(request, activeAccount("1000.00"), tradableInstrument(), position);

        assertEquals(OrderStatus.NEW, order.getStatus());
        assertEquals(OrderSide.SELL, order.getSide());
    }

    // === Settlement stays out of evaluate() (ETLEAPCP-1282, and the brief's rules 9/10) =======
    //
    // "cash and position move together or neither moves" is the brief's rule 9, and it is
    // explicitly uncounted and explicitly deferred: "[the order's] executed price is what the
    // Trade Executor achieves against a live quote in Sprint 7 and does not exist until the
    // order is filled." evaluate() only ever accepts a NEW order at the customer's *limit*
    // price - it never calls Account.debit or Position.applyBuy/applySell itself, because the
    // amount actually settled is the Trade Executor's executed price, which this sprint cannot
    // know yet. These two tests are the "buy succeeds and updates cash and position" scenario
    // the ticket names: they prove that once evaluate() accepts an order, the domain's own
    // settlement operations - Account.debit, Position.applyBuy/applySell - compose correctly
    // against the values on that accepted order, so whichever caller settles it (the Trade
    // Executor, in Sprint 7) has everything it needs and nothing left to reimplement.

    @Test
    void aSuccessfulBuyComposesWithAccountDebitAndPositionApplyBuy() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = buyRequest(10L, "50.00", "key-0000000026");
        Account account = activeAccount("1000.00");
        Position position = Position.empty(ACCOUNT_ID, SYMBOL);

        Order order = rules.evaluate(request, account, tradableInstrument(), position);
        assertEquals(OrderStatus.NEW, order.getStatus());

        // evaluate() alone moved nothing yet - the order is accepted, not settled.
        assertEquals(new BigDecimal("1000.00"), account.getCashBalance());
        assertEquals(0L, position.getQuantity());

        // Settlement, once it happens (Sprint 7), uses exactly the values the accepted order
        // carries and the existing entity operations - no new domain behaviour required.
        BigDecimal cost = order.getLimitPrice().multiply(BigDecimal.valueOf(order.getQuantity()));
        account.debit(cost);
        position.applyBuy(order.getQuantity(), order.getLimitPrice());

        assertEquals(new BigDecimal("500.00"), cost);
        assertEquals(new BigDecimal("500.00"), account.getCashBalance());
        assertEquals(10L, position.getQuantity());
        assertEquals(new BigDecimal("50.00"), position.getAverageCost());
    }

    @Test
    void aSuccessfulSellComposesWithPositionApplySellAndAccountCredit() {
        OrderPlacementRules rules = newRules();
        PlaceOrderRequest request = sellRequest(4L, "50.00", "key-0000000027");
        Account account = activeAccount("1000.00");
        Position position = Position.of(ACCOUNT_ID, SYMBOL, 10L, new BigDecimal("40.00"));

        Order order = rules.evaluate(request, account, tradableInstrument(), position);
        assertEquals(OrderStatus.NEW, order.getStatus());

        // Unsettled: the holding and the cash balance are exactly as they were before evaluate().
        assertEquals(10L, position.getQuantity());
        assertEquals(new BigDecimal("1000.00"), account.getCashBalance());

        BigDecimal proceeds = order.getLimitPrice().multiply(BigDecimal.valueOf(order.getQuantity()));
        position.applySell(order.getQuantity());
        account.credit(proceeds);

        assertEquals(6L, position.getQuantity());
        assertEquals(new BigDecimal("40.00"), position.getAverageCost(), "a sell leaves the average cost alone");
        assertEquals(new BigDecimal("1200.00"), account.getCashBalance());
    }
}
