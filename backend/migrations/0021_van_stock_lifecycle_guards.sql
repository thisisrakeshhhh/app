-- ============================================================================
-- 0021_van_stock_lifecycle_guards.sql
-- PROPOSED FORWARD MIGRATION — NOT YET EXECUTED
-- Status: Drafted during Phase 3.4.1 / 3.5 / 3.7 static remediation.
-- ============================================================================
-- Purpose:
-- 1. Enforce van stock allocation status invariants via database trigger:
--    Prevent updates to delivered quantities on allocations that are already
--    reconciled or in an invalid operational status.
-- 2. Enforce atomic credit limits on direct van-sale spot-bills:
--    A database trigger on orders BEFORE INSERT ensures that immediate DELIVERED
--    credit orders abort the entire batch if the retailer's total exposure
--    (outstanding + existing open reservations + new order amount) exceeds
--    their credit limit plus any authorized override for this specific order.
-- 3. Add composite index on van stock allocations by company, trip, and status
--    to optimize settlement and reconciliation queries.
-- 4. Van Stock Deductions Ledger & Zero-Row Guard:
--    An immutable deduction ledger ensuring that vehicle stock consumption is
--    enforced via INSERT triggers, guaranteeing that a missing allocation or
--    tenant mismatch triggers an immediate RAISE(ABORT), preventing silent
--    zero-row update commits in Cloudflare D1 batches.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_van_stock_allocation_status_guard;

CREATE TRIGGER trg_van_stock_allocation_status_guard
BEFORE UPDATE OF delivered_qty ON van_stock_allocations
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN OLD.status NOT IN ('ALLOCATED', 'IN_TRANSIT')
            THEN RAISE(ABORT, 'Cannot deliver from inactive or reconciled van stock allocation')
    END;
END;

DROP TRIGGER IF EXISTS trg_spot_bill_credit_guard;

CREATE TRIGGER trg_spot_bill_credit_guard
BEFORE INSERT ON orders
FOR EACH ROW
WHEN NEW.status = 'DELIVERED' AND NEW.payment_method = 'CREDIT'
BEGIN
    -- 1. Fail closed if retailer does not exist for the active company
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM retailers r
            WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id
        )
        THEN RAISE(ABORT, 'Retailer not found for active organization')
    END;

    -- 2. Fail closed on negative amounts
    SELECT CASE
        WHEN COALESCE(NEW.total_amount_paise, 0) < 0
        THEN RAISE(ABORT, 'Order total amount cannot be negative')
        WHEN COALESCE(NEW.credit_override_paise, 0) < 0
        THEN RAISE(ABORT, 'Credit override cannot be negative')
    END;

    -- 3. Fail closed if total credit exposure exceeds limit
    SELECT CASE
        WHEN (
            SELECT COALESCE(r.outstanding_amount_paise, 0) 
                 + COALESCE((SELECT SUM(cr.amount_paise) FROM credit_reservations cr 
                             WHERE cr.retailer_id = NEW.retailer_id AND cr.company_id = NEW.company_id), 0)
                 + COALESCE(NEW.total_amount_paise, 0)
            FROM retailers r
            WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id
        ) > (
            SELECT COALESCE(r.credit_limit_paise, 0) + COALESCE(NEW.credit_override_paise, 0)
            FROM retailers r
            WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id
        )
        THEN RAISE(ABORT, 'Credit exposure exceeds limit on spot-bill')
    END;
END;

CREATE INDEX IF NOT EXISTS idx_van_stock_company_trip_status 
ON van_stock_allocations(company_id, trip_id, status);

-- 4. Van Stock Deductions Ledger (Atomic zero-row abort guard & audit trail)
CREATE TABLE IF NOT EXISTS van_stock_deductions (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    trip_id TEXT NOT NULL,
    allocation_id TEXT NOT NULL,
    order_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (trip_id) REFERENCES delivery_trips(id),
    FOREIGN KEY (allocation_id) REFERENCES van_stock_allocations(id),
    FOREIGN KEY (order_id) REFERENCES orders(id)
);
CREATE INDEX IF NOT EXISTS idx_van_stock_deductions_alloc ON van_stock_deductions(allocation_id);
CREATE INDEX IF NOT EXISTS idx_van_stock_deductions_order ON van_stock_deductions(order_id);

DROP TRIGGER IF EXISTS trg_van_stock_deduction_guard;
CREATE TRIGGER trg_van_stock_deduction_guard
BEFORE INSERT ON van_stock_deductions
FOR EACH ROW
BEGIN
    -- 1. Ensure allocation row exists for this tenant
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM van_stock_allocations a
            WHERE a.id = NEW.allocation_id AND a.company_id = NEW.company_id
        )
        THEN RAISE(ABORT, 'Van stock allocation not found for tenant')
    END;

    -- 2. Ensure allocation is active for delivery
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM van_stock_allocations a
            WHERE a.id = NEW.allocation_id AND a.company_id = NEW.company_id
            AND a.status IN ('ALLOCATED', 'IN_TRANSIT')
        )
        THEN RAISE(ABORT, 'Van stock allocation is not active for delivery')
    END;

    -- 3. Ensure sufficient stock remains on allocation row
    SELECT CASE
        WHEN (
            SELECT a.allocated_qty - a.delivered_qty
            FROM van_stock_allocations a
            WHERE a.id = NEW.allocation_id AND a.company_id = NEW.company_id
        ) < NEW.quantity
        THEN RAISE(ABORT, 'Insufficient van stock on allocation row')
    END;
END;

DROP TRIGGER IF EXISTS trg_van_stock_deduction_apply;
CREATE TRIGGER trg_van_stock_deduction_apply
AFTER INSERT ON van_stock_deductions
FOR EACH ROW
BEGIN
    UPDATE van_stock_allocations
    SET delivered_qty = delivered_qty + NEW.quantity,
        updated_at = NEW.created_at
    WHERE id = NEW.allocation_id AND company_id = NEW.company_id;
END;


