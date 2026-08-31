package com.etleap.trading.domain.exception;

import java.util.Objects;

/**
 * Case 6: the idempotency key has already been accepted. Rule 8.
 *
 * <p>Shares its catalogue code, {@code ORD-409}, with {@link InsufficientHoldingsException}.
 * README: "One code can mean two things ... and neither is an accident." A caller that only
 * switches on the HTTP status Sprint 6 derives from {@code ORD-409} sees "conflict" either
 * way, which is honest: both cases mean "this request conflicts with the current state of the
 * account or its orders." A caller that needs to tell them apart switches on the exception's
 * concrete case (its Java type / the discriminator Sprint 6 puts in the body), not on the code.
 */
public final class DuplicateOrderException extends TradingDomainException {

    private static final String CODE = "ORD-409";
    private static final String MESSAGE = "Duplicate order";

    private final String idempotencyKey;

    public DuplicateOrderException(String idempotencyKey) {
        super(CODE, MESSAGE);
        this.idempotencyKey = Objects.requireNonNull(idempotencyKey, "idempotencyKey must not be null");
    }

    /** The key that was already registered. For logging only. */
    public String getIdempotencyKey() {
        return idempotencyKey;
    }
}
