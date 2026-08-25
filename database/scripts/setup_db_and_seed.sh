#!/usr/bin/env bash
set -euo pipefail

# Usage: TARGET_DATABASE=mydb ./scripts/setup_db_and_seed.sh

TARGET_DB=${TARGET_DATABASE:-${POSTGRES_DB:-trade_db}}
PGHOST=${PGHOST:-localhost}
PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres}

if [ -z "${PGPASSWORD:-}" ]; then
  echo -n "Postgres password for user ${PGUSER}: "
  read -s PGPASSWORD
  echo
  export PGPASSWORD
fi

PSQL="psql -h $PGHOST -p $PGPORT -U $PGUSER"

echo "Checking if database '$TARGET_DB' exists..."
EXISTS=$($PSQL -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${TARGET_DB}';")
if [ "$EXISTS" != "1" ]; then
  echo "Database does not exist — creating '${TARGET_DB}'"
  $PSQL -d postgres -c "CREATE DATABASE \"${TARGET_DB}\";"
else
  echo "Database '${TARGET_DB}' already exists"
fi

echo "Applying schema migrations to ${TARGET_DB}"
 $PSQL -d "$TARGET_DB" -f schema.sql

echo "Loading CSV seed files (aligned to DDL)"
set -x
$PSQL -d "$TARGET_DB" -c "\copy currencies(code,name) FROM 'seed/currencies.csv' CSV HEADER;"
$PSQL -d "$TARGET_DB" -c "\copy users(user_id,email,password_hash,role,status,phone_number,date_of_birth,created_at,updated_at) FROM 'seed/users.csv' CSV HEADER;"
$PSQL -d "$TARGET_DB" -c "\copy trading_accounts(account_id,user_id,account_number,cash_balance,created_at,updated_at) FROM 'seed/trading_accounts.csv' CSV HEADER;"
$PSQL -d "$TARGET_DB" -c "\copy instruments(instrument_id,ticker,company_name,exchange,sector,is_active,created_at) FROM 'seed/instruments_new.csv' CSV HEADER;"
$PSQL -d "$TARGET_DB" -c "\copy holdings(holding_id,account_id,instrument_id,quantity,average_buy_price,updated_at) FROM 'seed/holdings.csv' CSV HEADER;"
$PSQL -d "$TARGET_DB" -c "\copy portfolio_snapshots(snapshot_id,account_id,portfolio_value,unrealized_pnl,snapshot_time) FROM 'seed/portfolio_snapshots.csv' CSV HEADER;"
$PSQL -d "$TARGET_DB" -c "\copy orders(order_id,account_id,instrument_id,side,order_type,quantity,remaining_quantity,limit_price,status,created_at,updated_at) FROM 'seed/orders_new.csv' CSV HEADER;"
$PSQL -d "$TARGET_DB" -c "\copy cash_ledger(ledger_id,account_id,entry_type,reference_id,amount,created_at) FROM 'seed/cash_ledger.csv' CSV HEADER;"
set +x

echo "Seed loading complete"
