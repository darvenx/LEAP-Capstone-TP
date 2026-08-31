package com.etleap.trading.domain;

/**
 * The seam rule 8 is evaluated through: whether an idempotency key has already been accepted.
 *
 * <p>Rule 8 needs a design decision. In Sprint 6 the real authority is the unique constraint
 * on {@code orders.idempotency_key} built in Sprint 3 - not a read followed by a write,
 * because two concurrent requests carrying the same key would both pass a read-then-write
 * check, and duplicate a trade. {@link #register(String)} mirrors that unique-constraint
 * semantics exactly: it is one atomic operation that both checks and claims the key, so the
 * rule is expressible and testable here, without a database. A persistence-backed
 * implementation (Sprint 6) only has to make its {@code INSERT} do the same thing the unique
 * constraint already guarantees - reporting a constraint violation as {@code false}, not by
 * pre-checking with a {@code SELECT}.
 */
public interface IdempotencyKeyRegistry {

    /**
     * Atomically registers {@code idempotencyKey} as used.
     *
     * @return {@code true} if this call is the first to register the key, {@code false} if it
     *         was already registered - by this call or a concurrent one
     */
    boolean register(String idempotencyKey);
}
