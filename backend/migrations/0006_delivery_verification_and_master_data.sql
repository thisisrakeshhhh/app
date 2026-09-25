-- 0006_delivery_verification_and_master_data.sql
-- Adds server-backed delivery OTP verification, shop visits, stock audit ledger, and master-data attributes

-- 1. Server-backed Delivery OTP table
CREATE TABLE IF NOT EXISTS delivery_otps (
    order_id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    otp_code TEXT NOT NULL,
    recipient_name TEXT,
    expires_at INTEGER NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    is_used INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (company_id) REFERENCES companies(id)
);
CREATE INDEX IF NOT EXISTS idx_delivery_otps_company ON delivery_otps(company_id);

-- 2. Delivery proof columns on orders
ALTER TABLE orders ADD COLUMN recipient_name TEXT;
ALTER TABLE orders ADD COLUMN proof_photo_url TEXT;
ALTER TABLE orders ADD COLUMN signature_url TEXT;

-- 3. Shop Visits table for field tracking and synchronization
CREATE TABLE IF NOT EXISTS visits (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    employee_id TEXT NOT NULL,
    check_in_time INTEGER NOT NULL,
    check_out_time INTEGER,
    latitude REAL,
    longitude REAL,
    accuracy REAL,
    duration_seconds INTEGER DEFAULT 0,
    status TEXT NOT NULL, -- ACTIVE, COMPLETED
    no_order_reason TEXT,
    notes TEXT,
    idempotency_key TEXT UNIQUE,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (employee_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_visits_employee ON visits(company_id, employee_id, check_in_time);
CREATE INDEX IF NOT EXISTS idx_visits_retailer ON visits(company_id, retailer_id);

-- 4. Audited Stock Adjustments & Receipts (Never silently overwrite stock)
CREATE TABLE IF NOT EXISTS stock_adjustments (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    change_quantity INTEGER NOT NULL,
    reason TEXT NOT NULL, -- STOCK_RECEIPT, DAMAGE, AUDIT_CORRECTION, RETURN_RESTOCK
    stock_after INTEGER NOT NULL,
    notes TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_stock_adj_product ON stock_adjustments(company_id, product_id, created_at);

-- 5. In-Store Retailer Stock Checks
CREATE TABLE IF NOT EXISTS stock_checks (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    employee_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (employee_id) REFERENCES users(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS idx_stock_checks_ret ON stock_checks(company_id, retailer_id, created_at);

-- 6. Product Master Data extensions (deactivation instead of deletion, SKU, MRP)
ALTER TABLE products ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;
ALTER TABLE products ADD COLUMN mrp_paise INTEGER NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN sku TEXT;

-- 7. Retailer Master Data extensions (deactivation instead of deletion, payment terms)
ALTER TABLE retailers ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;
ALTER TABLE retailers ADD COLUMN payment_terms_days INTEGER NOT NULL DEFAULT 7;
