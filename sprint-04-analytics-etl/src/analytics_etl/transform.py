"""Transform stage: parse, type, clean and derive. Pure.

Takes a raw ``CandlesResponse`` dict and returns ``(clean_rows, quarantine)``.
It opens no socket, reads no environment variable and writes nowhere, so it is
the stage the test suite exercises hardest.

Disposition of the six malformed-fixture defects (see fixtures/README.md and the
plan Section F.2):

    1 duplicate date         -> dedupe, keep first, quarantine the later copy
    2 missing close          -> drop -> quarantine (close is the charted measure)
    3 non-numeric price      -> drop -> quarantine (cannot coerce safely)
    4 high < low             -> drop -> quarantine (an impossible bar; the red line)
    5 negative volume        -> null the volume, KEEP the OHLC row
    6 non-ISO date           -> drop -> quarantine (ambiguous DD/MM vs MM/DD)

Tolerated (valid, not defects): a calendar gap, ``volume: null`` on a real day,
and ``synthetic: true`` (kept, flag retained).
"""

from __future__ import annotations

import datetime as dt
from decimal import Decimal, InvalidOperation
from typing import Any

from .config import asset_class_for, exchange_for

# Quarantine reason codes.
REASON_MISSING_FIELD = "MISSING_FIELD"
REASON_MISSING_CLOSE = "MISSING_CLOSE"
REASON_NON_NUMERIC = "NON_NUMERIC"
REASON_HIGH_BELOW_LOW = "HIGH_BELOW_LOW"
REASON_NON_ISO_DATE = "NON_ISO_DATE"
REASON_DUPLICATE_DATE = "DUPLICATE_DATE"

_PRICE_FIELDS = ("open", "high", "low", "close")


def _quarantine(symbol: str, raw: dict, reason: str) -> dict:
    return {"symbol": symbol, "raw": raw, "reason": reason, "stage": "transform"}


def _parse_iso_date(value: Any) -> dt.date | None:
    """Return an ISO ``date`` or ``None`` if the value is not a strict ISO date."""
    if not isinstance(value, str):
        return None
    try:
        # date.fromisoformat is strict about YYYY-MM-DD, which rejects 09/07/2026.
        return dt.date.fromisoformat(value)
    except ValueError:
        return None


def _to_decimal(value: Any) -> Decimal | None:
    """Coerce a JSON number to Decimal, or None if it is not a number.

    Booleans are rejected (``True`` is not a price), and strings such as "n/a"
    raise and become None.
    """
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return Decimal(str(value))
    if isinstance(value, str):
        try:
            return Decimal(value)
        except InvalidOperation:
            return None
    return None


def _clean_volume(value: Any) -> int | None:
    """Volume is nulled when negative or absent; otherwise an int."""
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    try:
        v = int(value)
    except (TypeError, ValueError):
        return None
    return None if v < 0 else v


def transform(raw: dict) -> tuple[list[dict], list[dict]]:
    """Clean one raw ``CandlesResponse`` into ``(clean_rows, quarantine)``."""
    data = raw.get("data") or {}
    symbol = data.get("symbol") or (raw.get("meta") or {}).get("symbol") or "UNKNOWN"
    currency = data.get("currency") or "INR"
    candles = data.get("candles") or []

    exchange = exchange_for(symbol)
    asset_class = asset_class_for(symbol)

    clean_rows: list[dict] = []
    quarantine: list[dict] = []
    seen_dates: set[dt.date] = set()

    for candle in candles:
        if not isinstance(candle, dict):
            quarantine.append(_quarantine(symbol, candle, REASON_MISSING_FIELD))
            continue

        # 6: date must be a strict ISO date.
        trade_date = _parse_iso_date(candle.get("date"))
        if trade_date is None:
            quarantine.append(_quarantine(symbol, candle, REASON_NON_ISO_DATE))
            continue

        # 2: close specifically must be present (it is the charted measure).
        if "close" not in candle or candle.get("close") is None:
            quarantine.append(_quarantine(symbol, candle, REASON_MISSING_CLOSE))
            continue

        # Other OHLC fields must be present.
        if any(field not in candle or candle.get(field) is None for field in ("open", "high", "low")):
            quarantine.append(_quarantine(symbol, candle, REASON_MISSING_FIELD))
            continue

        # 3: every price must coerce to a number.
        prices: dict[str, Decimal] = {}
        non_numeric = False
        for field in _PRICE_FIELDS:
            dec = _to_decimal(candle.get(field))
            if dec is None:
                non_numeric = True
                break
            prices[field] = dec
        if non_numeric:
            quarantine.append(_quarantine(symbol, candle, REASON_NON_NUMERIC))
            continue

        # 4: an impossible bar (high below low) must never reach a chart.
        if prices["high"] < prices["low"]:
            quarantine.append(_quarantine(symbol, candle, REASON_HIGH_BELOW_LOW))
            continue

        # 1: one calendar day is one candle. Keep the first, quarantine repeats.
        if trade_date in seen_dates:
            quarantine.append(_quarantine(symbol, candle, REASON_DUPLICATE_DATE))
            continue
        seen_dates.add(trade_date)

        # adjclose defaults to close when absent; nulled if non-numeric.
        adjclose = _to_decimal(candle.get("adjclose"))
        if adjclose is None:
            adjclose = prices["close"]

        # 5: negative volume is nulled; the valid OHLC row is kept.
        volume = _clean_volume(candle.get("volume"))

        clean_rows.append(
            {
                "symbol": symbol,
                "trade_date": trade_date,
                "open": prices["open"],
                "high": prices["high"],
                "low": prices["low"],
                "close": prices["close"],
                "adjclose": adjclose,
                "volume": volume,
                "synthetic": bool(candle.get("synthetic", False)),
                "currency": currency,
                "asset_class": asset_class,
                "exchange": exchange,
            }
        )

    return clean_rows, quarantine
