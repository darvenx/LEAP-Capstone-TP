package com.etleap.trading.domain.dto;

import com.etleap.trading.domain.OrderSide;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * PlaceOrderRequest is {@code PlaceOrderRequest} in {@code contracts/trade-api.yaml} and is
 * binding. Six fields, each a business constraint enforced and tested here - including the
 * boundary either side of every limit - so that a second caller (the Trade Executor replaying
 * an order in Sprint 7) gets them without reimplementing them. Validated by hand rather than
 * by relying on a Bean Validation provider being present at runtime, which the brief
 * explicitly permits; the jakarta.validation annotations on {@link PlaceOrderRequest} document
 * the same constraints for any Validator Sprint 6 chooses to wire up.
 */
class PlaceOrderRequestValidationTest {

    private static PlaceOrderRequest valid() {
        return new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
    }

    private static Set<String> fieldsViolatedBy(PlaceOrderRequest request) {
        return PlaceOrderRequestValidator.validate(request).stream()
                .map(FieldViolation::field)
                .collect(Collectors.toSet());
    }

    @Test
    void aFullyValidRequestHasNoViolations() {
        assertTrue(PlaceOrderRequestValidator.validate(valid()).isEmpty());
    }

    // --- accountId: required, the numeric account key, at least 1 --------------------------

    @Test
    void accountIdMustNotBeNull() {
        PlaceOrderRequest request = new PlaceOrderRequest(null, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("accountId"), fieldsViolatedBy(request));
    }

    @Test
    void accountIdBelowOneIsAViolation() {
        PlaceOrderRequest request = new PlaceOrderRequest(0L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("accountId"), fieldsViolatedBy(request));
    }

    @Test
    void accountIdOfExactlyOneIsValid() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertTrue(fieldsViolatedBy(request).isEmpty());
    }

    // --- symbol: required, not blank, at most 20 characters ---------------------------------

    @Test
    void symbolMustNotBeNull() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, null, OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("symbol"), fieldsViolatedBy(request));
    }

    @Test
    void symbolMustNotBeBlank() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "   ", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("symbol"), fieldsViolatedBy(request));
    }

    @Test
    void symbolOfExactlyTwentyCharactersIsValid() {
        String twentyChars = "A".repeat(20);
        PlaceOrderRequest request = new PlaceOrderRequest(1L, twentyChars, OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertTrue(fieldsViolatedBy(request).isEmpty());
    }

    @Test
    void symbolOfTwentyOneCharactersIsAViolation() {
        String twentyOneChars = "A".repeat(21);
        PlaceOrderRequest request = new PlaceOrderRequest(1L, twentyOneChars, OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("symbol"), fieldsViolatedBy(request));
    }

    // --- side: required, one of BUY or SELL --------------------------------------------------

    @Test
    void sideMustNotBeNull() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", null, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("side"), fieldsViolatedBy(request));
    }

    @Test
    void bothSidesAreIndividuallyValid() {
        PlaceOrderRequest buy = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        PlaceOrderRequest sell = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.SELL, 10L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertTrue(fieldsViolatedBy(buy).isEmpty());
        assertTrue(fieldsViolatedBy(sell).isEmpty());
    }

    // --- quantity: required, whole units, greater than zero ---------------------------------

    @Test
    void quantityMustNotBeNull() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, null,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("quantity"), fieldsViolatedBy(request));
    }

    @Test
    void quantityOfZeroIsAViolation() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 0L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("quantity"), fieldsViolatedBy(request));
    }

    @Test
    void negativeQuantityIsAViolation() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, -1L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertEquals(Set.of("quantity"), fieldsViolatedBy(request));
    }

    @Test
    void quantityOfExactlyOneIsValid() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 1L,
                new BigDecimal("100.00"), "idem-key-00000001");
        assertTrue(fieldsViolatedBy(request).isEmpty());
    }

    // --- price: required, greater than zero, at most two decimal places ---------------------

    @Test
    void priceMustNotBeNull() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                null, "idem-key-00000001");
        assertEquals(Set.of("price"), fieldsViolatedBy(request));
    }

    @Test
    void priceOfZeroIsAViolation() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("0.00"), "idem-key-00000001");
        assertEquals(Set.of("price"), fieldsViolatedBy(request));
    }

    @Test
    void negativePriceIsAViolation() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("-0.01"), "idem-key-00000001");
        assertEquals(Set.of("price"), fieldsViolatedBy(request));
    }

    @Test
    void priceOfExactlyOneCentIsValid() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("0.01"), "idem-key-00000001");
        assertTrue(fieldsViolatedBy(request).isEmpty());
    }

    @Test
    void priceWithThreeDecimalPlacesIsAViolation() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.001"), "idem-key-00000001");
        assertEquals(Set.of("price"), fieldsViolatedBy(request));
    }

    @Test
    void priceWithExactlyTwoDecimalPlacesIsValid() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("99.99"), "idem-key-00000001");
        assertTrue(fieldsViolatedBy(request).isEmpty());
    }

    // --- idempotencyKey: required, between 8 and 100 characters -----------------------------

    @Test
    void idempotencyKeyMustNotBeNull() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), null);
        assertEquals(Set.of("idempotencyKey"), fieldsViolatedBy(request));
    }

    @Test
    void idempotencyKeyOfSevenCharactersIsAViolation() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "1234567");
        assertEquals(Set.of("idempotencyKey"), fieldsViolatedBy(request));
    }

    @Test
    void idempotencyKeyOfExactlyEightCharactersIsValid() {
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), "12345678");
        assertTrue(fieldsViolatedBy(request).isEmpty());
    }

    @Test
    void idempotencyKeyOfExactlyOneHundredCharactersIsValid() {
        String hundredChars = "k".repeat(100);
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), hundredChars);
        assertTrue(fieldsViolatedBy(request).isEmpty());
    }

    @Test
    void idempotencyKeyOfOneHundredAndOneCharactersIsAViolation() {
        String tooLong = "k".repeat(101);
        PlaceOrderRequest request = new PlaceOrderRequest(1L, "FXN:ACME", OrderSide.BUY, 10L,
                new BigDecimal("100.00"), tooLong);
        assertEquals(Set.of("idempotencyKey"), fieldsViolatedBy(request));
    }

    // --- multiple violations at once ---------------------------------------------------------

    @Test
    void multipleViolationsAreAllReportedTogether() {
        PlaceOrderRequest request = new PlaceOrderRequest(0L, "", null, 0L,
                BigDecimal.ZERO, "short");
        List<FieldViolation> violations = PlaceOrderRequestValidator.validate(request);
        assertEquals(Set.of("accountId", "symbol", "side", "quantity", "price", "idempotencyKey"),
                violations.stream().map(FieldViolation::field).collect(Collectors.toSet()));
    }
}
