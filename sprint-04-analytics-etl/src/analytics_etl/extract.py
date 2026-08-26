"""Extract stage: obtain raw Fauxnance responses and hand them on unchanged.

The only stage that needs a key and a network. It does no parsing or cleaning;
the raw dict it returns is exactly what the transform consumes, so the cached
bytes and the live bytes are interchangeable.
"""

from __future__ import annotations

from .config import Config
from .fauxnance_client import FauxnanceClient


def extract(symbol: str, range_label: str, client: FauxnanceClient) -> dict:
    """Return the raw ``CandlesResponse`` dict for one symbol and range.

    Errors (429 / other 4xx / network) propagate from the client so the runner
    can decide per case whether to stop the batch or skip one symbol.
    """
    return client.get_candles(symbol, range_label)


def build_client(cfg: Config) -> FauxnanceClient:
    """Construct a client from configuration. Kept here so callers need not know
    the client's constructor shape."""
    return FauxnanceClient(
        base_url=cfg.base_url,
        api_key=cfg.api_key,
        cache_dir=cfg.cache_dir,
    )
