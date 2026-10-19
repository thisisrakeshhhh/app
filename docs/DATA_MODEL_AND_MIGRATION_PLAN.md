# RouteFlow — Data Model & Migration Plan
**Document Version:** 1.0.0  
**Target Migration:** `0019_multi_tenant_organizations_and_catalog.sql`  

---

## 1. Migration History Overview

The RouteFlow D1 SQLite database has evolved through 18 discrete, numbered migrations:

- `0001_initial.sql`: Core users, companies, products, shops, and orders.
- `0002_seeds.sql`: Initial seed data for test company and default roles.
- `0003_order_lifecycle.sql`: Stage timestamps and delivery coordinates.
- `0004_security_ledger_and_sessions.sql`: Stateful session table and user security tokens.
- `0005_atomic_transitions_and_ledger.sql`: Order status state invariants and financial logs.
- `0006_delivery_verification_and_master_data.sql`: Delivery OTP, signatures, and shop geo-coordinates.
- `0007_beats_and_shifts.sql`: Route definitions, beat days, and sales staff shifts.
- `0008_collections_handovers_returns.sql`: Cash collections, driver handovers, and return reasons.
- `0009_daily_cycle_integrity.sql`: Checkpoint constraints and daily operating cycle enforcement.
- `0010_partial_and_failed_deliveries.sql`: Line-item rejections and undelivered return logs.
- `0011_retry_delivery_and_return_limits.sql`: Maximum delivery retry limits and return cages.
- `0012_security_and_concurrency.sql`: Optimistic concurrency locks (`version` columns).
- `0013_onboarding_and_delegation.sql`: Company self-serve onboarding and role delegation.
- `0014_product_batches_and_expiry.sql`: Batch numbers, manufacturing/expiry dates, and batch inventory.
- `0015_delivery_trips_and_sequencing.sql`: Multi-order delivery trips, vehicles, and drop sequence.
- `0016_production_governance_and_audit.sql`: Immutable security audit logs and role changes.
- `0017_daily_operating_system.sql`: Day-start/day-end cash registers and godown open/close states.
- `0018_warehouse_godown_production.sql`: Godown bin locations, picking lists, packing slips, and stock ledger.

---

## 2. Migration 0019 Design Specification

Migration 0019 introduces enterprise multi-tenancy, a global FMCG product catalog, vehicle van-stock allocations, and retailer double-entry khata ledgers, while remaining **100% backward-compatible** with existing `company_id` foreign keys.

### 2.1 Table: `organizations` and `organization_memberships`
Allows a single user identity to belong to multiple distributor organizations with distinct roles (e.g. Sales Executive in Org A, Admin in Org B).

```sql
CREATE TABLE IF NOT EXISTS organizations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    legal_name TEXT,
    gstin TEXT,
    fssai_license TEXT,
    state_code TEXT NOT NULL DEFAULT '07', -- Default Delhi/NCR
    currency TEXT NOT NULL DEFAULT 'INR',
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS organization_memberships (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK(role IN ('OWNER', 'ADMIN', 'SALES', 'WAREHOUSE', 'DELIVERY', 'RETAILER')),
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(organization_id, user_id)
);
```

### 2.2 Shared Global FMCG Catalog
Separates universal brand and product definitions from distributor-specific pricing and stock.

```sql
CREATE TABLE IF NOT EXISTS catalog_brands (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    manufacturer TEXT,
    logo_url TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS catalog_products (
    id TEXT PRIMARY KEY,
    brand_id TEXT REFERENCES catalog_brands(id),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    hsn_code TEXT NOT NULL,
    barcode TEXT UNIQUE,
    base_unit TEXT NOT NULL DEFAULT 'PIECE',
    description TEXT,
    image_url TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tenant_catalog_mappings (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id),
    catalog_product_id TEXT NOT NULL REFERENCES catalog_products(id),
    custom_sku TEXT,
    wholesale_rate REAL NOT NULL,
    mrp REAL NOT NULL,
    purchase_price REAL,
    gst_rate REAL NOT NULL DEFAULT 18.0,
    min_order_qty INTEGER NOT NULL DEFAULT 1,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(company_id, catalog_product_id)
);
```

### 2.3 Van Stock Allocations (Consignment & Logistics)
Tracks inventory loaded onto delivery vehicles for spot-billing and pre-booked deliveries.

```sql
CREATE TABLE IF NOT EXISTS van_stock_allocations (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL REFERENCES delivery_trips(id),
    product_id TEXT NOT NULL REFERENCES products(id),
    batch_id TEXT REFERENCES product_batches(id),
    allocated_qty INTEGER NOT NULL,
    delivered_qty INTEGER NOT NULL DEFAULT 0,
    returned_qty INTEGER NOT NULL DEFAULT 0,
    damaged_qty INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'ALLOCATED' CHECK(status IN ('ALLOCATED', 'IN_TRANSIT', 'RECONCILED')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### 2.4 Retailer Khata Ledger (Double-Entry Financial Accounting)
Tracks running balances, invoices, credit notes, and collection receipts with zero balance drift.

```sql
CREATE TABLE IF NOT EXISTS retailer_ledgers (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id),
    shop_id TEXT NOT NULL REFERENCES shops(id),
    entry_type TEXT NOT NULL CHECK(entry_type IN ('INVOICE_DEBIT', 'PAYMENT_CREDIT', 'RETURN_CREDIT', 'ADJUSTMENT')),
    reference_id TEXT, -- order_id or collection_id
    amount REAL NOT NULL,
    running_balance REAL NOT NULL,
    notes TEXT,
    created_by TEXT REFERENCES users(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_retailer_ledgers_shop ON retailer_ledgers(shop_id, created_at DESC);
```

---

## 3. Backward Compatibility Safeguards

1. **Non-destructive Extension**: Existing columns and foreign keys (`company_id`, `products.id`, `orders.id`) are maintained.
2. **Auto-Populate Trigger / Backfill**: Migration 0019 will insert corresponding `organizations` for all existing `companies`, and create `organization_memberships` for all existing `users`.
3. **Graceful Fallback**: If a tenant has not configured `tenant_catalog_mappings`, the system queries the legacy `products` table directly.
