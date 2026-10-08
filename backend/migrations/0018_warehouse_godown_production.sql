-- 0018_warehouse_godown_production.sql
-- Production Blinkit-style Warehouse / Godown operations:
-- 1. Barcode and Image support on products
-- 2. Extended batch attributes (damaged_quantity, supplier, purchase price)
-- 3. Carton and package metadata on orders
-- 4. Dispatch Batches & Order groupings for delivery handover
-- 5. Stock movement ledger (audit trail of inward, audits, damaged, dispatch)
-- 6. Warehouse Return inspections (saleable vs damaged/expired)

-- 1. Add barcode and image key to products
ALTER TABLE products ADD COLUMN barcode TEXT;
ALTER TABLE products ADD COLUMN product_image_key TEXT;
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(company_id, barcode);

-- 2. Add extended attributes to product_batches
ALTER TABLE product_batches ADD COLUMN damaged_quantity INTEGER NOT NULL DEFAULT 0;
ALTER TABLE product_batches ADD COLUMN purchase_price_paise INTEGER;
ALTER TABLE product_batches ADD COLUMN supplier_name TEXT;

-- 3. Add carton and packaging fields to orders
ALTER TABLE orders ADD COLUMN cartons_count INTEGER NOT NULL DEFAULT 1;
ALTER TABLE orders ADD COLUMN package_photo_url TEXT;
ALTER TABLE orders ADD COLUMN package_weight_grams INTEGER;
ALTER TABLE orders ADD COLUMN packing_notes TEXT;
ALTER TABLE orders ADD COLUMN dispatch_batch_id TEXT;

-- 4. Dispatch Batches table
CREATE TABLE IF NOT EXISTS dispatch_batches (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    batch_code TEXT NOT NULL,
    delivery_executive_id TEXT,
    route_id TEXT,
    status TEXT NOT NULL DEFAULT 'CREATED', -- 'CREATED', 'PACKED', 'ASSIGNED', 'HANDED_OVER', 'IN_TRANSIT', 'COMPLETED'
    total_orders INTEGER NOT NULL DEFAULT 0,
    total_cartons INTEGER NOT NULL DEFAULT 0,
    created_by TEXT NOT NULL,
    notes TEXT,
    handed_over_at INTEGER,
    received_by_driver_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (delivery_executive_id) REFERENCES users(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_dispatch_batches_company ON dispatch_batches(company_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dispatch_batches_driver ON dispatch_batches(company_id, delivery_executive_id, status);

CREATE TABLE IF NOT EXISTS dispatch_batch_orders (
    dispatch_batch_id TEXT NOT NULL,
    order_id TEXT NOT NULL,
    cartons_count INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (dispatch_batch_id, order_id),
    FOREIGN KEY (dispatch_batch_id) REFERENCES dispatch_batches(id),
    FOREIGN KEY (order_id) REFERENCES orders(id)
);
CREATE INDEX IF NOT EXISTS idx_dispatch_batch_orders_order ON dispatch_batch_orders(order_id);

-- 5. Stock Movements Ledger
CREATE TABLE IF NOT EXISTS stock_movements (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    batch_id TEXT,
    movement_type TEXT NOT NULL, -- 'INWARD_GRN', 'AUDIT_CORRECTION', 'DAMAGED', 'EXPIRED', 'RETURNED_TO_GODOWN', 'MANUAL_CORRECTION', 'DISPATCH'
    quantity INTEGER NOT NULL,   -- positive for add, negative for deduction
    stock_before INTEGER NOT NULL,
    stock_after INTEGER NOT NULL,
    reason TEXT NOT NULL,
    notes TEXT,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_stock_movements_company_prod ON stock_movements(company_id, product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON stock_movements(company_id, movement_type);

-- 6. Warehouse Return Inspections
CREATE TABLE IF NOT EXISTS warehouse_return_inspections (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    return_id TEXT,
    order_id TEXT,
    retailer_id TEXT,
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    condition TEXT NOT NULL, -- 'SALEABLE', 'DAMAGED', 'EXPIRED', 'MISSING'
    photo_url TEXT,
    action_taken TEXT NOT NULL, -- 'RESTOCKED_TO_GODOWN', 'BLOCKED_DAMAGED', 'DISCARDED'
    notes TEXT,
    inspected_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (inspected_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_return_insp_company ON warehouse_return_inspections(company_id, created_at DESC);

-- Update default sample barcodes for seeded products if present
UPDATE products SET barcode = '8901030000001' WHERE id = 'P1' AND (barcode IS NULL OR barcode = '');
UPDATE products SET barcode = '8901030000002' WHERE id = 'P2' AND (barcode IS NULL OR barcode = '');
UPDATE products SET barcode = '8901030000003' WHERE id = 'P3' AND (barcode IS NULL OR barcode = '');
UPDATE products SET barcode = '8901030000004' WHERE id = 'P4' AND (barcode IS NULL OR barcode = '');
