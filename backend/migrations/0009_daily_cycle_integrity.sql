-- Additive migration. Existing payments remain booked; legacy non-cash entries
-- are explicitly marked for review, never silently undone or deleted.
ALTER TABLE collections ADD COLUMN status TEXT NOT NULL DEFAULT 'LEGACY_SETTLED';
ALTER TABLE collections ADD COLUMN reference TEXT;
ALTER TABLE collections ADD COLUMN unapplied_paise INTEGER NOT NULL DEFAULT 0;
ALTER TABLE collections ADD COLUMN updated_at INTEGER;
ALTER TABLE collections ADD COLUMN reviewed_by TEXT;
ALTER TABLE collections ADD COLUMN review_reason TEXT;
UPDATE collections SET status = CASE WHEN payment_method = 'CASH' THEN 'SETTLED' ELSE 'LEGACY_REVIEW' END,
 unapplied_paise = amount_paise, updated_at = created_at;
ALTER TABLE invoices ADD COLUMN paid_paise INTEGER NOT NULL DEFAULT 0;
ALTER TABLE invoices ADD COLUMN credited_paise INTEGER NOT NULL DEFAULT 0;
UPDATE invoices SET paid_paise = total_amount_paise WHERE status = 'PAID';
CREATE TRIGGER invoice_initial_payment AFTER INSERT ON invoices WHEN NEW.status = 'PAID'
BEGIN UPDATE invoices SET paid_paise = total_amount_paise WHERE id = NEW.id; END;
CREATE TABLE collection_allocations (
 collection_id TEXT NOT NULL REFERENCES collections(id), invoice_id TEXT NOT NULL REFERENCES invoices(id),
 amount_paise INTEGER NOT NULL CHECK(typeof(amount_paise) = 'integer' AND amount_paise > 0),
 PRIMARY KEY(collection_id, invoice_id)
);
CREATE TRIGGER allocation_guard BEFORE INSERT ON collection_allocations BEGIN
 SELECT CASE WHEN NOT EXISTS (
  SELECT 1 FROM invoices i JOIN collections c ON c.id = NEW.collection_id
  WHERE i.id = NEW.invoice_id AND i.company_id = c.company_id AND i.retailer_id = c.retailer_id
  AND NEW.amount_paise <= i.total_amount_paise - i.paid_paise - i.credited_paise
 ) THEN RAISE(ABORT, 'Invoice allocation exceeds unpaid balance') END;
END;
CREATE TRIGGER collection_transition BEFORE UPDATE OF status ON collections BEGIN
 SELECT CASE WHEN NOT (
  (OLD.status = 'ENTERED' AND NEW.status IN ('VERIFIED','CLEARED','REJECTED','SETTLED')) OR
  (OLD.status IN ('SETTLED','VERIFIED','CLEARED','LEGACY_REVIEW') AND NEW.status = 'REVERSED')
 ) THEN RAISE(ABORT, 'Collection transition already applied or invalid') END;
END;
CREATE TABLE operation_receipts (
 id TEXT PRIMARY KEY, company_id TEXT NOT NULL, actor_id TEXT NOT NULL, operation TEXT NOT NULL,
 request_hash TEXT NOT NULL, response TEXT NOT NULL, created_at INTEGER NOT NULL
);

-- Credit is reserved at submission (payment mode is only known at delivery).
-- Existing open orders are included, even if they already exceed today's limit.
ALTER TABLE orders ADD COLUMN credit_override_paise INTEGER NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN credit_override_reason TEXT;
ALTER TABLE orders ADD COLUMN credit_override_by TEXT;
CREATE TABLE credit_reservations (
 order_id TEXT PRIMARY KEY REFERENCES orders(id), company_id TEXT NOT NULL,
 retailer_id TEXT NOT NULL REFERENCES retailers(id), amount_paise INTEGER NOT NULL CHECK(amount_paise >= 0)
);
INSERT INTO credit_reservations SELECT id, company_id, retailer_id, total_amount_paise FROM orders
 WHERE status IN ('SUBMITTED','APPROVED','PICKING','PACKED','OUT_FOR_DELIVERY');
CREATE TRIGGER reserve_order_credit AFTER INSERT ON orders WHEN NEW.status = 'SUBMITTED' BEGIN
 SELECT CASE WHEN (SELECT outstanding_amount_paise + COALESCE((SELECT SUM(amount_paise) FROM credit_reservations
  WHERE retailer_id = NEW.retailer_id AND company_id = NEW.company_id), 0) + NEW.total_amount_paise
  > credit_limit_paise + NEW.credit_override_paise FROM retailers WHERE id = NEW.retailer_id AND company_id = NEW.company_id)
 THEN RAISE(ABORT, 'Credit exposure exceeds limit') END;
 INSERT INTO credit_reservations VALUES(NEW.id, NEW.company_id, NEW.retailer_id, NEW.total_amount_paise);
