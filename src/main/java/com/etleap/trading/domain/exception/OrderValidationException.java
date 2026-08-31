package com.etleap.trading.domain.exception;

import java.math.BigDecimal;
import java.util.Objects;

/**
 * Our answer to the design question the brief poses for rules 4 and 5: the six specified cases
 * have no member for "quantity or price out of range," and {@code VAL-422} is a documented
 * outcome of order placement in {@code contracts/trade-api.yaml}. We add this seventh type
 * rather than relying on validation-alone, for one reason: {@link com.etleap.trading.domain.OrderPlacementRules}
 * is the authority the Trade Executor calls directly when it replays an order in Sprint 7,
 * and a replayed order never passed through a {@code jakarta.validation} Validator (there is
 * no HTTP request, no DTO binding, no controller). If quantity-or-price-out-of-range were only
 * a {@code jakarta.validation} annotation, that replay path would have no way to enforce rules
 * 4 and 5 at all. Making it a domain exception, thrown by the same rule evaluator that runs the
 * other six checks, means every caller - the HTTP controller in Sprint 6 and the Trade
 * Executor in Sprint 7 alike - gets rules 4 and 5 enforced identically, for the same reason
 * business rules live in the domain rather than in a controller.
 *
 * <p>Extends the same {@link TradingDomainException} base as the six specified cases, so
 * Sprint 6 still catches one base type in one place. It carries {@code VAL-422} for both
 * rules; the offending field name is the typed detail, not the message.
 */
public final class OrderValidationException extends TradingDomainException {

    private static final String CODE = "VAL-422";
    private static final String MESSAGE = "Order validation failed";

    private final String field;

    private OrderValidationException(String field) {
        super(CODE, MESSAGE);
        this.field = Objects.requireNonNull(field, "field must not be null");
    }

    /** Rule 4: quantity must be a whole number greater than zero. */
    public static OrderValidationException quantityMustBePositive(Long quantity) {
        return new OrderValidationException("quantity");
    }

    /** Rule 5: price must be greater than zero, at most two decimal places. */
    public static OrderValidationException priceMustBePositive(BigDecimal price) {
        return new OrderValidationException("price");
    }

    /** Which field on the request failed validation. For logging only. */
    public String getField() {
        return field;
    }
}
