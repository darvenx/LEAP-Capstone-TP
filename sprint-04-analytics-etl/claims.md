# Claims

Three claims about the sampled market-data window, each backed by a chart in
`reports/report.html`. The underlying values are invented fixture data, so these
claims describe the fixtures, not the real market — they are stated as real
claims so the review can check the mechanism (claim → chart → rows).

| # | Claim | Chart artefact |
|---|---|---|
| 1 | Over the sampled 1–14 July 2026 window, Reliance Industries (NSE) closed the period up **+1.08%** (2876.90 → 2907.95), a slightly stronger run than Infosys's **+1.03%** over the same fortnight. | `reports/report.html#chart-close-trend` |
| 2 | Infosys (NSE) traded more heavily than Reliance across early July 2026: its **average daily volume was ~7.54M shares** versus Reliance's **~6.68M**, despite Infosys closing lower in absolute price. | `reports/report.html#chart-avg-volume` |
| 3 | Infosys was the more volatile of the two NSE names intraday in the window: its **average daily high-to-low range was ~1.10% of the day's low**, against **~0.99%** for Reliance. | `reports/report.html#chart-volatility` |

## Notes

- **Date range pulled:** July 2026 (range label `2026-07`).
- **Symbols in scope:** `INFY.NS`, `RELIANCE.NS` (both NSE), `TATASTEEL.BO` (BSE)
  — three NSE/BSE instruments (criterion 6 needs at least two).
- **What the transform rejected:** running the pipeline quarantines 5 of the 7
  `TATASTEEL.BO` candles (the malformed fixture): the duplicate `2026-07-01`
  copy, the `2026-07-02` row missing `close`, the `2026-07-06` row with
  `open="n/a"`, the `2026-07-07` row whose high is below its low, and the
  `09/07/2026` non-ISO-dated row. The `2026-07-08` negative-volume row is
  **kept** with its volume nulled. So `TATASTEEL.BO` contributes only two clean
  rows, which is why the two NSE names carry the claims.
- **Withdrawn claim.** An early "Tata Steel rose +3.72% over the window" was
  withdrawn: with only two surviving clean candles after cleaning, a
  start-to-end percentage is not a defensible trend, only a two-point difference.
  The withdrawal is the point of the malformed fixture — the cleaning changes
  what you are allowed to claim.

## How to run

The pipeline has both entry points (equivalent). From the repository root
(`Our-project/`), with the project installed (`pip install -e
'sprint-04-analytics-etl[dev]'`):

```bash
analytics-etl                 # console script declared in pyproject.toml
python -m analytics_etl       # module __main__ block
```

It writes `analytics.duckdb` and `reports/report.html`, and prints a per-symbol
summary of clean vs quarantined rows.