END;
CREATE TRIGGER release_order_credit AFTER UPDATE OF status ON orders WHEN NEW.status IN ('REJECTED','CANCELLED','DELIVERED')
BEGIN DELETE FROM credit_reservations WHERE order_id = NEW.id; END;

ALTER TABLE return_requests ADD COLUMN authorized_by TEXT;
ALTER TABLE return_requests ADD COLUMN received_by TEXT;
ALTER TABLE return_requests ADD COLUMN received_at INTEGER;
ALTER TABLE return_requests ADD COLUMN credited_by TEXT;
ALTER TABLE return_requests ADD COLUMN credited_at INTEGER;
ALTER TABLE return_requests ADD COLUMN credit_paise INTEGER NOT NULL DEFAULT 0;
ALTER TABLE return_items ADD COLUMN free_quantity INTEGER NOT NULL DEFAULT 0;
ALTER TABLE return_items ADD COLUMN saleable_free_quantity INTEGER NOT NULL DEFAULT 0;
ALTER TABLE return_items ADD COLUMN damaged_free_quantity INTEGER NOT NULL DEFAULT 0;
-- Preserve legacy pending requests; their original intent already authorized receipt.
UPDATE return_requests SET status = 'AUTHORIZED' WHERE status = 'PENDING_INSPECTION';
CREATE TRIGGER return_quantity_guard BEFORE INSERT ON return_items BEGIN
 SELECT CASE WHEN typeof(NEW.requested_quantity) != 'integer' OR NEW.requested_quantity < 0
  OR typeof(NEW.free_quantity) != 'integer' OR NEW.free_quantity < 0
  OR NEW.requested_quantity + NEW.free_quantity <= 0 THEN RAISE(ABORT, 'Invalid return quantity') END;
 SELECT CASE WHEN NOT EXISTS (
 SELECT 1 FROM return_requests r JOIN orders o ON o.id = r.order_id
 WHERE r.id = NEW.return_id AND o.status = 'DELIVERED' AND r.company_id = o.company_id
 AND NEW.requested_quantity + COALESCE((SELECT SUM(ri.requested_quantity) FROM return_items ri
  JOIN return_requests rr ON rr.id = ri.return_id WHERE rr.order_id = o.id AND ri.product_id = NEW.product_id
  AND rr.status NOT IN ('REJECTED','REVERSED')),0)
 <= COALESCE((SELECT SUM(quantity) FROM order_items WHERE order_id = o.id AND product_id = NEW.product_id),0)
 AND NEW.free_quantity + COALESCE((SELECT SUM(ri.free_quantity) FROM return_items ri
  JOIN return_requests rr ON rr.id = ri.return_id WHERE rr.order_id = o.id AND ri.product_id = NEW.product_id
  AND rr.status NOT IN ('REJECTED','REVERSED')),0)
 <= COALESCE((SELECT SUM(free_quantity) FROM order_items WHERE order_id = o.id AND product_id = NEW.product_id),0)
 ) THEN RAISE(ABORT, 'Return exceeds remaining delivered quantity') END;
END;
CREATE TRIGGER return_transition BEFORE UPDATE OF status ON return_requests BEGIN
 SELECT CASE WHEN NOT (
 (OLD.status = 'REQUESTED' AND NEW.status IN ('AUTHORIZED','REJECTED')) OR
 (OLD.status = 'AUTHORIZED' AND NEW.status IN ('RECEIVED','REJECTED')) OR
 (OLD.status = 'RECEIVED' AND NEW.status = 'INSPECTED') OR
 (OLD.status = 'INSPECTED' AND NEW.status = 'CREDITED')
 ) THEN RAISE(ABORT, 'Return transition already applied or invalid') END;
END;
CREATE TABLE return_credit_notes (
 return_id TEXT PRIMARY KEY REFERENCES return_requests(id), company_id TEXT NOT NULL,
 invoice_id TEXT NOT NULL REFERENCES invoices(id), amount_paise INTEGER NOT NULL CHECK(amount_paise >= 0),
 created_by TEXT NOT NULL, created_at INTEGER NOT NULL
);

