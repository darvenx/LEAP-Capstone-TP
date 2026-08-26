"""Load stage: write clean rows into DuckDB. The only stage that writes.

The target for now is a DuckDB table ``market_candles`` keyed on
``(symbol, trade_date)``. The load is idempotent: re-running the same frame does
not double-count, because the natural key for the batch is deleted before the
rows are inserted. In Sprint 7 the same idempotent-merge-on-a-natural-key shape
loads ``fact_trades`` on ``source_order_id`` instead.
"""

from __future__ import annotations

from pathlib import Path

import duckdb

TABLE = "market_candles"

_CREATE_TABLE = f"""
CREATE TABLE IF NOT EXISTS {TABLE} (
    symbol      VARCHAR       NOT NULL,
    trade_date  DATE          NOT NULL,
    open        DECIMAL(18,4) NOT NULL,
    high        DECIMAL(18,4) NOT NULL,
    low         DECIMAL(18,4) NOT NULL,
    close       DECIMAL(18,4) NOT NULL,
    adjclose    DECIMAL(18,4) NOT NULL,
    volume      BIGINT,
    synthetic   BOOLEAN       NOT NULL,
    currency    VARCHAR       NOT NULL,
    asset_class VARCHAR       NOT NULL,
    exchange    VARCHAR       NOT NULL,
    PRIMARY KEY (symbol, trade_date)
);
"""

_COLUMNS = (
    "symbol", "trade_date", "open", "high", "low", "close",
    "adjclose", "volume", "synthetic", "currency", "asset_class", "exchange",
)


def load(rows: list[dict], duckdb_path: str | Path) -> dict:
    """Idempotently upsert clean rows into DuckDB. Returns a small summary.

    ``rows`` is the clean-row collection emitted by :func:`transform.transform`.
    """
    duckdb_path = str(duckdb_path)
    con = duckdb.connect(duckdb_path)
    try:
        con.execute(_CREATE_TABLE)

        if not rows:
            total = con.execute(f"SELECT COUNT(*) FROM {TABLE}").fetchone()[0]
            return {"received": 0, "written": 0, "table_total": total}

        # Delete the natural keys in this batch, then insert. This makes a
        # re-run of the same frame a no-op on the row count.
        keys = {(r["symbol"], r["trade_date"]) for r in rows}
        con.executemany(
            f"DELETE FROM {TABLE} WHERE symbol = ? AND trade_date = ?",
            [list(k) for k in keys],
        )

        placeholders = ", ".join(["?"] * len(_COLUMNS))
        con.executemany(
            f"INSERT INTO {TABLE} ({', '.join(_COLUMNS)}) VALUES ({placeholders})",
            [[r[c] for c in _COLUMNS] for r in rows],
        )

        total = con.execute(f"SELECT COUNT(*) FROM {TABLE}").fetchone()[0]
        return {"received": len(rows), "written": len(rows), "table_total": total}
    finally:
        con.close()
