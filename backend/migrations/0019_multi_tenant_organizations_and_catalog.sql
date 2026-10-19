-- 0019_multi_tenant_organizations_and_catalog.sql
-- Enterprise Multi-Tenancy, Global FMCG Catalog, Van Stock Ledgers, GST Breakdown, Retailer Ledgers & Credit Policies

-- 1. Organizations table
CREATE TABLE IF NOT EXISTS organizations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    legal_name TEXT,
    gstin TEXT,
    fssai_license TEXT,
    state_code TEXT NOT NULL DEFAULT '07',
    currency TEXT NOT NULL DEFAULT 'INR',
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_organizations_active ON organizations(is_active);

-- 2. Organization Memberships table (supports both canonical and legacy role names)
CREATE TABLE IF NOT EXISTS organization_memberships (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('OWNER', 'ADMIN', 'SALES', 'SALESPERSON', 'WAREHOUSE', 'WAREHOUSE_MANAGER', 'DELIVERY', 'DELIVERY_EXECUTIVE', 'RETAILER')),
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(organization_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_org_memberships_user ON organization_memberships(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_org_memberships_org ON organization_memberships(organization_id, is_active);

-- 3. Global Catalog Brands table
CREATE TABLE IF NOT EXISTS catalog_brands (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    manufacturer TEXT,
    logo_url TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_catalog_brands_active ON catalog_brands(name, is_active);

-- 4. Global Catalog Products / SKUs table
CREATE TABLE IF NOT EXISTS catalog_products (
    id TEXT PRIMARY KEY,
    brand_id TEXT,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    hsn_code TEXT NOT NULL,
    barcode TEXT UNIQUE,
    base_unit TEXT NOT NULL DEFAULT 'PIECE',
    description TEXT,
    image_url TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (brand_id) REFERENCES catalog_brands(id)
);
CREATE INDEX IF NOT EXISTS idx_catalog_products_barcode ON catalog_products(barcode);
CREATE INDEX IF NOT EXISTS idx_catalog_products_category ON catalog_products(category, is_active);

-- 5. Tenant Catalog Mappings table (Distributor custom pricing & margins)
CREATE TABLE IF NOT EXISTS tenant_catalog_mappings (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    catalog_product_id TEXT NOT NULL,
    custom_sku TEXT,
    wholesale_rate_paise INTEGER NOT NULL,
    mrp_paise INTEGER NOT NULL,
    purchase_price_paise INTEGER,
    gst_rate REAL NOT NULL DEFAULT 18.0,
    min_order_qty INTEGER NOT NULL DEFAULT 1,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (catalog_product_id) REFERENCES catalog_products(id),
    UNIQUE(company_id, catalog_product_id)
);
CREATE INDEX IF NOT EXISTS idx_tenant_catalog_company ON tenant_catalog_mappings(company_id, is_active);

-- 6. Van Stock Allocations (Logistics & Consignment Custody)
CREATE TABLE IF NOT EXISTS van_stock_allocations (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    trip_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    batch_id TEXT,
    allocated_qty INTEGER NOT NULL CHECK(allocated_qty >= 0),
    delivered_qty INTEGER NOT NULL DEFAULT 0 CHECK(delivered_qty >= 0 AND delivered_qty <= allocated_qty),
    returned_qty INTEGER NOT NULL DEFAULT 0 CHECK(returned_qty >= 0),
    damaged_qty INTEGER NOT NULL DEFAULT 0 CHECK(damaged_qty >= 0),
    status TEXT NOT NULL DEFAULT 'ALLOCATED' CHECK(status IN ('ALLOCATED', 'IN_TRANSIT', 'RECONCILED')),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (trip_id) REFERENCES delivery_trips(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (batch_id) REFERENCES product_batches(id)
);
CREATE INDEX IF NOT EXISTS idx_van_stock_trip ON van_stock_allocations(trip_id, status);
CREATE INDEX IF NOT EXISTS idx_van_stock_product ON van_stock_allocations(company_id, product_id);

-- Enforce van stock non-negative and non-exceeding delivered allocation via trigger
DROP TRIGGER IF EXISTS trg_van_stock_allocation_guard;
CREATE TRIGGER trg_van_stock_allocation_guard
BEFORE UPDATE OF delivered_qty, allocated_qty ON van_stock_allocations
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NEW.delivered_qty > NEW.allocated_qty
            THEN RAISE(ABORT, 'Van stock delivered quantity cannot exceed allocated quantity')
        WHEN NEW.delivered_qty < 0
            THEN RAISE(ABORT, 'Van stock delivered quantity cannot be negative')
    END;
END;

-- 7. Retailer Double-Entry Khata Ledgers (Referencing retailers table correctly)
CREATE TABLE IF NOT EXISTS retailer_ledgers (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    entry_type TEXT NOT NULL CHECK(entry_type IN ('INVOICE_DEBIT', 'PAYMENT_CREDIT', 'RETURN_CREDIT', 'ADJUSTMENT')),
    reference_id TEXT,
    amount_paise INTEGER NOT NULL,
    running_balance_paise INTEGER NOT NULL,
    notes TEXT,
    created_by TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_retailer_ledgers_retailer ON retailer_ledgers(company_id, retailer_id, created_at DESC);

-- 8. Organization-configurable Credit Policies
CREATE TABLE IF NOT EXISTS credit_policies (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL UNIQUE,
    policy_mode TEXT NOT NULL DEFAULT 'HARD_STOP' CHECK(policy_mode IN ('HARD_STOP', 'WARNING_ONLY', 'APPROVAL_REQUIRED')),
    max_overdue_days INTEGER NOT NULL DEFAULT 30,
    max_overdue_invoices INTEGER NOT NULL DEFAULT 2,
    allow_sales_override INTEGER NOT NULL DEFAULT 0,
    require_override_reason INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- 9. Credit Overrides Audit Table
CREATE TABLE IF NOT EXISTS credit_overrides (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    order_id TEXT,
    override_amount_paise INTEGER NOT NULL,
    exposure_at_time_paise INTEGER NOT NULL,
    credit_limit_paise INTEGER NOT NULL,
    authorized_by TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (authorized_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_credit_overrides_retailer ON credit_overrides(company_id, retailer_id, created_at DESC);

-- 10. GST Breakdown columns on order_items
ALTER TABLE order_items ADD COLUMN hsn_code TEXT;
ALTER TABLE order_items ADD COLUMN gst_rate REAL DEFAULT 18.0;
ALTER TABLE order_items ADD COLUMN cgst_amount_paise INTEGER DEFAULT 0;
ALTER TABLE order_items ADD COLUMN sgst_amount_paise INTEGER DEFAULT 0;
ALTER TABLE order_items ADD COLUMN igst_amount_paise INTEGER DEFAULT 0;
ALTER TABLE order_items ADD COLUMN cess_amount_paise INTEGER DEFAULT 0;

-- 11. Van Sales fields on orders
ALTER TABLE orders ADD COLUMN is_van_sale INTEGER NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN van_trip_id TEXT;
ALTER TABLE orders ADD COLUMN is_provisional INTEGER NOT NULL DEFAULT 0;

-- 12. Non-destructive backfill for existing companies and users into organizations model
INSERT OR IGNORE INTO organizations (id, name, legal_name, is_active, created_at, updated_at)
SELECT id, name, name, 1, CAST(strftime('%s', 'now') AS INTEGER) * 1000, CAST(strftime('%s', 'now') AS INTEGER) * 1000
FROM companies;

INSERT OR IGNORE INTO organization_memberships (id, organization_id, user_id, role, is_active, created_at)
SELECT 'mem_' || id, company_id, id, role, 1, CAST(strftime('%s', 'now') AS INTEGER) * 1000
FROM users
WHERE company_id IS NOT NULL;

-- 13. Initialize default credit policy for existing companies (HARD_STOP default as requested)
INSERT OR IGNORE INTO credit_policies (id, company_id, policy_mode, max_overdue_days, max_overdue_invoices, allow_sales_override, require_override_reason, created_at, updated_at)
SELECT 'cp_' || id, id, 'HARD_STOP', 30, 2, 0, 1, CAST(strftime('%s', 'now') AS INTEGER) * 1000, CAST(strftime('%s', 'now') AS INTEGER) * 1000
FROM companies;
