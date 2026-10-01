-- 0014_product_batches_and_expiry.sql
-- Product batch tracking with expiry dates, rack/bin locations, and FEFO-aware stock.
-- Warehouse staff record batches when goods arrive (GRN).
-- Picking screen sorts by earliest expiry (FEFO) automatically.
-- products.stock_quantity remains the authoritative available total (aggregate of active batches).

-- 1. Product batches table
--    One row per physical batch (GRN / stock-in event).
CREATE TABLE IF NOT EXISTS product_batches (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    product_id TEXT NOT NULL,

    -- Identification
    batch_no TEXT NOT NULL,                    -- Manufacturer batch / lot number
    mfg_date INTEGER,                          -- Unix epoch (seconds) or NULL if not printed
    expiry_date INTEGER,                       -- Unix epoch (seconds); NULL = no-expiry item

    -- Location in warehouse
    rack_bin TEXT,                             -- e.g. "A3-Bin2"

    -- Quantities
    received_quantity INTEGER NOT NULL,        -- Quantity at GRN (immutable)
    remaining_quantity INTEGER NOT NULL,       -- Decremented on picking; never below 0
    committed_quantity INTEGER NOT NULL DEFAULT 0, -- Reserved for approved+pending-pick orders

    -- Status
    status TEXT NOT NULL DEFAULT 'ACTIVE',     -- ACTIVE | DEPLETED | EXPIRED | RECALLED

    -- Audit
    received_by TEXT NOT NULL,                 -- user id of WM who entered this GRN
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,

    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (received_by) REFERENCES users(id)
);

-- FEFO query index: sort batches by expiry ascending, then pick from the front
CREATE INDEX IF NOT EXISTS idx_batches_fefo
    ON product_batches(company_id, product_id, expiry_date ASC, remaining_quantity DESC)
    WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS idx_batches_company_product
    ON product_batches(company_id, product_id);

CREATE INDEX IF NOT EXISTS idx_batches_expiry_check
    ON product_batches(company_id, expiry_date)
    WHERE status = 'ACTIVE';

-- 2. Link picking actions to specific batches
--    order_items optionally references the batch actually picked.
ALTER TABLE order_items ADD COLUMN batch_id TEXT REFERENCES product_batches(id);
ALTER TABLE order_items ADD COLUMN batch_no TEXT;       -- Denormalised for delivery note print

-- 3. Track which batches contributed to a fulfilled order item (for partial picks across batches)
CREATE TABLE IF NOT EXISTS order_item_batch_picks (
    id TEXT PRIMARY KEY,
    order_item_id TEXT NOT NULL,
    batch_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    picked_at INTEGER NOT NULL,
    picked_by TEXT NOT NULL,
    FOREIGN KEY (order_item_id) REFERENCES order_items(id),
    FOREIGN KEY (batch_id) REFERENCES product_batches(id),
    FOREIGN KEY (picked_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_batch_picks_order_item ON order_item_batch_picks(order_item_id);
CREATE INDEX IF NOT EXISTS idx_batch_picks_batch ON order_item_batch_picks(batch_id);

-- 4. Expiry alert thresholds per company (defaults work without row in this table)
CREATE TABLE IF NOT EXISTS expiry_alert_config (
    company_id TEXT PRIMARY KEY,
    warn_days INTEGER NOT NULL DEFAULT 30,   -- Show orange warning if expiry within N days
    block_days INTEGER NOT NULL DEFAULT 7,   -- Block picking if expiry within N days
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- 5. Mark existing products as expiry-tracked or not
ALTER TABLE products ADD COLUMN tracks_expiry INTEGER NOT NULL DEFAULT 0; -- 1 = batch/expiry tracked
