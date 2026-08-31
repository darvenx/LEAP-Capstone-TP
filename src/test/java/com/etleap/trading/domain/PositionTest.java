package com.etleap.trading.domain;

import com.etleap.trading.domain.exception.InsufficientHoldingsException;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Position is the net holding of one instrument in one account, with its average cost, moved
 * by a buy or a sell. The average cost rule is asymmetric: a buy recalculates the average
 * across the old holding and the new units at the price they were bought at; a sell reduces
 * the quantity and leaves the average alone, which is what makes realised profit and loss
 * computable at the point of sale. A position never goes negative.
 */
class PositionTest {

    @Test
    void anEmptyPositionHasZeroQuantityAndZeroAverageCost() {
        Position position = Position.empty(1L, "FXN:ACME");

        assertEquals(0L, position.getQuantity());
        assertEquals(new BigDecimal("0.00"), position.getAverageCost());
    }

    @Test
    void firstBuyIntoAnEmptyPositionSetsQuantityAndAverageCostFromThatBuy() {
        Position position = Position.empty(1L, "FXN:ACME");

        position.applyBuy(10L, new BigDecimal("100.00"));

        assertEquals(10L, position.getQuantity());
        assertEquals(new BigDecimal("100.00"), position.getAverageCost());
    }

    @Test
    void aSecondBuyRecalculatesTheAverageAcrossOldHoldingAndNewUnits() {
        Position position = Position.empty(1L, "FXN:ACME");
        position.applyBuy(10L, new BigDecimal("100.00")); // 1000.00 total

        position.applyBuy(10L, new BigDecimal("200.00")); // +2000.00 total = 3000.00 / 20

        assertEquals(20L, position.getQuantity());
        assertEquals(new BigDecimal("150.00"), position.getAverageCost());
    }

    @Test
    void averageCostRoundsHalfUpToTwoDecimalPlacesWhenItDoesNotDivideEvenly() {
        Position position = Position.empty(1L, "FXN:ACME");
        position.applyBuy(3L, new BigDecimal("10.00")); // 30.00
        position.applyBuy(3L, new BigDecimal("10.01")); // +30.03 = 60.03 / 6 = 10.005

        assertEquals(new BigDecimal("10.01"), position.getAverageCost());
    }

    @Test
    void aSellReducesQuantityButLeavesTheAverageCostAlone() {
        Position position = Position.empty(1L, "FXN:ACME");
        position.applyBuy(10L, new BigDecimal("100.00"));

        position.applySell(4L);

        assertEquals(6L, position.getQuantity());
        assertEquals(new BigDecimal("100.00"), position.getAverageCost(),
                "a sell must not touch the average cost - that is what makes realised P&L computable");
    }

    @Test
    void sellingExactlyTheFullHoldingLeavesQuantityAtZero() {
        Position position = Position.empty(1L, "FXN:ACME");
        position.applyBuy(10L, new BigDecimal("100.00"));

        position.applySell(10L);

        assertEquals(0L, position.getQuantity());
    }

    @Test
    void aPositionNeverGoesNegative() {
        Position position = Position.empty(1L, "FXN:ACME");
        position.applyBuy(5L, new BigDecimal("100.00"));

        InsufficientHoldingsException ex =
                assertThrows(InsufficientHoldingsException.class, () -> position.applySell(6L));

        assertEquals("ORD-409", ex.getCode());
        assertEquals(5L, position.getQuantity(), "the refused sell must not touch the holding");
    }

    @Test
    void applyBuyRejectsAZeroOrNegativeQuantity() {
        Position position = Position.empty(1L, "FXN:ACME");

        assertThrows(IllegalArgumentException.class, () -> position.applyBuy(0L, new BigDecimal("1.00")));
        assertThrows(IllegalArgumentException.class, () -> position.applyBuy(-1L, new BigDecimal("1.00")));
    }

    @Test
    void applySellRejectsAZeroOrNegativeQuantity() {
        Position position = Position.empty(1L, "FXN:ACME");
        position.applyBuy(5L, new BigDecimal("1.00"));

        assertThrows(IllegalArgumentException.class, () -> position.applySell(0L));
        assertThrows(IllegalArgumentException.class, () -> position.applySell(-1L));
    }
}
