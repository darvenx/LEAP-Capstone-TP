Quick start:

From this directory, provide PostgreSQL authentication through the environment
or `.pgpass`, then run:

```sh
TARGET_DATABASE=trade_db ./scripts/setup_db_and_seed.sh
```

The command applies every numbered migration and every SQL seed in filename
order. If `TARGET_DATABASE` is omitted, the script reads `POSTGRES_DB` from the
repository `.env`. It stops on the first error and does not prompt.

The six business queries are in `sql/verify_queries.sql`; the two required
constraint rejection demonstrations are in `sql/failure_tests.sql`.
