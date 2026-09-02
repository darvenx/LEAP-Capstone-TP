-- =============================================================================
-- 016_integrity_guards.sql
-- Cross-row rules that a single-column CHECK cannot express. These are
-- database-enforced so Sprint 6/7 cannot write an inconsistent state even
-- through a bug: an order may only be opened against an ACTIVE account, a
-- working (NEW) order may only reference a tradable instrument, and a terminal
-- order's status is final.
--
-- The cash-ledger entry-sign CHECK lives on the table itself (008).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- orders: an order may only be opened against an ACTIVE account, and a working
-- (NEW) order may only reference a tradable instrument. Terminal orders are
-- exempt from the tradable check so history that references a later-delisted
-- instrument stays insertable (rule: delist is a flag, never a delete).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_order_is_allowed()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    account_state       account_status;
    instrument_tradable BOOLEAN;
BEGIN
    SELECT status INTO account_state
    FROM accounts
    WHERE id = NEW.account_id;

    IF account_state <> 'ACTIVE' THEN
        RAISE EXCEPTION 'orders require an ACTIVE account (account_id=%)', NEW.account_id
            USING ERRCODE = '23514';
    END IF;

    -- Historical terminal orders may retain a since-delisted instrument.
    IF NEW.status <> 'NEW' THEN
        RETURN NEW;
    END IF;

    SELECT tradable INTO instrument_tradable
    FROM instruments
    WHERE id = NEW.instrument_id;

    IF NOT instrument_tradable THEN
        RAISE EXCEPTION 'a working (NEW) order requires a tradable instrument (instrument_id=%)', NEW.instrument_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_require_active_account_and_tradable_instrument
    BEFORE INSERT OR UPDATE OF account_id, instrument_id, status ON orders
    FOR EACH ROW
    EXECUTE FUNCTION enforce_order_is_allowed();


-- -----------------------------------------------------------------------------
-- orders: a terminal order (FILLED / REJECTED / CANCELLED) is final. Its status
-- must never change again. This makes the "exactly one terminal state" domain
-- rule a database guarantee, not just an application convention.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION prevent_terminal_order_reopen()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status IN ('FILLED', 'REJECTED', 'CANCELLED')
       AND NEW.status <> OLD.status THEN
        RAISE EXCEPTION 'a terminal order cannot change status (% -> %)', OLD.status, NEW.status
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_terminal_status
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION prevent_terminal_order_reopen();
