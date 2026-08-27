Quick start:

From the VS Code PowerShell terminal, edit the password in the root
`manifest.env`, then run:

```powershell
cd C:\Users\Administrator\Documents\LEAP-Capstone-TP
.\setup-database.ps1
```

You can also run the database script directly:

```powershell
cd C:\Users\Administrator\Documents\LEAP-Capstone-TP\database
.\scripts\setup_db_and_seed.ps1
```

The PowerShell command loads `manifest.env`, applies every numbered migration
and every SQL seed in filename order, and stops on the first error. The
password is placed in the current process environment only; close the terminal
or run `Remove-Item Env:PGPASSWORD` after use.

The original `scripts/setup_db_and_seed.sh` is equivalent for Git Bash or WSL.

## Docker from VS Code terminal

From the repository root:

```powershell
docker compose --env-file .\manifest.env up -d
docker compose logs -f postgres
```

The container initializes the database automatically on its first start. To
reset it after changing migrations or seeds:

```powershell
docker compose down -v
docker compose --env-file .\manifest.env up -d
```

Use `docker compose down` without `-v` when you need to keep the data volume.

## pgAdmin

1. Register/connect to your PostgreSQL server.
2. Create an empty database named `trade_db` in pgAdmin.
3. Open Query Tool for `trade_db` and run each migration in order:
	`migrations/001_extensions_and_enums.sql`,
	`migrations/002_create_tables.sql`,
	`migrations/003_create_indexes.sql`, and
	`migrations/004_order_guards.sql`.
4. Run `seed/001_core.sql`.
5. Run the checks below, or open `sql/verify_queries.sql`, replace its `$1`
	placeholders with the example values in the file comments, and execute it.

To reset in pgAdmin, disconnect from `trade_db`, right-click it, choose Delete,
then recreate it before rerunning the files.

```sql
SELECT status, COUNT(*) FROM trading_accounts GROUP BY status;
SELECT status, COUNT(*) FROM orders GROUP BY status;
SELECT account_number, status, cash_balance FROM trading_accounts ORDER BY account_number;
SELECT i.ticker, h.quantity, h.average_buy_price
FROM holdings h JOIN instruments i ON i.instrument_id = h.instrument_id;
```

The six business queries are in `sql/verify_queries.sql`; the two required
constraint rejection demonstrations are in `sql/failure_tests.sql`. Execute
the failure tests with `ON_ERROR_STOP` disabled because the two errors are
intentional; confirm SQLSTATE `23505` and `23503` in the Messages tab.
