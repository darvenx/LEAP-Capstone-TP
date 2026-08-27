-- Cross-row domain rules that CHECK constraints cannot enforce.

CREATE OR REPLACE FUNCTION enforce_order_is_allowed()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    account_state account_status;
    instrument_tradable BOOLEAN;
BEGIN
    SELECT status INTO account_state
    FROM trading_accounts
    WHERE account_id = NEW.account_id;

    IF account_state <> 'ACTIVE' THEN
        RAISE EXCEPTION 'orders require an ACTIVE account' USING ERRCODE = '23514';
    END IF;

    -- Historical terminal orders may retain a delisted instrument.
    IF NEW.status <> 'NEW' THEN
        RETURN NEW;
    END IF;

    SELECT is_tradable INTO instrument_tradable
    FROM instruments
    WHERE instrument_id = NEW.instrument_id;

    IF NOT instrument_tradable THEN
        RAISE EXCEPTION 'orders require a tradable instrument' USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_require_active_account_and_tradable_instrument
BEFORE INSERT OR UPDATE OF account_id, instrument_id, status ON orders
FOR EACH ROW
EXECUTE FUNCTION enforce_order_is_allowed();

CREATE OR REPLACE FUNCTION prevent_terminal_order_reopen()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status IN ('FILLED', 'REJECTED', 'CANCELLED')
       AND NEW.status <> OLD.status THEN
        RAISE EXCEPTION 'terminal orders cannot change status' USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_terminal_status
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION prevent_terminal_order_reopen();
