package com.etleap.trading.domain;

import java.util.Objects;

/**
 * Reference data for one tradable instrument: a symbol in the Fauxnance scheme, a display
 * name, an asset class, and the currency it is quoted in. Answers whether it may be traded,
 * which is rule 3 of order placement.
 *
 * <p>Delisting is a flag, never a deleted row: order history references the symbol, and that
 * history is the audit trail. A delisted instrument still exists, it just answers
 * {@link #isTradable()} with {@code false}.
 */
public final class Instrument {

    private final String symbol;
    private final String displayName;
    private final String assetClass;
    private final String currency;
    private final String exchange;
    private boolean delisted;

    public Instrument(String symbol, String displayName, String assetClass, String currency, String exchange) {
        this.symbol = requireNonBlank(symbol, "symbol");
        this.displayName = requireNonBlank(displayName, "displayName");
        this.assetClass = requireNonBlank(assetClass, "assetClass");
        this.currency = requireNonBlank(currency, "currency");
        this.exchange = exchange;  // nullable
        this.delisted = false;
    }

    /** Rule 3: an order may only reference an instrument that exists and is tradable. */
    public boolean isTradable() {
        return !delisted;
    }

    /** Marks the instrument as no longer tradable, without erasing it from history. */
    public void delist() {
        this.delisted = true;
    }

    /** Reverses a delisting, making the instrument tradable again. */
    public void relist() {
        this.delisted = false;
    }

    public String getSymbol() {
        return symbol;
    }

    public String getDisplayName() {
        return displayName;
    }

    public String getAssetClass() {
        return assetClass;
    }

    public String getCurrency() {
        return currency;
    }

    public String getExchange() {
        return exchange;
    }

    private static String requireNonBlank(String value, String fieldName) {
        Objects.requireNonNull(value, fieldName + " must not be null");
        if (value.isBlank()) {
            throw new IllegalArgumentException(fieldName + " must not be blank");
        }
        return value;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof Instrument)) {
            return false;
        }
        Instrument that = (Instrument) other;
        return symbol.equals(that.symbol);
    }

    @Override
    public int hashCode() {
        return symbol.hashCode();
    }

    @Override
    public String toString() {
        return "Instrument{symbol='" + symbol + "', tradable=" + isTradable() + "}";
    }
}
