"""Extract error-handling tests. Four distinct cases, all offline: the suite
never opens a socket and never needs a key."""

from __future__ import annotations

import json

import pytest
import requests

from analytics_etl.fauxnance_client import (
    BadRequest,
    FauxnanceClient,
    NetworkError,
    QuotaExhausted,
)


class FakeResponse:
    def __init__(self, status_code=200, json_body=None, headers=None):
        self.status_code = status_code
        self._json = json_body or {}
        self.headers = headers or {}

    def json(self):
        return self._json

    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.HTTPError(f"HTTP {self.status_code}")


class FakeSession:
    """Records calls and returns queued responses or raises queued exceptions."""

    def __init__(self, outcomes):
        self._outcomes = list(outcomes)
        self.calls = 0

    def get(self, url, headers=None, params=None, timeout=None):
        self.calls += 1
        outcome = self._outcomes.pop(0) if self._outcomes else self._outcomes_default
        if isinstance(outcome, Exception):
            raise outcome
        return outcome


def _client(tmp_path, session, **kwargs):
    return FauxnanceClient(
        base_url="https://example.test/v1",
        api_key="unit-test-key",
        cache_dir=tmp_path,
        session=session,
        backoff_base=0.0,  # no real sleeping in tests
        **kwargs,
    )


def test_cache_hit_avoids_a_second_http_call(tmp_path):
    # Pre-seed the cache; the client must read it and never call the session.
    body = {"data": {"symbol": "INFY.NS", "candles": []}}
    (tmp_path / "INFY.NS_2026-07.json").write_text(json.dumps(body), encoding="utf-8")
    session = FakeSession([])
    client = _client(tmp_path, session)

    result = client.get_candles("INFY.NS", "2026-07")

    assert result == body
    assert session.calls == 0


def test_429_stops_with_quota_exhausted(tmp_path):
    session = FakeSession([FakeResponse(status_code=429, headers={"Retry-After": "120"})])
    client = _client(tmp_path, session)

    with pytest.raises(QuotaExhausted) as exc:
        client.get_candles("INFY.NS", "2026-07")
    assert exc.value.retry_after == 120
    assert session.calls == 1  # not retried


def test_other_4xx_fails_this_symbol(tmp_path):
    session = FakeSession([FakeResponse(status_code=404)])
    client = _client(tmp_path, session)

    with pytest.raises(BadRequest) as exc:
        client.get_candles("NOPE.NS", "2026-07")
    assert exc.value.status_code == 404
    assert session.calls == 1  # retrying would repeat the mistake


def test_network_error_retries_then_gives_up(tmp_path):
    session = FakeSession(
        [requests.ConnectionError("boom"), requests.Timeout("slow"), requests.ConnectionError("boom")]
    )
    client = _client(tmp_path, session, max_retries=3)

    with pytest.raises(NetworkError):
        client.get_candles("INFY.NS", "2026-07")
    assert session.calls == 3  # retried up to the budget, then gave up


def test_network_error_recovers_before_budget(tmp_path):
    body = {"data": {"symbol": "INFY.NS", "candles": []}}
    session = FakeSession([requests.Timeout("slow"), FakeResponse(status_code=200, json_body=body)])
    client = _client(tmp_path, session, max_retries=3)

    result = client.get_candles("INFY.NS", "2026-07")
    assert result == body
    assert session.calls == 2  # one failure, one success


def test_200_with_bad_data_is_returned_untouched(tmp_path):
    # A 200 whose body is wrong is not an HTTP problem; it belongs to transform.
    bad_body = {"data": {"symbol": "INFY.NS", "candles": [{"date": "nope"}]}}
    session = FakeSession([FakeResponse(status_code=200, json_body=bad_body)])
    client = _client(tmp_path, session)

    assert client.get_candles("INFY.NS", "2026-07") == bad_body
