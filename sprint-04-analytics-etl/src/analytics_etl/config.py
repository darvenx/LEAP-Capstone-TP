"""Configuration and symbol helpers.

The only module that reads the environment. The Fauxnance key is read from
``FAUXNANCE_API_KEY`` and nowhere else, and is never logged or printed. The
transform and load stages never import this module, which is how we keep them
free of I/O and secrets.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

# The symbol universe for this sprint: two NSE equities and one BSE equity
# (criterion 6 needs at least two NSE/BSE instruments), plus the malformed BSE
# fixture symbol which the tests exercise but the runner skips by default.
DEFAULT_SYMBOLS = ("INFY.NS", "RELIANCE.NS", "TATASTEEL.BO")

# Default candle range label. One symbol + one range = one cache entry.
DEFAULT_RANGE = "2026-07"


@dataclass(frozen=True)
class Config:
    """Runtime configuration. ``api_key`` is intentionally excluded from repr."""

    base_url: str
    api_key: str
    cache_dir: Path
    duckdb_path: Path
    symbols: tuple[str, ...]

    def __repr__(self) -> str:  # never leak the key through logging/repr
        key_state = "set" if self.api_key and self.api_key != PLACEHOLDER_KEY else "unset"
        return (
            f"Config(base_url={self.base_url!r}, api_key=<{key_state}>, "
            f"cache_dir={self.cache_dir!r}, duckdb_path={self.duckdb_path!r}, "
            f"symbols={self.symbols!r})"
        )


PLACEHOLDER_KEY = "replace-with-your-fauxnance-key"

# Package root: .../sprint-04-analytics-etl
_PACKAGE_ROOT = Path(__file__).resolve().parents[2]


def project_root() -> Path:
    """The repository root that holds the shared ``.env`` (Our-project/)."""
    return _PACKAGE_ROOT.parent


def load_config(symbols: tuple[str, ...] | None = None) -> Config:
    """Build a :class:`Config` from the environment and the repository ``.env``."""
    # Load the repository-root .env first, then the sprint-local one if present.
    load_dotenv(project_root() / ".env")
    load_dotenv(_PACKAGE_ROOT / ".env", override=False)

    base_url = os.environ.get(
        "FAUXNANCE_BASE_URL",
        "https://y4t9nq2bqf.execute-api.eu-west-2.amazonaws.com/v1",
    ).rstrip("/")
    api_key = os.environ.get("FAUXNANCE_API_KEY", "")

    cache_dir = Path(os.environ.get("ANALYTICS_CACHE_DIR", _PACKAGE_ROOT / ".cache"))
    duckdb_path = Path(os.environ.get("ANALYTICS_DUCKDB", _PACKAGE_ROOT / "analytics.duckdb"))

    return Config(
        base_url=base_url,
        api_key=api_key,
        cache_dir=cache_dir,
        duckdb_path=duckdb_path,
        symbols=symbols or DEFAULT_SYMBOLS,
    )


def has_live_key(cfg: Config) -> bool:
    """True only when a real key has been supplied (not the placeholder)."""
    return bool(cfg.api_key) and cfg.api_key != PLACEHOLDER_KEY


def exchange_for(symbol: str) -> str:
    """Derive the venue from the Fauxnance symbol scheme."""
    s = symbol.upper()
    if s.startswith("FX:"):
        return "FX"
    if s.startswith("X:"):
        return "CRYPTO"
    if s.endswith(".NS"):
        return "NSE"
    if s.endswith(".BO"):
        return "BSE"
    return "US"


def asset_class_for(symbol: str) -> str:
    """Derive the asset class from the symbol scheme."""
    s = symbol.upper()
    if s.startswith("FX:"):
        return "FX"
    if s.startswith("X:"):
        return "CRYPTO"
    return "EQUITY"
