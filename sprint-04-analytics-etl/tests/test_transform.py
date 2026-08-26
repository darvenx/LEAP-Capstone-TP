"""Transform tests: the assessed core. One test per malformed defect, plus
happy-path typing, dedupe, and the tolerated-but-valid cases."""

from __future__ import annotations

import datetime as dt
from decimal import Decimal

from analytics_etl.transform import (
    REASON_DUPLICATE_DATE,
    REASON_HIGH_BELOW_LOW,
    REASON_MISSING_CLOSE,
    REASON_NON_ISO_DATE,
    REASON_NON_NUMERIC,
    transform,
)


def _reasons(quarantine: list[dict]) -> set[str]:
    return {q["reason"] for q in quarantine}


# --- Happy path -------------------------------------------------------------

def test_happy_path_types_prices_as_decimal(infy_raw):
    clean, quarantine = transform(infy_raw)
    assert quarantine == []
    assert len(clean) == 8
    row = clean[0]
    assert row["trade_date"] == dt.date(2026, 7, 1)
    assert isinstance(row["open"], Decimal)
    assert row["open"] == Decimal("1584.5")
    assert row["symbol"] == "INFY.NS"
    assert row["exchange"] == "NSE"
    assert row["asset_class"] == "EQUITY"
    assert row["currency"] == "INR"


def test_null_volume_is_tolerated_and_kept(infy_raw):
    clean, _ = transform(infy_raw)
    row = next(r for r in clean if r["trade_date"] == dt.date(2026, 7, 6))
    assert row["volume"] is None            # null volume tolerated
    assert row["close"] == Decimal("1572.85")  # the price day is kept


def test_synthetic_flag_is_kept(infy_raw):
    clean, _ = transform(infy_raw)
    row = next(r for r in clean if r["trade_date"] == dt.date(2026, 7, 8))
    assert row["synthetic"] is True


def test_calendar_gap_is_tolerated(reliance_raw):
    # RELIANCE is missing 2026-07-08 (a shut exchange day). A gap is not a defect.
    clean, quarantine = transform(reliance_raw)
    assert quarantine == []
    dates = {r["trade_date"] for r in clean}
    assert dt.date(2026, 7, 8) not in dates
    assert dt.date(2026, 7, 7) in dates and dt.date(2026, 7, 9) in dates


# --- The six malformed defects (one test each) ------------------------------

def test_dedupe_keeps_first_and_quarantines_duplicate(malformed_raw):
    # Defect 1: 2026-07-01 appears twice with different closes.
    clean, quarantine = transform(malformed_raw)
    kept = [r for r in clean if r["trade_date"] == dt.date(2026, 7, 1)]
    assert len(kept) == 1
    assert kept[0]["close"] == Decimal("169.5")  # the first close is kept
    assert REASON_DUPLICATE_DATE in _reasons(quarantine)


def test_missing_close_is_quarantined(malformed_raw):
    # Defect 2: 2026-07-02 has no close field.
    _, quarantine = transform(malformed_raw)
    assert REASON_MISSING_CLOSE in _reasons(quarantine)
    assert any(
        q["reason"] == REASON_MISSING_CLOSE and q["raw"].get("date") == "2026-07-02"
        for q in quarantine
    )


def test_non_numeric_price_is_quarantined(malformed_raw):
    # Defect 3: 2026-07-06 open is the string "n/a".
    _, quarantine = transform(malformed_raw)
    assert any(
        q["reason"] == REASON_NON_NUMERIC and q["raw"].get("open") == "n/a"
        for q in quarantine
    )


def test_rejects_a_high_below_a_low(malformed_raw):
    # Defect 4: 2026-07-07 has a high below its low. The explicit red line: an
    # impossible bar must never reach a chart.
    clean, quarantine = transform(malformed_raw)
    assert dt.date(2026, 7, 7) not in {r["trade_date"] for r in clean}
    assert any(
        q["reason"] == REASON_HIGH_BELOW_LOW and q["raw"].get("date") == "2026-07-07"
        for q in quarantine
    )


def test_negative_volume_is_nulled_and_row_kept(malformed_raw):
    # Defect 5: 2026-07-08 volume is -1. Null the volume, keep valid OHLC.
    clean, _ = transform(malformed_raw)
    row = next(r for r in clean if r["trade_date"] == dt.date(2026, 7, 8))
    assert row["volume"] is None
    assert row["close"] == Decimal("175.8")


def test_non_iso_date_is_quarantined(malformed_raw):
    # Defect 6: the last row dates itself 09/07/2026 (non-ISO).
    _, quarantine = transform(malformed_raw)
    assert any(
        q["reason"] == REASON_NON_ISO_DATE and q["raw"].get("date") == "09/07/2026"
        for q in quarantine
    )


def test_quarantine_record_carries_symbol_and_stage(malformed_raw):
    _, quarantine = transform(malformed_raw)
    assert quarantine, "expected some quarantined rows"
    for q in quarantine:
        assert q["symbol"] == "TATASTEEL.BO"
        assert q["stage"] == "transform"
        assert "reason" in q and "raw" in q


def test_malformed_only_two_rows_survive(malformed_raw):
    # 2026-07-01 (first copy) and 2026-07-08 (volume nulled) are the only two
    # rows that should reach the clean set.
    clean, _ = transform(malformed_raw)
    surviving = sorted(r["trade_date"] for r in clean)
    assert surviving == [dt.date(2026, 7, 1), dt.date(2026, 7, 8)]
