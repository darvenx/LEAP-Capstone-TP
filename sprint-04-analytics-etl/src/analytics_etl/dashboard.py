"""Dashboard stage: build an offline HTML report from the DuckDB store.

plotly inlines its own JavaScript (``include_plotlyjs='inline'``) so the report
opens with no network and no build step. One file, ``report.html``, holds three
charts, each with a fragment anchor so ``claims.md`` can point at it, for example
``report.html#chart-close-trend``.

This module reads DuckDB and writes HTML. It is deliberately kept out of the
extract/transform/load contract because it is presentation, not pipeline.
"""

from __future__ import annotations

from pathlib import Path

import duckdb
import plotly.graph_objects as go

from .load import TABLE

# Display names so a non-technical reader never sees a bare ticker.
_DISPLAY_NAME = {
    "INFY.NS": "Infosys (NSE)",
    "RELIANCE.NS": "Reliance Industries (NSE)",
    "TATASTEEL.BO": "Tata Steel (BSE)",
    "AAPL": "Apple (US)",
}


def _name(symbol: str) -> str:
    return _DISPLAY_NAME.get(symbol, symbol)


def _fig_to_div(fig: go.Figure, div_id: str, first: bool) -> str:
    """Render one figure as an HTML fragment, inlining plotly.js only once."""
    return fig.to_html(
        include_plotlyjs="inline" if first else False,
        full_html=False,
        div_id=div_id,
    )


def build_dashboard(duckdb_path: str | Path, reports_dir: str | Path) -> dict:
    """Build ``report.html`` and return the computed claim figures.

    Returns a dict of headline numbers so the runner can print them and a human
    can trace a claim back to the rows.
    """
    reports_dir = Path(reports_dir)
    reports_dir.mkdir(parents=True, exist_ok=True)
    report_path = reports_dir / "report.html"

    con = duckdb.connect(str(duckdb_path), read_only=True)
    try:
        df = con.execute(
            f"""
            SELECT symbol, trade_date, close, volume, high, low, exchange
            FROM {TABLE}
            ORDER BY symbol, trade_date
            """
        ).df()
    finally:
        con.close()

    figures: list[str] = []
    claim_facts: dict = {"symbols": sorted(df["symbol"].unique().tolist()) if len(df) else []}

    # --- Chart 1: closing-price trend by instrument -----------------------------
    fig1 = go.Figure()
    trend: dict[str, float] = {}
    for symbol, g in df.groupby("symbol"):
        g = g.sort_values("trade_date")
        fig1.add_trace(
            go.Scatter(
                x=g["trade_date"], y=g["close"].astype(float),
                mode="lines+markers", name=_name(symbol),
            )
        )
        if len(g) >= 2:
            first_close = float(g["close"].iloc[0])
            last_close = float(g["close"].iloc[-1])
            if first_close:
                trend[symbol] = (last_close - first_close) / first_close * 100.0
    claim_facts["close_pct_change"] = trend
    fig1.update_layout(
        title="Closing price by instrument over the sampled period",
        xaxis_title="Trading day",
        yaxis_title="Closing price (local currency)",
        legend_title="Instrument",
        template="plotly_white",
    )
    figures.append(_fig_to_div(fig1, "chart-close-trend", first=True))

    # --- Chart 2: average daily traded volume by instrument ---------------------
    avg_vol = (
        df.dropna(subset=["volume"])
        .groupby("symbol")["volume"].mean()
        .sort_values(ascending=False)
    )
    claim_facts["avg_volume"] = {s: float(v) for s, v in avg_vol.items()}
    fig2 = go.Figure(
        go.Bar(
            x=[_name(s) for s in avg_vol.index],
            y=avg_vol.values,
            marker_color="#3366cc",
        )
    )
    fig2.update_layout(
        title="Average daily traded volume by instrument",
        xaxis_title="Instrument",
        yaxis_title="Average daily volume (shares)",
        template="plotly_white",
    )
    figures.append(_fig_to_div(fig2, "chart-avg-volume", first=False))

    # --- Chart 3: daily price range (volatility proxy) by instrument ------------
    fig3 = go.Figure()
    volatility: dict[str, float] = {}
    if len(df):
        df = df.copy()
        df["day_range_pct"] = (
            (df["high"].astype(float) - df["low"].astype(float))
            / df["low"].astype(float) * 100.0
        )
        for symbol, g in df.groupby("symbol"):
            g = g.sort_values("trade_date")
            fig3.add_trace(
                go.Scatter(
                    x=g["trade_date"], y=g["day_range_pct"],
                    mode="lines+markers", name=_name(symbol),
                )
            )
            volatility[symbol] = float(g["day_range_pct"].mean())
    claim_facts["avg_daily_range_pct"] = volatility
    fig3.update_layout(
        title="Daily high-to-low range as a percentage of the low, by instrument",
        xaxis_title="Trading day",
        yaxis_title="Intraday range (% of the day's low)",
        legend_title="Instrument",
        template="plotly_white",
    )
    figures.append(_fig_to_div(fig3, "chart-volatility", first=False))

    html = _assemble(figures)
    report_path.write_text(html, encoding="utf-8")
    claim_facts["report_path"] = str(report_path)
    return claim_facts


def _assemble(figures: list[str]) -> str:
    body = "\n<hr/>\n".join(figures)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>Enterprise Trading Platform — Sprint 4 analytics</title>
<style>
  body {{ font-family: system-ui, Arial, sans-serif; margin: 2rem; color: #222; }}
  h1 {{ font-size: 1.4rem; }}
  p.note {{ color: #555; max-width: 60rem; }}
</style>
</head>
<body>
<h1>Sprint 4 analytics — market-data candles</h1>
<p class="note">Offline report. Charts are backed by the DuckDB
<code>market_candles</code> table loaded by the pipeline. The underlying values
are invented fixture data, so read the shapes, not a market conclusion. Each
chart is addressable by fragment, e.g. <code>report.html#chart-close-trend</code>.</p>
{body}
</body>
</html>
"""
