# Entity relationship diagram

```mermaid
erDiagram
    USERS ||--|| TRADING_ACCOUNTS : owns
    TRADING_ACCOUNTS ||--o{ ORDERS : places
    INSTRUMENTS ||--o{ ORDERS : names
    TRADING_ACCOUNTS ||--o{ HOLDINGS : has
    INSTRUMENTS ||--o{ HOLDINGS : held_as
    TRADING_ACCOUNTS ||--o{ CASH_LEDGER : records
    USERS ||--o{ WATCHLISTS : creates
    WATCHLISTS ||--o{ WATCHLIST_ITEMS : contains
    INSTRUMENTS ||--o{ WATCHLIST_ITEMS : watches
    TRADING_ACCOUNTS ||--o{ PORTFOLIO_SNAPSHOTS : snapshots
    USERS ||--o{ NOTIFICATIONS : receives
    USERS ||--o{ AUDIT_LOGS : performs

    USERS {
        uuid user_id PK
        varchar email UK
        user_role role
        user_status status
    }
    TRADING_ACCOUNTS {
        uuid account_id PK
        uuid user_id FK UK
        varchar account_number UK
        varchar holder_name
        account_status status
        char currency
        numeric cash_balance
        bigint version
    }
    INSTRUMENTS {
        uuid instrument_id PK
        varchar ticker UK
        varchar display_name
        asset_class asset_class
        char quote_currency
        boolean is_tradable
    }
    ORDERS {
        uuid order_id PK
        uuid account_id FK
        uuid instrument_id FK
        varchar idempotency_key UK
        order_side side
        order_type order_type
        numeric quantity
        numeric remaining_quantity
        numeric limit_price
        order_status status
    }
    HOLDINGS {
        uuid holding_id PK
        uuid account_id FK
        uuid instrument_id FK
        numeric quantity
        numeric average_buy_price
    }
    CASH_LEDGER {
        uuid ledger_id PK
        uuid account_id FK
        ledger_entry_type entry_type
        uuid reference_id
        numeric amount
    }
    PORTFOLIO_SNAPSHOTS {
        uuid snapshot_id PK
        uuid account_id FK
        numeric portfolio_value
        numeric unrealized_pnl
        timestamptz snapshot_time
    }
    WATCHLISTS {
        uuid watchlist_id PK
        uuid user_id FK
        varchar watchlist_name
    }
    WATCHLIST_ITEMS {
        uuid watchlist_item_id PK
        uuid watchlist_id FK
        uuid instrument_id FK
        numeric target_high_price
        numeric target_low_price
    }
    NOTIFICATIONS {
        uuid notification_id PK
        uuid user_id FK
        text message
        notification_status status
    }
    AUDIT_LOGS {
        uuid audit_id PK
        uuid user_id FK
        varchar action
        varchar entity_type
        uuid entity_id
        jsonb old_values
        jsonb new_values
    }
```

A user has one account in this scope. Accounts may have no orders, holdings,
ledger entries, or snapshots yet. Instruments may exist without current orders
or holdings because delisted reference data is retained. The unique
`(account_id, instrument_id)` key makes each holding one current position.
