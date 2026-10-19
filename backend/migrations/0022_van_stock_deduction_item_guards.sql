-- ============================================================================
-- 0022_van_stock_deduction_item_guards.sql
-- PROPOSED FORWARD MIGRATION — NOT YET EXECUTED
-- Status: Drafted during Phase 3.9 Pre-UI Backend Sign-off.
-- ============================================================================
-- Purpose:
-- 1. Upgrade van_stock_deductions to include product_id tracking.
-- 2. Add unique constraint on (order_id, allocation_id) to prevent duplicate
--    deduction records.
-- 3. Add composite indexes on trip_id and (order_id, product_id).
-- 4. Replace trg_van_stock_deduction_guard with comprehensive 7-point relational
--    guard enforcing:
--    - product_id presence
--    - tenant, trip, and product allocation match
--    - active allocation status ('ALLOCATED', 'IN_TRANSIT')
--    - remaining allocation stock
--    - order existence and tenant/trip match
--    - order_item existence for the specific product
--    - bounded order-item quantity across multiple batches/allocations
-- ============================================================================

-- 1. Add product_id column to van_stock_deductions (forward-compatible alter)
ALTER TABLE van_stock_deductions ADD COLUMN product_id TEXT REFERENCES products(id);

-- 2. Backfill product_id for any legacy rows from van_stock_allocations
UPDATE van_stock_deductions
SET product_id = (
    SELECT a.product_id 
    FROM van_stock_allocations a 
    WHERE a.id = van_stock_deductions.allocation_id
)
WHERE product_id IS NULL;

-- 3. Deduplicate legacy rows (preserving earliest) before applying unique index
DELETE FROM van_stock_deductions
WHERE id NOT IN (
    SELECT MIN(id)
    FROM van_stock_deductions
    GROUP BY order_id, allocation_id
);

-- 4. Add unique constraint on (order_id, allocation_id)
CREATE UNIQUE INDEX IF NOT EXISTS uq_van_stock_deduction_order_alloc 
ON van_stock_deductions(order_id, allocation_id);

-- 5. Add supporting indexes
CREATE INDEX IF NOT EXISTS idx_van_stock_deductions_trip 
ON van_stock_deductions(trip_id);

CREATE INDEX IF NOT EXISTS idx_van_stock_deductions_order_prod 
ON van_stock_deductions(order_id, product_id);

-- 6. Upgrade trg_van_stock_deduction_guard to full 7-point relational and quantity guard
DROP TRIGGER IF EXISTS trg_van_stock_deduction_guard;

CREATE TRIGGER trg_van_stock_deduction_guard
BEFORE INSERT ON van_stock_deductions
FOR EACH ROW
BEGIN
    -- 1. Ensure product_id is provided
    SELECT CASE
        WHEN NEW.product_id IS NULL OR length(trim(NEW.product_id)) = 0
        THEN RAISE(ABORT, 'Product ID is required for van stock deduction')
    END;

    -- 2. Ensure allocation row exists for this tenant, trip, and product
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM van_stock_allocations a
            WHERE a.id = NEW.allocation_id
              AND a.company_id = NEW.company_id
              AND a.trip_id = NEW.trip_id
              AND a.product_id = NEW.product_id
        )
        THEN RAISE(ABORT, 'Van stock allocation not found or trip/product mismatch for tenant')
    END;

    -- 3. Ensure allocation is active for delivery
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM van_stock_allocations a
            WHERE a.id = NEW.allocation_id
              AND a.company_id = NEW.company_id
              AND a.status IN ('ALLOCATED', 'IN_TRANSIT')
        )
        THEN RAISE(ABORT, 'Van stock allocation is not active for delivery')
    END;

    -- 4. Ensure sufficient stock remains on allocation row
    SELECT CASE
        WHEN (
            SELECT a.allocated_qty - a.delivered_qty
            FROM van_stock_allocations a
            WHERE a.id = NEW.allocation_id AND a.company_id = NEW.company_id
        ) < NEW.quantity
        THEN RAISE(ABORT, 'Insufficient van stock on allocation row')
    END;

    -- 5. Ensure order exists and belongs to the same tenant and vehicle trip
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM orders o
            WHERE o.id = NEW.order_id
              AND o.company_id = NEW.company_id
              AND (o.trip_id = NEW.trip_id OR o.van_trip_id = NEW.trip_id)
        )
        THEN RAISE(ABORT, 'Order not found or trip mismatch for van stock deduction')
    END;

    -- 6. Ensure order item exists for this order and product
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM order_items oi
            WHERE oi.order_id = NEW.order_id
              AND oi.product_id = NEW.product_id
        )
        THEN RAISE(ABORT, 'Order item not found for order and product')
    END;

    -- 7. Ensure total deductions for this order and product do not exceed total order item quantity
    SELECT CASE
        WHEN (
            COALESCE((SELECT SUM(d.quantity) FROM van_stock_deductions d
                      WHERE d.order_id = NEW.order_id AND d.product_id = NEW.product_id), 0) + NEW.quantity
        ) > (
            SELECT SUM(oi.quantity) FROM order_items oi
            WHERE oi.order_id = NEW.order_id AND oi.product_id = NEW.product_id
        )
        THEN RAISE(ABORT, 'Total deduction quantity exceeds order item quantity')
    END;
END;
