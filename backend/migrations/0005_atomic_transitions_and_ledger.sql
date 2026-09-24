-- 0005_atomic_transitions_and_ledger.sql
-- Guarded atomic order state transitions to prevent concurrent double-processing

CREATE TRIGGER IF NOT EXISTS trg_order_status_transition_guard
BEFORE UPDATE OF status ON orders
FOR EACH ROW
BEGIN
    SELECT CASE
        -- Guard approval: can only transition from SUBMITTED to APPROVED
        WHEN NEW.status = 'APPROVED' AND OLD.status != 'SUBMITTED'
            THEN RAISE(ABORT, 'Order is not in SUBMITTED state for approval')
        -- Guard packing: can only transition from APPROVED or PICKING to PACKED
        WHEN NEW.status = 'PACKED' AND OLD.status NOT IN ('APPROVED', 'PICKING')
            THEN RAISE(ABORT, 'Order is not in APPROVED or PICKING state for packing')
        -- Guard dispatch: can only transition from PACKED to OUT_FOR_DELIVERY
        WHEN NEW.status = 'OUT_FOR_DELIVERY' AND OLD.status != 'PACKED'
            THEN RAISE(ABORT, 'Order is not in PACKED state for dispatch')
        -- Guard delivery: can only transition from OUT_FOR_DELIVERY to DELIVERED
        WHEN NEW.status = 'DELIVERED' AND OLD.status != 'OUT_FOR_DELIVERY'
            THEN RAISE(ABORT, 'Order is not in OUT_FOR_DELIVERY state for delivery')
        -- Guard rejection: can only transition from SUBMITTED or APPROVED to REJECTED
        WHEN NEW.status = 'REJECTED' AND OLD.status NOT IN ('SUBMITTED', 'APPROVED')
            THEN RAISE(ABORT, 'Order cannot be rejected in current state')
    END;
END;
