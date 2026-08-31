package com.etleap.trading.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Instrument is reference data: a symbol in the Fauxnance scheme, a display name, an asset
 * class, a currency of quotation. It answers whether it may be traded (rule 3). Delisting is a
 * flag, never a deleted row, because order history references the symbol and that history is
 * the audit trail.
 */
class InstrumentTest {

    private Instrument newInstrument() {
        return new Instrument("FXN:ACME", "Acme Corp", "EQUITY", "USD");
    }

    @Test
    void newlyCreatedInstrumentIsTradable() {
        Instrument instrument = newInstrument();
        assertTrue(instrument.isTradable());
    }

    @Test
    void delistingFlipsTradabilityWithoutDeletingTheInstrument() {
        Instrument instrument = newInstrument();

        instrument.delist();

        assertFalse(instrument.isTradable());
        // Still here: the symbol still resolves, because order history references it.
        assertEquals("FXN:ACME", instrument.getSymbol());
    }

    @Test
    void relistingADelistedInstrumentMakesItTradableAgain() {
        Instrument instrument = newInstrument();
        instrument.delist();

        instrument.relist();

        assertTrue(instrument.isTradable());
    }

    @Test
    void exposesTheReferenceDataItWasGivenVerbatim() {
        Instrument instrument = newInstrument();

        assertEquals("FXN:ACME", instrument.getSymbol());
        assertEquals("Acme Corp", instrument.getDisplayName());
        assertEquals("EQUITY", instrument.getAssetClass());
        assertEquals("USD", instrument.getCurrency());
    }

    @Test
    void rejectsABlankSymbol() {
        assertThrows(IllegalArgumentException.class,
                () -> new Instrument("  ", "Acme Corp", "EQUITY", "USD"));
    }

    @Test
    void rejectsANullDisplayName() {
        assertThrows(NullPointerException.class,
                () -> new Instrument("FXN:ACME", null, "EQUITY", "USD"));
    }
}
