-- 0010_partial_and_failed_deliveries.sql
-- Supports item-level partial deliveries, failed deliveries (shop closed, refused, damaged, shortage),
-- driver held stock tracking, warehouse return acknowledgement, and partial financial accounting.

-- 1. Order level delivery exception columns
ALTER TABLE orders ADD COLUMN delivery_failure_reason TEXT;
ALTER TABLE orders ADD COLUMN delivery_notes TEXT;
ALTER TABLE orders ADD COLUMN rescheduled_date TEXT;
ALTER TABLE orders ADD COLUMN delivered_amount_paise INTEGER DEFAULT 0;

-- 2. Item level delivery quantities
ALTER TABLE order_items ADD COLUMN delivered_quantity INTEGER DEFAULT 0;
ALTER TABLE order_items ADD COLUMN delivered_free_quantity INTEGER DEFAULT 0;
ALTER TABLE order_items ADD COLUMN undelivered_quantity INTEGER DEFAULT 0;
ALTER TABLE order_items ADD COLUMN undelivered_free_quantity INTEGER DEFAULT 0;
ALTER TABLE order_items ADD COLUMN undelivered_reason TEXT;

-- 3. Undelivered Goods tracking (driver held stock & warehouse return acknowledgement)
CREATE TABLE IF NOT EXISTS undelivered_goods (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    order_id TEXT NOT NULL REFERENCES orders(id),
    driver_id TEXT NOT NULL REFERENCES users(id),
    product_id TEXT NOT NULL REFERENCES products(id),
    undelivered_paid_quantity INTEGER NOT NULL CHECK(undelivered_paid_quantity >= 0),
    undelivered_free_quantity INTEGER NOT NULL CHECK(undelivered_free_quantity >= 0),
    reason TEXT NOT NULL CHECK(reason IN ('SHOP_CLOSED', 'REFUSED', 'DAMAGED', 'SHORTAGE', 'OTHER')),
    status TEXT NOT NULL CHECK(status IN ('HELD_BY_DRIVER', 'RETURNED_TO_WAREHOUSE', 'RESCHEDULED')),
    saleable_quantity INTEGER NOT NULL DEFAULT 0,
    damaged_quantity INTEGER NOT NULL DEFAULT 0,
    shortage_quantity INTEGER NOT NULL DEFAULT 0,
    acknowledged_by TEXT REFERENCES users(id),
    acknowledged_at INTEGER,
    rescheduled_for TEXT,
    notes TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

CREATE INDEX IF NOT EXISTS idx_undelivered_goods_driver ON undelivered_goods(company_id, driver_id, status);
CREATE INDEX IF NOT EXISTS idx_undelivered_goods_order ON undelivered_goods(order_id);
CREATE INDEX IF NOT EXISTS idx_undelivered_goods_company ON undelivered_goods(company_id, status);

-- 4. Update order transition trigger to support PARTIALLY_DELIVERED, DELIVERY_FAILED, and retry dispatch
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
        WHEN NEW.status = 'OUT_FOR_DELIVERY' AND OLD.status NOT IN ('PACKED', 'DELIVERY_FAILED')
            THEN RAISE(ABORT, 'Order is not in PACKED or DELIVERY_FAILED state for dispatch')
        WHEN NEW.status IN ('DELIVERED', 'PARTIALLY_DELIVERED', 'DELIVERY_FAILED') AND OLD.status != 'OUT_FOR_DELIVERY'
            THEN RAISE(ABORT, 'Order is not in OUT_FOR_DELIVERY state for delivery')
        WHEN NEW.status = 'REJECTED' AND OLD.status NOT IN ('SUBMITTED', 'APPROVED')
            THEN RAISE(ABORT, 'Order cannot be rejected in current state')
    END;
END;

-- 5. Release credit reservation on partial or failed delivery
DROP TRIGGER IF EXISTS release_order_credit;
CREATE TRIGGER release_order_credit AFTER UPDATE OF status ON orders
WHEN NEW.status IN ('REJECTED','CANCELLED','DELIVERED','PARTIALLY_DELIVERED','DELIVERY_FAILED')
BEGIN DELETE FROM credit_reservations WHERE order_id = NEW.id; END;

-- 6. Limit customer returns to actual delivered quantities (supporting PARTIALLY_DELIVERED)
DROP TRIGGER IF EXISTS return_quantity_guard;
CREATE TRIGGER return_quantity_guard BEFORE INSERT ON return_items BEGIN
 SELECT CASE WHEN typeof(NEW.requested_quantity) != 'integer' OR NEW.requested_quantity < 0
  OR typeof(NEW.free_quantity) != 'integer' OR NEW.free_quantity < 0
  OR NEW.requested_quantity + NEW.free_quantity <= 0 THEN RAISE(ABORT, 'Invalid return quantity') END;
 SELECT CASE WHEN NOT EXISTS (
 SELECT 1 FROM return_requests r JOIN orders o ON o.id = r.order_id
 WHERE r.id = NEW.return_id AND o.status IN ('DELIVERED', 'PARTIALLY_DELIVERED') AND r.company_id = o.company_id
 AND NEW.requested_quantity + COALESCE((SELECT SUM(ri.requested_quantity) FROM return_items ri
  JOIN return_requests rr ON rr.id = ri.return_id WHERE rr.order_id = o.id AND ri.product_id = NEW.product_id
  AND rr.status NOT IN ('REJECTED','REVERSED')),0)
 <= COALESCE((SELECT SUM(CASE WHEN o.status = 'PARTIALLY_DELIVERED' THEN delivered_quantity ELSE COALESCE(NULLIF(delivered_quantity,0), quantity) END) FROM order_items WHERE order_id = o.id AND product_id = NEW.product_id),0)
 AND NEW.free_quantity + COALESCE((SELECT SUM(ri.free_quantity) FROM return_items ri
  JOIN return_requests rr ON rr.id = ri.return_id WHERE rr.order_id = o.id AND ri.product_id = NEW.product_id
  AND rr.status NOT IN ('REJECTED','REVERSED')),0)
 <= COALESCE((SELECT SUM(CASE WHEN o.status = 'PARTIALLY_DELIVERED' THEN delivered_free_quantity ELSE COALESCE(NULLIF(delivered_free_quantity,0), free_quantity) END) FROM order_items WHERE order_id = o.id AND product_id = NEW.product_id),0)
 ) THEN RAISE(ABORT, 'Return exceeds remaining delivered quantity') END;
END;

