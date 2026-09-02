# Sprint 4 — Analytics & ETL pipeline

An installable Python project that extracts end-of-day **candles** from the
Fauxnance API, transforms and cleans them, loads them into a **DuckDB**
analytical store, and produces an **offline HTML dashboard** backing three
business claims.

The pipeline is three functions in three modules, wired by a runner, built so
that in **Sprint 7** the *same* functions are repointed from market-data candles
to the operational database and load the star schema in
`contracts/analytics-schema.sql`. The source changes; the shape does not.

## Layout

```
sprint-04-analytics-etl/
├── pyproject.toml            # installable project; [dev] extra brings pytest
├── src/analytics_etl/
│   ├── config.py             # loads env (the only module that reads it); never logs the key
│   ├── fauxnance_client.py   # HTTP client, X-Api-Key, 4-way errors, raw .cache/
│   ├── extract.py            # extract(symbol, range, client) -> raw dict   (network only)
│   ├── transform.py          # transform(raw) -> (clean_rows, quarantine)   (pure)
│   ├── load.py               # load(rows, duckdb_path) -> counts            (DuckDB write only)
│   ├── dashboard.py          # offline HTML (plotly, include_plotlyjs='inline')
│   └── __main__.py           # runner: E -> T -> L, writes dashboard, prints a summary
├── fixtures/                 # three canned CandlesResponse payloads (one malformed)
├── tests/                    # pytest: transform (core), extract errors, load idempotency
├── reports/                  # committed dashboard output (report.html)
└── .cache/                   # git-ignored raw pulls / fixture-seeded raw JSON
```

## Install and run (from the repository root, `Our-project/`)

```bash
python -m venv .venv
# Windows PowerShell:  .venv\Scripts\python -m pip install -e "sprint-04-analytics-etl[dev]"
# Linux/macOS:         .venv/bin/python -m pip install -e "sprint-04-analytics-etl[dev]"

# run the test suite (offline, no key, no network)
python -m pytest sprint-04-analytics-etl

# run the pipeline (offline from fixtures until a real key is set)
python -m analytics_etl        # or the console script: analytics-etl
```

The runner writes `reports/report.html` and the DuckDB store
(`analytics.duckdb`), and prints a per-symbol summary.

## The key and the quota

The key is read from `FAUXNANCE_API_KEY` in the repository-root `.env` and
nowhere else. It is sent as the `X-Api-Key` header and never logged (the
`Config.__repr__` masks it). Until a real key is issued the pipeline runs
**offline**: the runner pre-seeds `.cache/` from the committed fixtures. To go
live: put the key in `.env`, delete `.cache/`, re-run. No code change.

Quota is 2000 requests/day/key. Raw responses are cached to `.cache/` keyed by
symbol + range, so re-runs cost nothing.

## Symbol universe

`INFY.NS`, `RELIANCE.NS` (both NSE) and `TATASTEEL.BO` (BSE) — three NSE/BSE
instruments, satisfying the "at least two NSE/BSE" criterion. `TATASTEEL.BO` is
served offline by the **malformed** fixture, so a normal run also demonstrates
the transform quarantining bad rows.

## Error handling (four distinct cases, never one bare `try`)

| What happened | Signal | Response |
|---|---|---|
| Quota exhausted | HTTP 429 (`Retry-After`) | `QuotaExhausted` → stop the batch, say so |
| Data not ready yet | HTTP 202 / 503 (`Retry-After`) | honour the (bounded) hint, then `BackfillPending` → skip this symbol, re-run later |
| Bad request | other 4xx (401/403/404/400) | `BadRequest` → fail this symbol, continue others |
| Nothing arrived | connection error / timeout | retry with growing backoff, then `NetworkError` |
| 200 with bad data | a missing/typed/impossible field | not HTTP; handed to `transform` (drop/quarantine) |

The live `/candles/{symbol}` endpoint is called with ISO `from`/`to` dates and
`interval=1d`; the compact `YYYY-MM` label (e.g. `2026-07`) is only the cache
key, translated to the first/last day of that month per call.

## The six malformed-fixture defects and this transform's disposition

| # | Defect (date) | Disposition |
|---|---|---|
| 1 | duplicate `2026-07-01` | dedupe: keep first, quarantine the later copy |
| 2 | `2026-07-02` missing `close` | drop → quarantine |
| 3 | `2026-07-06` `open="n/a"` | drop → quarantine |
| 4 | `2026-07-07` high < low | drop → quarantine (`test_rejects_a_high_below_a_low`) |
| 5 | `2026-07-08` volume = -1 | null the volume, **keep** the OHLC row |
| 6 | `09/07/2026` non-ISO date | drop → quarantine |

Tolerated as valid: a calendar gap, `volume: null` on a real day, `synthetic: true`.

## Testing

`pytest` from this folder (or `python -m pytest sprint-04-analytics-etl` from the
root) runs the whole suite offline. Coverage: the transform gets one test per
defect plus happy-path typing, dedupe and the tolerated cases; extract gets the
four error cases plus cache-hit; load gets the idempotency guarantee.
