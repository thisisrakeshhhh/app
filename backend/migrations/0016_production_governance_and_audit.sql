-- 0016_production_governance_and_audit.sql
-- Production Governance, Role Permissions, Suppliers, Goods Receipt Notes (GRN),
-- Extended Audit Logging, and Multi-Status Payment Verification Lifecycle.

-- 1. Role permissions table for customizable access control
CREATE TABLE IF NOT EXISTS role_permissions (
    company_id TEXT NOT NULL,
    role TEXT NOT NULL,
    can_approve_orders INTEGER NOT NULL DEFAULT 1,
    can_edit_stock INTEGER NOT NULL DEFAULT 1,
    can_give_discount INTEGER NOT NULL DEFAULT 0,
    can_reverse_payment INTEGER NOT NULL DEFAULT 0,
    max_discount_pct REAL NOT NULL DEFAULT 5.0,
    updated_at INTEGER NOT NULL,
    updated_by TEXT,
    PRIMARY KEY (company_id, role),
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- 2. Enhanced Audit Logging columns (device_id, ip_address, role)
ALTER TABLE audit_logs ADD COLUMN role TEXT;
ALTER TABLE audit_logs ADD COLUMN device_id TEXT;
ALTER TABLE audit_logs ADD COLUMN ip_address TEXT;

CREATE INDEX IF NOT EXISTS idx_audit_logs_company_time ON audit_logs(company_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(company_id, action);

-- 3. Suppliers table for wholesale procurement / GRN
CREATE TABLE IF NOT EXISTS suppliers (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    name TEXT NOT NULL,
    contact_number TEXT,
    email TEXT,
    gstin TEXT,
    address TEXT,
    city TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id)
);
CREATE INDEX IF NOT EXISTS idx_suppliers_company ON suppliers(company_id);

-- 4. Goods Receipt Notes (GRN) / Inward Stock Entry
CREATE TABLE IF NOT EXISTS goods_receipt_notes (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    supplier_id TEXT NOT NULL,
    warehouse_id TEXT,
    invoice_number TEXT,
    invoice_date INTEGER,
    status TEXT NOT NULL DEFAULT 'PENDING_APPROVAL', -- PENDING_APPROVAL, APPROVED, REJECTED
    total_amount_paise INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    received_by TEXT NOT NULL,
    approved_by TEXT,
    created_at INTEGER NOT NULL,
    approved_at INTEGER,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    FOREIGN KEY (received_by) REFERENCES users(id),
    FOREIGN KEY (approved_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_grn_company ON goods_receipt_notes(company_id, created_at DESC);

-- 5. GRN Line Items
CREATE TABLE IF NOT EXISTS grn_items (
    id TEXT PRIMARY KEY,
    grn_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    batch_no TEXT,
    quantity_received INTEGER NOT NULL,
    unit_cost_paise INTEGER NOT NULL,
    mfg_date INTEGER,
    expiry_date INTEGER,
    rack_bin TEXT,
    FOREIGN KEY (grn_id) REFERENCES goods_receipt_notes(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS idx_grn_items_grn ON grn_items(grn_id);

-- 6. Collections table enhancements for verification lifecycle
ALTER TABLE collections ADD COLUMN verified_by TEXT REFERENCES users(id);
ALTER TABLE collections ADD COLUMN verified_at INTEGER;
ALTER TABLE collections ADD COLUMN cleared_at INTEGER;
