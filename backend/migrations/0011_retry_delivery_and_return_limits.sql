-- 0011_retry_delivery_and_return_limits.sql
-- Enables rescheduling & retry delivery dispatch and aligns customer return quantity limits with partial deliveries.

-- 1. Update order transition trigger to allow OUT_FOR_DELIVERY from DELIVERY_FAILED for retry dispatch
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

-- 2. Limit customer returns to actual delivered quantities (supporting PARTIALLY_DELIVERED)
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
