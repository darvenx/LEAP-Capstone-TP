package com.etleap.trading.domain;

/**
 * The lifecycle state of an {@link Order}.
 *
 * <p>{@code NEW} is the working state; the other three are terminal. There is deliberately
 * no partial-fill literal, which is why the Trade Executor (Sprint 7) fills an order in full
 * or rejects it. Fixed by contract - see {@link AccountStatus} for why this enum is not
 * renamed or extended casually. Spelt with two Ls: {@code CANCELLED}.
 */
public enum OrderStatus {

    /** Received, not yet resolved. The only non-terminal state. */
    NEW,

    /** Terminal: settled in full at an executed price. */
    FILLED,

    /** Terminal: a business rule refused the order before it ever traded. */
    REJECTED,

    /** Terminal: withdrawn before it filled. */
    CANCELLED
}
