package com.etleap.trading.domain.support;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Money is decimal at two places and never a double: binary floating point cannot represent
 * 0.10 exactly, and a balance out by a hundredth of a penny after a thousand trades is a defect
 * an auditor finds before you do.
 */
class MoneyTest {

    @Test
    void normalizesAWholeNumberToTwoDecimalPlaces() {
        assertEquals(new BigDecimal("100.00"), Money.normalize(new BigDecimal("100")));
    }

    @Test
    void normalizesOneDecimalPlaceToTwo() {
        assertEquals(new BigDecimal("10.50"), Money.normalize(new BigDecimal("10.5")));
    }

    @Test
    void leavesTwoDecimalPlacesUnchanged() {
        assertEquals(new BigDecimal("10.55"), Money.normalize(new BigDecimal("10.55")));
    }

    @Test
    void rejectsAThirdDecimalPlaceRatherThanSilentlyRounding() {
        assertThrows(IllegalArgumentException.class, () -> Money.normalize(new BigDecimal("10.005")));
    }

    @Test
    void rejectsNull() {
        assertThrows(NullPointerException.class, () -> Money.normalize(null));
    }
}
