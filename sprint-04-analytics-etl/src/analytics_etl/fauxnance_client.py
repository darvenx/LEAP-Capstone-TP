"""HTTP client for the Fauxnance market-data API.

Owns the four-way error handling the sprint requires, and the raw-response
disk cache. It is the only place a network call and the API key live. The key
is sent as the ``X-Api-Key`` header and is never logged.

The cases, kept distinct (never one bare ``try``):

    429               quota exhausted -> raise QuotaExhausted, stop the batch
    202 / 503         data not ready  -> honour Retry-After, then raise BackfillPending
    other 4xx         bad request     -> raise BadRequest, fail this symbol only
    network/timeout   nothing arrived -> retry with growing backoff, then give up
    200 with bad data                 -> not an HTTP problem; handed to transform

The 202 (``BACKFILL_IN_PROGRESS``) and 503 (``UPSTREAM_UNAVAILABLE``) responses
only appear against the live API: the first pull of a symbol can trip an
asynchronous historical backfill. They are answered with the server's
``Retry-After`` hint (bounded), then given up on so the batch can move on and be
re-run once the data has landed.
"""

from __future__ import annotations

import calendar
import datetime as dt
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


class BackfillPending(FauxnanceError):
    """HTTP 202/503: the symbol's data is being fetched and is not ready yet.

    Distinct from ``BadRequest`` (the request was fine) and ``NetworkError``
    (the request arrived): the service accepted the call but has no real anchor
    to serve yet. Re-running once the backfill has landed will succeed.
    """

    def __init__(self, symbol: str, status_code: int, retry_after: int | None = None):
        self.status_code = status_code
        self.retry_after = retry_after
        reason = "backfill in progress" if status_code == 202 else "upstream unavailable"
        super().__init__(
            f"Fauxnance is not ready to serve {symbol!r} yet ({reason}, HTTP "
            f"{status_code}). Re-run later to pick it up."
        )


def _cache_path(cache_dir: Path, symbol: str, range_label: str) -> Path:
    safe_symbol = symbol.replace(":", "_").replace("/", "_")
    return cache_dir / f"{safe_symbol}_{range_label}.json"


def _range_to_dates(range_label: str) -> tuple[str | None, str | None]:
    """Translate a ``YYYY-MM`` cache label into inclusive ``from``/``to`` dates.

    The cache is keyed by a compact month label (e.g. ``2026-07``) so re-runs
    stay stable, but the live ``/candles/{symbol}`` endpoint speaks ISO dates.
    Anything that is not a ``YYYY-MM`` month falls back to ``(None, None)`` so
    the caller lets the API apply its own default window.
    """
    try:
        year_s, month_s = range_label.split("-", 1)
        year, month = int(year_s), int(month_s)
        first = dt.date(year, month, 1)
    except (ValueError, TypeError):
        return None, None
    last_day = calendar.monthrange(year, month)[1]
    last = dt.date(year, month, last_day)
    return first.isoformat(), last.isoformat()


def _parse_retry_after(resp: "requests.Response") -> int | None:
    value = resp.headers.get("Retry-After")
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


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
        max_retry_after: float = 60.0,
    ):
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._cache_dir = Path(cache_dir)
        self._session = session or requests.Session()
        self._max_retries = max_retries
        self._backoff_base = backoff_base
        # Upper bound on how long we honour a server Retry-After for 202/503, so a
        # long backfill estimate can never hang the batch.
        self._max_retry_after = max_retry_after

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

        # The live endpoint takes ISO from/to dates and a daily interval; the
        # compact month label is only our cache key.
        params: dict[str, str] = {"interval": "1d"}
        date_from, date_to = _range_to_dates(range_label)
        if date_from and date_to:
            params["from"] = date_from
            params["to"] = date_to

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
                raise QuotaExhausted(_parse_retry_after(resp))

            # 202/503: the request was accepted but the data is not ready. Wait
            # the (bounded) server hint and try again; give up when the budget
            # is spent so the batch can move on and be re-run later.
            if resp.status_code in (202, 503):
                retry_after = _parse_retry_after(resp)
                if attempt < self._max_retries:
                    hint = retry_after if retry_after is not None else self._backoff_base * (2 ** (attempt - 1))
                    sleep_for = min(float(hint), self._max_retry_after)
                    logger.warning(
                        "%s not ready (HTTP %d, attempt %d/%d), waiting %.1fs",
                        symbol, resp.status_code, attempt, self._max_retries, sleep_for,
                    )
                    time.sleep(sleep_for)
                    continue
                raise BackfillPending(symbol, resp.status_code, retry_after)

            if 400 <= resp.status_code < 500:
                raise BadRequest(resp.status_code, symbol)

            resp.raise_for_status()
            # A 200 whose body is wrong is not an HTTP problem: hand it on to
            # transform untouched.
            return resp.json()

        # Unreachable, but keeps the type checker honest.
        raise NetworkError(str(last_exc))