ALTER TABLE cash_handovers ADD COLUMN expected_amount_paise INTEGER;
ALTER TABLE cash_handovers ADD COLUMN resolution_notes TEXT;
CREATE TRIGGER handover_insert_guard BEFORE INSERT ON cash_handovers BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM cash_handovers WHERE company_id = NEW.company_id
 AND user_id = NEW.user_id AND status = 'PENDING') THEN RAISE(ABORT, 'Pending handover exists') END;
 SELECT CASE WHEN NEW.amount_paise <= 0 OR typeof(NEW.amount_paise) != 'integer' OR NEW.amount_paise >
 COALESCE((SELECT SUM(CASE WHEN entry_type = 'CASH_REVERSAL' THEN -amount_paise ELSE amount_paise END)
 FROM payment_ledger WHERE company_id = NEW.company_id AND collected_by = NEW.user_id
 AND entry_type IN ('CASH_PAYMENT','CASH_REVERSAL')),0) -
 COALESCE((SELECT SUM(received_amount_paise) FROM cash_handovers WHERE company_id = NEW.company_id
 AND user_id = NEW.user_id AND status = 'ACCEPTED'),0)
 THEN RAISE(ABORT, 'Handover exceeds cash custody') END;
END;
CREATE TRIGGER handover_transition BEFORE UPDATE OF status ON cash_handovers BEGIN
 SELECT CASE WHEN OLD.status != 'PENDING' OR NEW.status NOT IN ('ACCEPTED','REJECTED')
 THEN RAISE(ABORT, 'Handover already acknowledged') END;
 SELECT CASE WHEN NEW.status = 'ACCEPTED' AND (NEW.received_amount_paise < 0 OR
 NEW.received_amount_paise > NEW.amount_paise OR typeof(NEW.received_amount_paise) != 'integer')
 THEN RAISE(ABORT, 'Invalid accepted cash amount') END;
END;
CREATE TABLE daily_closings (
 id TEXT PRIMARY KEY, company_id TEXT NOT NULL, business_date TEXT NOT NULL,
 closed_by TEXT NOT NULL, closed_at INTEGER NOT NULL, snapshot TEXT NOT NULL, notes TEXT NOT NULL,
 UNIQUE(company_id, business_date)
);
CREATE TRIGGER active_visit_guard BEFORE INSERT ON visits WHEN NEW.status = 'ACTIVE' BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM visits WHERE company_id = NEW.company_id AND employee_id = NEW.employee_id
 AND status = 'ACTIVE' AND id != NEW.id) THEN RAISE(ABORT, 'Active visit already exists') END;
END;
CREATE TRIGGER active_shift_guard BEFORE INSERT ON shifts WHEN NEW.status IN ('ON_SHIFT','ON_BREAK') BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM shifts WHERE company_id = NEW.company_id AND user_id = NEW.user_id
 AND status IN ('ON_SHIFT','ON_BREAK') AND id != NEW.id) THEN RAISE(ABORT, 'Active shift already exists') END;
END;
ALTER TABLE delivery_otps ADD COLUMN send_status TEXT NOT NULL DEFAULT 'UNAVAILABLE';
ALTER TABLE delivery_otps ADD COLUMN provider_id TEXT;
CREATE TABLE shift_breaks (id TEXT PRIMARY KEY, shift_id TEXT NOT NULL REFERENCES shifts(id),
 start_time INTEGER NOT NULL, end_time INTEGER);
CREATE TRIGGER release_rejected_stock AFTER UPDATE OF status ON orders
 WHEN NEW.status='REJECTED' AND OLD.status='APPROVED'
BEGIN
 UPDATE products SET reserved_quantity=reserved_quantity-COALESCE((SELECT SUM(quantity+free_quantity)
 FROM order_items WHERE order_id=NEW.id AND product_id=products.id),0)
 WHERE company_id=NEW.company_id AND id IN (SELECT product_id FROM order_items WHERE order_id=NEW.id);
END;
CREATE TRIGGER otp_claim_guard BEFORE UPDATE OF is_used ON delivery_otps WHEN NEW.is_used=1 BEGIN
 SELECT CASE WHEN OLD.is_used=1 OR OLD.attempt_count>=OLD.max_attempts OR OLD.expires_at<CAST(strftime('%s','now') AS INTEGER)*1000
 THEN RAISE(ABORT,'OTP expired, exhausted or already used') END;
END;
CREATE TRIGGER visit_checkout_guard BEFORE UPDATE OF status ON visits WHEN NEW.status='COMPLETED' BEGIN
 SELECT CASE WHEN OLD.status!='ACTIVE' THEN RAISE(ABORT,'Visit already completed') END;
END;
