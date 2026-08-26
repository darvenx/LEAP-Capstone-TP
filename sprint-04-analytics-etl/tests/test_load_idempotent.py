"""Load idempotency test: re-running the same frame must not double-count."""

from __future__ import annotations

import datetime as dt
from decimal import Decimal

from analytics_etl.load import TABLE, load
from analytics_etl.transform import transform


def _row(trade_date: dt.date, close: str) -> dict:
    return {
        "symbol": "INFY.NS",
        "trade_date": trade_date,
        "open": Decimal("100.00"),
        "high": Decimal("110.00"),
        "low": Decimal("95.00"),
        "close": Decimal(close),
        "adjclose": Decimal(close),
        "volume": 1000,
        "synthetic": False,
        "currency": "INR",
        "asset_class": "EQUITY",
        "exchange": "NSE",
    }


def test_reloading_the_same_frame_does_not_double_count(tmp_path):
    db = tmp_path / "test.duckdb"
    rows = [_row(dt.date(2026, 7, 1), "101.00"), _row(dt.date(2026, 7, 2), "102.00")]

    first = load(rows, db)
    second = load(rows, db)

    assert first["table_total"] == 2
    assert second["table_total"] == 2  # unchanged: idempotent on (symbol, trade_date)


def test_reload_updates_in_place_on_natural_key(tmp_path):
    db = tmp_path / "test.duckdb"
    load([_row(dt.date(2026, 7, 1), "101.00")], db)
    load([_row(dt.date(2026, 7, 1), "199.00")], db)  # same key, new close

    import duckdb

    con = duckdb.connect(str(db), read_only=True)
    try:
        total = con.execute(f"SELECT COUNT(*) FROM {TABLE}").fetchone()[0]
        close = con.execute(f"SELECT close FROM {TABLE}").fetchone()[0]
    finally:
        con.close()
    assert total == 1
    assert Decimal(str(close)) == Decimal("199.00")


def test_load_of_transformed_malformed_frame(malformed_raw, tmp_path):
    # End-to-end-ish: the two surviving rows from the malformed fixture load, and
    # a second load leaves the count unchanged.
    clean, _ = transform(malformed_raw)
    db = tmp_path / "test.duckdb"
    first = load(clean, db)
    second = load(clean, db)
    assert first["table_total"] == 2
    assert second["table_total"] == 2
