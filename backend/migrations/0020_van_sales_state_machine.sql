-- ============================================================================
-- 0020_van_sales_state_machine.sql
-- PROPOSED FORWARD MIGRATION — NOT YET EXECUTED
-- Status: Drafted for architectural completeness during Phase 3.2 remediation.
-- ============================================================================
-- Purpose:
-- 1. Support the provisional van-sales lifecycle by updating
--    `trg_order_status_transition_guard` so that orders created as provisional
--    van sales (is_van_sale = 1, status = 'SUBMITTED') can transition directly
--    to 'DELIVERED' upon vehicle stock reconciliation/settlement, without
--    violating the warehouse dispatch pipeline (OUT_FOR_DELIVERY requirement).
-- 2. Add an explicit check index on van-sales order settlement.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_order_status_transition_guard;

CREATE TRIGGER trg_order_status_transition_guard
BEFORE UPDATE OF status ON orders
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NEW.status = 'APPROVED' AND OLD.status != 'SUBMITTED'
            THEN RAISE(ABORT, 'Order is not in SUBMITTED state for approval')
        WHEN NEW.status = 'PACKED' AND OLD.status NOT IN ('APPROVED', 'PICKING')
            THEN RAISE(ABORT, 'Order is not in APPROVED or PICKING state for packing')
        WHEN NEW.status = 'OUT_FOR_DELIVERY' AND OLD.status NOT IN ('PACKED', 'DELIVERY_FAILED', 'ASSIGNED_TO_TRIP', 'APPROVED')
            THEN RAISE(ABORT, 'Order is not in PACKED or DELIVERY_FAILED state for dispatch')
        -- Standard delivery requires OUT_FOR_DELIVERY; provisional van sales permit direct transition from SUBMITTED -> DELIVERED
        WHEN NEW.status IN ('DELIVERED', 'PARTIALLY_DELIVERED', 'DELIVERY_FAILED')
             AND OLD.status != 'OUT_FOR_DELIVERY'
             AND NOT (NEW.status = 'DELIVERED' AND OLD.is_van_sale = 1 AND OLD.status = 'SUBMITTED')
            THEN RAISE(ABORT, 'Order is not in valid precursor state for delivery')
        WHEN NEW.status = 'REJECTED' AND OLD.status NOT IN ('SUBMITTED', 'APPROVED')
            THEN RAISE(ABORT, 'Order cannot be rejected in current state')
    END;
END;

CREATE INDEX IF NOT EXISTS idx_orders_van_sale_provisional ON orders(company_id, is_van_sale, is_provisional, status);
