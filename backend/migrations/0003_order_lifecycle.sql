-- 0003_order_lifecycle.sql
-- Add delivery_employee_id, rejection_reason, and payment_method to orders
ALTER TABLE orders ADD COLUMN delivery_employee_id TEXT;
ALTER TABLE orders ADD COLUMN rejection_reason TEXT;
ALTER TABLE orders ADD COLUMN payment_method TEXT;
ALTER TABLE refresh_tokens ADD COLUMN revoked_at INTEGER;

CREATE INDEX IF NOT EXISTS idx_orders_company_status ON orders(company_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_emp ON orders(delivery_employee_id);

-- Enforce strict inventory invariants at the database level to prevent race conditions
CREATE TRIGGER IF NOT EXISTS trg_check_product_reservation
BEFORE UPDATE OF reserved_quantity ON products
FOR EACH ROW
WHEN NEW.reserved_quantity > NEW.stock_quantity
BEGIN
    SELECT RAISE(ABORT, 'Insufficient stock available to reserve');
END;

CREATE TRIGGER IF NOT EXISTS trg_check_product_stock
BEFORE UPDATE OF stock_quantity ON products
FOR EACH ROW
WHEN NEW.stock_quantity < 0
BEGIN
    SELECT RAISE(ABORT, 'Stock cannot be negative');
END;
