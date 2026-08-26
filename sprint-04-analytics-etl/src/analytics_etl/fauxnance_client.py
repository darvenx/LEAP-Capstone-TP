"""HTTP client for the Fauxnance market-data API.

Owns the four-way error handling the sprint requires, and the raw-response
disk cache. It is the only place a network call and the API key live. The key
is sent as the ``X-Api-Key`` header and is never logged.

The four cases, kept distinct (never one bare ``try``):

    429               quota exhausted -> raise QuotaExhausted, stop the batch
    other 4xx         bad request     -> raise BadRequest, fail this symbol only
    network/timeout   nothing arrived -> retry with growing backoff, then give up
    200 with bad data                 -> not an HTTP problem; handed to transform
"""

from __future__ import annotations

import json
import logging
import time
from pathlib import Path

import requests

logger = logging.getLogger("analytics_etl.fauxnance")


class FauxnanceError(Exception):
    """Base class for Fauxnance client failures."""


class QuotaExhausted(FauxnanceError):
    """HTTP 429. The daily quota is spent; the batch must stop."""

    def __init__(self, retry_after: int | None = None):
        self.retry_after = retry_after
        super().__init__(
            "Fauxnance daily quota exhausted (HTTP 429)."
            + (f" Resets in ~{retry_after}s." if retry_after else "")
        )


class BadRequest(FauxnanceError):
    """A non-429 4xx: bad/missing key (401), unknown symbol (404), bad range (400)."""

    def __init__(self, status_code: int, symbol: str):
        self.status_code = status_code
        super().__init__(
            f"Fauxnance rejected the request for {symbol!r} with HTTP {status_code}. "
            "Retrying would repeat the mistake."
        )


class NetworkError(FauxnanceError):
    """Nothing reached the service after the retry budget was spent."""


def _cache_path(cache_dir: Path, symbol: str, range_label: str) -> Path:
    safe_symbol = symbol.replace(":", "_").replace("/", "_")
    return cache_dir / f"{safe_symbol}_{range_label}.json"


class FauxnanceClient:
    """Thin client around ``GET /candles/{symbol}`` with a raw-response cache."""

    def __init__(
        self,
        base_url: str,
        api_key: str,
        cache_dir: Path,
        *,
        session: requests.Session | None = None,
        max_retries: int = 3,
        backoff_base: float = 0.5,
    ):
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._cache_dir = Path(cache_dir)
        self._session = session or requests.Session()
        self._max_retries = max_retries
        self._backoff_base = backoff_base

    def get_candles(self, symbol: str, range_label: str) -> dict:
        """Return the raw ``CandlesResponse`` dict, from cache if present.

        Caches the raw response (not a cleaned frame), keyed by symbol + range,
        so re-runs cost nothing against the quota.
        """
        cache_file = _cache_path(self._cache_dir, symbol, range_label)
        if cache_file.exists():
            logger.info("cache hit: %s (%s)", symbol, range_label)
            return json.loads(cache_file.read_text(encoding="utf-8"))

        logger.info("cache miss: fetching %s (%s)", symbol, range_label)
        raw = self._fetch(symbol, range_label)

        self._cache_dir.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps(raw), encoding="utf-8")
        return raw

    def _fetch(self, symbol: str, range_label: str) -> dict:
        url = f"{self._base_url}/candles/{symbol}"
        headers = {"X-Api-Key": self._api_key}  # never logged
        params = {"range": range_label}

        last_exc: Exception | None = None
        for attempt in range(1, self._max_retries + 1):
            try:
                resp = self._session.get(url, headers=headers, params=params, timeout=10)
            except (requests.ConnectionError, requests.Timeout) as exc:
                # Nothing reached the service: retry with growing backoff.
                last_exc = exc
                if attempt < self._max_retries:
                    sleep_for = self._backoff_base * (2 ** (attempt - 1))
                    logger.warning(
                        "network error for %s (attempt %d/%d), backing off %.1fs",
                        symbol, attempt, self._max_retries, sleep_for,
                    )
                    time.sleep(sleep_for)
                    continue
                raise NetworkError(
                    f"No response for {symbol!r} after {self._max_retries} attempts."
                ) from exc

            if resp.status_code == 429:
                retry_after = resp.headers.get("Retry-After")
                raise QuotaExhausted(int(retry_after) if retry_after else None)

            if 400 <= resp.status_code < 500:
                raise BadRequest(resp.status_code, symbol)

            resp.raise_for_status()
            # A 200 whose body is wrong is not an HTTP problem: hand it on to
            # transform untouched.
            return resp.json()

        # Unreachable, but keeps the type checker honest.
        raise NetworkError(str(last_exc))
