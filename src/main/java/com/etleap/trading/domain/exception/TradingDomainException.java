package com.etleap.trading.domain.exception;

import java.util.Objects;

/**
 * Base type for every failure the trading domain raises deliberately, as opposed to a
 * programming error.
 *
 * <p>It carries a catalogue {@code code} such as {@code ACC-404}, never an HTTP status: Sprint
 * 6 maps that code to a status in exactly one place (a single catch of this base type), and
 * Sprint 7 maps the same code to a rejection reason on a Kafka event. Two callers, one source
 * of truth.
 *
 * <p>{@link #getMessage()} is <em>only</em> ever the fixed catalogue message for the concrete
 * case - it becomes the response body a caller sees, so it never carries account ids, amounts,
 * symbols or keys (that would leak internal detail into an error body, which is OWASP A05).
 * Anything an investigation needs is a typed field on the concrete subtype, meant to be logged
 * server-side, never rendered to the caller.
 */
public abstract class TradingDomainException extends RuntimeException {

    private final String code;

    protected TradingDomainException(String code, String catalogueMessage) {
        super(catalogueMessage);
        this.code = Objects.requireNonNull(code, "code must not be null");
        Objects.requireNonNull(catalogueMessage, "catalogueMessage must not be null");
    }

    public final String getCode() {
        return code;
    }
}
