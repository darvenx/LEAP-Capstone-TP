"""Sprint 4 analytics and ingestion pipeline.

Three pure-ish stages in three modules, wired by a runner:

    extract   (network + key only)   fauxnance -> raw dict
    transform (pure, no I/O)         raw dict -> (clean rows, quarantine)
    load      (DuckDB write only)    clean rows -> DuckDB market_candles

The shape is frozen this sprint so Sprint 7 can repoint the same functions from
market-data candles to the operational database and load the star schema in
`contracts/analytics-schema.sql` without reshaping the pipeline.
"""

__all__ = ["extract", "transform", "load", "config", "fauxnance_client", "dashboard"]

__version__ = "0.1.0"
