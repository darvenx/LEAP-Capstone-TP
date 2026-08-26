"""Runner: wire extract -> transform -> load, build the dashboard, print a summary.

Run it either way (they are equivalent):

    analytics-etl                 # console script from pyproject
    python -m analytics_etl       # module __main__

With no real ``FAUXNANCE_API_KEY`` set, the runner pre-seeds ``.cache/`` from the
committed fixtures and runs fully offline. When a real key is put in ``.env``,
clear ``.cache/`` and re-run to pull live; no code changes.
"""

from __future__ import annotations

import logging
import shutil
import sys
from pathlib import Path

from . import config as config_mod
from .dashboard import build_dashboard
from .extract import build_client, extract
from .fauxnance_client import BackfillPending, BadRequest, NetworkError, QuotaExhausted
from .load import load
from .transform import transform

logger = logging.getLogger("analytics_etl")

# Which fixture seeds which symbol's cache when running offline. TATASTEEL.BO is
# intentionally seeded from the malformed fixture, so a normal offline run also
# demonstrates the transform quarantining bad rows.
_FIXTURE_FOR_SYMBOL = {
    "INFY.NS": "candles-infy-ns-2026-07.json",
    "RELIANCE.NS": "candles-reliance-ns-2026-07.json",
    "TATASTEEL.BO": "candles-malformed.json",
}


def _fixtures_dir() -> Path:
    return Path(__file__).resolve().parents[2] / "fixtures"


def _seed_cache_from_fixtures(cfg: config_mod.Config, range_label: str) -> None:
    """Copy fixtures into the raw cache so an offline run has data to read."""
    fixtures = _fixtures_dir()
    cfg.cache_dir.mkdir(parents=True, exist_ok=True)
    for symbol in cfg.symbols:
        fixture_name = _FIXTURE_FOR_SYMBOL.get(symbol)
        if not fixture_name:
            continue
        source = fixtures / fixture_name
        if not source.exists():
            continue
        safe_symbol = symbol.replace(":", "_").replace("/", "_")
        target = cfg.cache_dir / f"{safe_symbol}_{range_label}.json"
        if not target.exists():
            shutil.copyfile(source, target)
            logger.info("seeded cache for %s from %s", symbol, fixture_name)


def run(range_label: str = config_mod.DEFAULT_RANGE) -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s %(name)s: %(message)s",
    )
    cfg = config_mod.load_config()
    logger.info("configuration: %r", cfg)  # __repr__ masks the key

    if not config_mod.has_live_key(cfg):
        logger.info("no live FAUXNANCE_API_KEY set: running offline from fixtures")
        _seed_cache_from_fixtures(cfg, range_label)

    client = build_client(cfg)

    total_clean = 0
    total_quarantined = 0
    processed: list[str] = []

    for symbol in cfg.symbols:
        try:
            raw = extract(symbol, range_label, client)
        except QuotaExhausted as exc:
            # 429: stop the whole batch, plainly.
            logger.error("stopping: %s", exc)
            break
        except BadRequest as exc:
            # other 4xx: fail this symbol, carry on with the rest.
            logger.error("skipping %s: %s", symbol, exc)
            continue
        except BackfillPending as exc:
            # 202/503: data not ready yet; skip this symbol and re-run later.
            logger.warning("skipping %s (not ready): %s", symbol, exc)
            continue
        except NetworkError as exc:
            logger.error("skipping %s after retries: %s", symbol, exc)
            continue

        clean_rows, quarantine = transform(raw)
        result = load(clean_rows, cfg.duckdb_path)
        total_clean += len(clean_rows)
        total_quarantined += len(quarantine)
        processed.append(symbol)
        logger.info(
            "%s: %d clean, %d quarantined, table now %d rows",
            symbol, len(clean_rows), len(quarantine), result["table_total"],
        )
        for q in quarantine:
            logger.info("  quarantined %s: %s", symbol, q["reason"])

    if not processed:
        logger.error("no symbols processed; nothing to plot")
        return 1

    reports_dir = Path(__file__).resolve().parents[2] / "reports"
    facts = build_dashboard(cfg.duckdb_path, reports_dir)

    print("\n=== Sprint 4 pipeline summary ===")
    print(f"symbols processed : {', '.join(processed)}")
    print(f"clean rows loaded : {total_clean}")
    print(f"rows quarantined  : {total_quarantined}")
    print(f"dashboard         : {facts['report_path']}")
    if facts.get("close_pct_change"):
        print("close % change over period:")
        for sym, pct in facts["close_pct_change"].items():
            print(f"  {sym:<14} {pct:+.2f}%")
    return 0


def main() -> None:
    sys.exit(run())


if __name__ == "__main__":
    main()
