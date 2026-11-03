-- 0026_overselling_protection_trigger.sql
-- RouteFlow Phase C: Atomic Overselling Protection Trigger

CREATE TRIGGER IF NOT EXISTS trg_products_prevent_overselling
BEFORE UPDATE OF reserved_quantity ON products
FOR EACH ROW
WHEN NEW.reserved_quantity > NEW.stock_quantity
BEGIN
    SELECT RAISE(ABORT, 'INSUFFICIENT_STOCK: reserved_quantity cannot exceed stock_quantity');
END;
