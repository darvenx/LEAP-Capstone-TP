package com.etleap.trading.domain.exception;

import java.util.Objects;

/**
 * Case 3: the symbol is unknown, or it is known and no longer tradable. Rule 3.
 *
 * <p>Both reasons - unknown symbol and a delisted-but-still-referenced symbol - share this one
 * case and this one code deliberately: from the caller's point of view "you cannot trade this
 * instrument" is a single fact, and the distinction is an internal one visible only via
 * {@link Instrument#isTradable()} during investigation, not to the order placement caller.
 */
public final class InstrumentNotFoundException extends TradingDomainException {

    private static final String CODE = "INS-404";
    private static final String MESSAGE = "Instrument not found or not tradable";

    private final String symbol;

    public InstrumentNotFoundException(String symbol) {
        super(CODE, MESSAGE);
        this.symbol = Objects.requireNonNull(symbol, "symbol must not be null");
    }

    public String getSymbol() {
        return symbol;
    }
}
