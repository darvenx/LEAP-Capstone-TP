package com.etleap.trading.domain;

import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * AccountStatus, OrderSide and OrderStatus appear in contracts/trade-api.yaml, the database
 * stores the same strings, and Sprint 9 generates its Angular types from that file - so a
 * renamed or extra literal breaks three places at once. These tests pin the literal set,
 * exactly and in order, rather than merely checking a handful of expected values are present.
 */
class DomainEnumerationsTest {

    @Test
    void accountStatusHoldsExactlyTheContractualLiterals() {
        assertExactLiterals(AccountStatus.class, "ACTIVE", "SUSPENDED", "CLOSED");
    }

    @Test
    void orderSideHoldsExactlyTheContractualLiterals() {
        assertExactLiterals(OrderSide.class, "BUY", "SELL");
    }

    @Test
    void orderStatusHoldsExactlyTheContractualLiterals() {
        // NEW is the working state; the other three are terminal. There is deliberately no
        // partial-fill literal - the Trade Executor fills an order in full or rejects it.
        assertExactLiterals(OrderStatus.class, "NEW", "FILLED", "REJECTED", "CANCELLED");
    }

    @Test
    void cancelledIsSpeltWithTwoLs() {
        assertEquals("CANCELLED", OrderStatus.valueOf("CANCELLED").name());
    }

    private static <E extends Enum<E>> void assertExactLiterals(Class<E> enumType, String... expectedInOrder) {
        List<String> actual = Arrays.stream(enumType.getEnumConstants())
                .map(Enum::name)
                .collect(Collectors.toList());
        assertEquals(Arrays.asList(expectedInOrder), actual,
                () -> enumType.getSimpleName() + " must hold exactly the contractual literals, no more and no fewer");
    }
}
