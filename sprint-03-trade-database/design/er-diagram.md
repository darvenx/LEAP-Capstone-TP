# ER diagram — trade database

Mermaid `erDiagram` of the corrected operational model. It renders on GitHub and
diffs in review. Core trading entities are at the top; the Sprint 10 extension
tables (retained now, cost nothing) are grouped below.

```mermaid
erDiagram
    users ||--o| accounts : "owns"
    accounts ||--o{ orders : "places"
    instruments ||--o{ orders : "referenced by"
    accounts ||--o{ positions : "holds"
    instruments ||--o{ positions : "held as"
    accounts ||--o{ cash_ledger : "records"
    accounts ||--o{ portfolio_snapshots : "snapshotted"

    users ||--o{ watchlists : "creates"
    watchlists ||--o{ watchlist_items : "contains"
    instruments ||--o{ watchlist_items : "watched as"
    users ||--o{ price_alerts : "sets"
    instruments ||--o{ price_alerts : "alerted on"
    users ||--o{ notifications : "receives"
    users ||--o{ audit_logs : "acts in"

    users {
        uuid user_id PK
        varchar email UK
        varchar full_name
        varchar password_hash
        user_role role
        account_status status
    }
    accounts {
        bigint id PK "identity surrogate = ACCOUNTS.id"
        varchar account_id UK "business ref, e.g. ACC-000001"
        uuid user_id FK "UK, nullable"
        varchar holder_name
        decimal cash_balance "CHECK >= 0"
        char currency "CHECK ^[A-Z]{3}$"
        account_status status
        int version "optimistic lock"
    }
    instruments {
        bigint id PK
        varchar symbol UK "Fauxnance scheme"
        varchar name
        varchar asset_class
        char currency
        varchar exchange
        boolean tradable "delist = flag"
    }
    orders {
        uuid id PK
        varchar idempotency_key UK "rule 8 / 23505"
        bigint account_id FK
        bigint instrument_id FK
        order_side side
        int quantity "CHECK > 0"
        decimal price "CHECK > 0"
        decimal executed_price "NULL until FILLED"
        order_status status "default NEW"
        timestamptz created_on "S7 watermark"
    }
    positions {
        bigint id PK
        bigint account_id FK
        bigint instrument_id FK
        int quantity "CHECK >= 0"
        decimal average_cost
        string uq "UNIQUE(account_id, instrument_id)"
    }
    cash_ledger {
        uuid ledger_id PK
        bigint account_id FK
        ledger_entry_type entry_type
        uuid reference_id
        decimal amount "CHECK <> 0"
    }
    portfolio_snapshots {
        uuid snapshot_id PK
        bigint account_id FK
        decimal portfolio_value
        decimal unrealized_pnl
    }
    watchlists {
        uuid watchlist_id PK
        uuid user_id FK
        varchar watchlist_name
    }
    watchlist_items {
        uuid watchlist_item_id PK
        uuid watchlist_id FK
        bigint instrument_id FK
    }
    price_alerts {
        uuid alert_id PK
        uuid user_id FK
        bigint instrument_id FK
        decimal target_price
        alert_direction direction
    }
    notifications {
        uuid notification_id PK
        uuid user_id FK
        notification_status status
    }
    audit_logs {
        uuid audit_id PK
        uuid user_id FK
        varchar entity_type
        varchar entity_id
    }
```

## Relationship notes (cardinality and optionality)

- **users to accounts is one-to-zero-or-one.** `accounts.user_id` is `UNIQUE`
  and nullable. A user need not have a trading account yet, and (per the Sprint 8
  assumption) accounts exist before the auth service links a user to one.
- **accounts to orders is one-to-many, optional.** A freshly opened account has
  no orders. An order always belongs to exactly one account (`NOT NULL`).
- **instruments to orders is one-to-many.** A delisted instrument
  (`tradable = FALSE`) still appears in historical orders, which is why the row
  is retired, not deleted.
- **accounts + instruments to positions is one-to-many each, with a composite
  `UNIQUE(account_id, instrument_id)`** so an account holds each instrument at
  most once. `quantity >= 0` forbids short positions.
