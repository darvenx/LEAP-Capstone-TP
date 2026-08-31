package com.etleap.trading.domain.dto;

/**
 * One failed constraint on a {@link PlaceOrderRequest} field: which field, and why. Deliberately
 * not {@code jakarta.validation.ConstraintViolation} - that interface is meant to be produced
 * by a Bean Validation provider's {@code Validator}, and {@link PlaceOrderRequestValidator}
 * checks these constraints by hand instead, precisely so this module does not depend on one
 * being present at runtime.
 */
public record FieldViolation(String field, String message) {
}
