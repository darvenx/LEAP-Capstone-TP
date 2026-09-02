package com.etleap.trading.domain;

/**
 * The trading status of an {@link Account}.
 *
 * <p>These three literals are fixed by contract: they appear verbatim in
 * {@code contracts/trade-api.yaml}, the database stores the same strings, and Sprint 9
 * generates its Angular types from that file. Renaming or extending this enum breaks all
 * three places at once, so it holds exactly {@code ACTIVE}, {@code SUSPENDED} and
 * {@code CLOSED} - no more and no fewer.
 */
public enum AccountStatus {

    /** The account trades. */
    ACTIVE,

    /** The account can be read and cannot trade. Suspension is reversible. */
    SUSPENDED,

    /** The account never trades again. A closed account is never deleted. */
    CLOSED
}
