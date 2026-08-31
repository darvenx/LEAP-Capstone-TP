package com.etleap.trading.domain;

/**
 * Whether an {@link Order} buys or sells its instrument.
 *
 * <p>Fixed by contract - see {@link AccountStatus} for why this enum is not renamed or
 * extended casually.
 */
public enum OrderSide {
    BUY,
    SELL
}
