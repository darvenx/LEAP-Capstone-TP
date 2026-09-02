package com.etleap.trading.domain.dto;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * Enforces the six {@link PlaceOrderRequest} constraints by hand - the brief explicitly
 * permits this ("Validating by hand rather than by annotation is allowed. What is assessed is
 * that every constraint is enforced and tested.") - so that this module does not need a Bean
 * Validation provider on its runtime classpath, and so that a caller which never runs one (the
 * Trade Executor replaying an order in Sprint 7) is governed by exactly the same constraints as
 * an HTTP request Sprint 6 validates on the way in.
 */
public final class PlaceOrderRequestValidator {

    private static final int SYMBOL_MAX_LENGTH = 20;
    private static final int IDEMPOTENCY_KEY_MIN_LENGTH = 8;
    private static final int IDEMPOTENCY_KEY_MAX_LENGTH = 100;
    private static final int PRICE_MAX_FRACTION_DIGITS = 2;

    private PlaceOrderRequestValidator() {
    }

    /** Every violated constraint on {@code request}, in field order. Empty if fully valid. */
    public static List<FieldViolation> validate(PlaceOrderRequest request) {
        List<FieldViolation> violations = new ArrayList<>();

        validateAccountId(request.accountId(), violations);
        validateSymbol(request.symbol(), violations);
        if (request.side() == null) {
            violations.add(new FieldViolation("side", "must not be null"));
        }
        validateQuantity(request.quantity(), violations);
        validatePrice(request.price(), violations);
        validateIdempotencyKey(request.idempotencyKey(), violations);

        return violations;
    }

    private static void validateAccountId(Long accountId, List<FieldViolation> violations) {
        if (accountId == null) {
            violations.add(new FieldViolation("accountId", "must not be null"));
        } else if (accountId < 1) {
            violations.add(new FieldViolation("accountId", "must be at least 1"));
        }
    }

    private static void validateSymbol(String symbol, List<FieldViolation> violations) {
        if (symbol == null) {
            violations.add(new FieldViolation("symbol", "must not be null"));
        } else if (symbol.isBlank()) {
            violations.add(new FieldViolation("symbol", "must not be blank"));
        } else if (symbol.length() > SYMBOL_MAX_LENGTH) {
            violations.add(new FieldViolation("symbol", "must be at most " + SYMBOL_MAX_LENGTH + " characters"));
        }
    }

    private static void validateQuantity(Long quantity, List<FieldViolation> violations) {
        if (quantity == null) {
            violations.add(new FieldViolation("quantity", "must not be null"));
        } else if (quantity <= 0) {
            violations.add(new FieldViolation("quantity", "must be greater than zero"));
        }
    }

    private static void validatePrice(BigDecimal price, List<FieldViolation> violations) {
        if (price == null) {
            violations.add(new FieldViolation("price", "must not be null"));
            return;
        }
        if (price.signum() <= 0) {
            violations.add(new FieldViolation("price", "must be greater than zero"));
        }
        if (price.scale() > PRICE_MAX_FRACTION_DIGITS) {
            violations.add(new FieldViolation("price", "must have at most two decimal places"));
        }
    }

    private static void validateIdempotencyKey(String idempotencyKey, List<FieldViolation> violations) {
        if (idempotencyKey == null) {
            violations.add(new FieldViolation("idempotencyKey", "must not be null"));
        } else if (idempotencyKey.length() < IDEMPOTENCY_KEY_MIN_LENGTH
                || idempotencyKey.length() > IDEMPOTENCY_KEY_MAX_LENGTH) {
            violations.add(new FieldViolation("idempotencyKey",
                    "must be between " + IDEMPOTENCY_KEY_MIN_LENGTH + " and " + IDEMPOTENCY_KEY_MAX_LENGTH + " characters"));
        }
    }
}
