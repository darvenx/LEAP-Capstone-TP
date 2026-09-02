"""Shared test fixtures. The suite reads canned responses from disk and never
touches the network, needs no key, and costs nothing against the quota."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures"


def _load(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


@pytest.fixture
def infy_raw() -> dict:
    """A clean NSE response: eight days, one null volume, one synthetic flag."""
    return _load("candles-infy-ns-2026-07.json")


@pytest.fixture
def reliance_raw() -> dict:
    """A clean NSE response with a calendar gap (a shut exchange day)."""
    return _load("candles-reliance-ns-2026-07.json")


@pytest.fixture
def malformed_raw() -> dict:
    """The deliberately corrupted BSE response carrying all six defects."""
    return _load("candles-malformed.json")
