package com.etleap.trading.domain;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * An order is recorded when it is received, before anyone knows whether it will succeed, and
 * reaches exactly one terminal state, with a disallowed transition refused by the order itself
 * rather than by its caller.
 */
class OrderTest {

    private Order newOrder() {
        return Order.receive(1L, "FXN:ACME", OrderSide.BUY, 10L, new BigDecimal("100.00"), "idem-key-00000001");
    }

    @Test
    void receivingAnOrderRecordsItInTheWorkingStateBeforeAnyRuleHasRun() {
        Order order = newOrder();

        assertEquals(OrderStatus.NEW, order.getStatus());
        assertFalse(order.isTerminal());
        assertNull(order.getExecutedPrice(), "no execution has happened yet");
    }

    @Test
    void receivingAnOrderRecordsEveryFieldOfTheRequestVerbatim() {
        Order order = newOrder();

        assertEquals(1L, order.getAccountId());
        assertEquals("FXN:ACME", order.getSymbol());
        assertEquals(OrderSide.BUY, order.getSide());
        assertEquals(10L, order.getQuantity());
        assertEquals(new BigDecimal("100.00"), order.getLimitPrice());
        assertEquals("idem-key-00000001", order.getIdempotencyKey());
        assertNotEquals(null, order.getOrderId());
        assertNotEquals(null, order.getReceivedAt());
    }

    @Test
    void twoReceivedOrdersHaveDistinctIds() {
        Order first = newOrder();
        Order second = newOrder();

        assertNotEquals(first.getOrderId(), second.getOrderId());
    }

    @Test
    void fillingAnOrderTransitionsToFilledAndRecordsTheExecutedPrice() {
        Order order = newOrder();

        order.fill(new BigDecimal("101.25"));

        assertEquals(OrderStatus.FILLED, order.getStatus());
        assertEquals(new BigDecimal("101.25"), order.getExecutedPrice());
        assertTrue(order.isTerminal());
    }

    @Test
    void rejectingAnOrderTransitionsToRejected() {
        Order order = newOrder();

        order.reject();

        assertEquals(OrderStatus.REJECTED, order.getStatus());
        assertTrue(order.isTerminal());
    }

    @Test
    void cancellingAnOrderTransitionsToCancelled() {
        Order order = newOrder();

        order.cancel();

        assertEquals(OrderStatus.CANCELLED, order.getStatus());
        assertTrue(order.isTerminal());
    }

    @Test
    void aFilledOrderRefusesToBeFilledAgain() {
        Order order = newOrder();
        order.fill(new BigDecimal("100.00"));

        assertThrows(IllegalStateException.class, () -> order.fill(new BigDecimal("200.00")));
    }

    @Test
    void aFilledOrderRefusesToBeRejected() {
        Order order = newOrder();
        order.fill(new BigDecimal("100.00"));

        assertThrows(IllegalStateException.class, order::reject);
    }

    @Test
    void aRejectedOrderRefusesToBeFilledOrCancelled() {
        Order order = newOrder();
        order.reject();

        assertThrows(IllegalStateException.class, () -> order.fill(new BigDecimal("100.00")));
        assertThrows(IllegalStateException.class, order::cancel);
    }

    @Test
    void aCancelledOrderRefusesEveryFurtherTransition() {
        Order order = newOrder();
        order.cancel();

        assertThrows(IllegalStateException.class, () -> order.fill(new BigDecimal("100.00")));
        assertThrows(IllegalStateException.class, order::reject);
        assertThrows(IllegalStateException.class, order::cancel);
    }
}
