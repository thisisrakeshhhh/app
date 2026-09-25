-- 0008_collections_handovers_returns.sql
-- Supports standalone retailer collections, cash handover reconciliation, and warehouse return workflows.

-- 1. Collections Table
CREATE TABLE IF NOT EXISTS collections (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    collected_by TEXT NOT NULL,
    amount_paise INTEGER NOT NULL,
    payment_method TEXT NOT NULL, -- CASH, UPI, CHEQUE
    receipt_id TEXT NOT NULL,
    notes TEXT,
    idempotency_key TEXT UNIQUE,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (collected_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_collections_retailer ON collections(retailer_id);
CREATE INDEX IF NOT EXISTS idx_collections_collected_by ON collections(collected_by);
CREATE INDEX IF NOT EXISTS idx_collections_company ON collections(company_id);

-- 2. Cash Handovers Table
CREATE TABLE IF NOT EXISTS cash_handovers (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    amount_paise INTEGER NOT NULL,
    status TEXT NOT NULL, -- 'PENDING', 'ACCEPTED', 'REJECTED'
    submitted_at INTEGER NOT NULL,
    acknowledged_at INTEGER,
    acknowledged_by TEXT,
    received_amount_paise INTEGER,
    discrepancy_paise INTEGER,
    notes TEXT,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (acknowledged_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_handovers_user ON cash_handovers(user_id);
CREATE INDEX IF NOT EXISTS idx_handovers_company ON cash_handovers(company_id);

-- 3. Returns and Return Items Tables
CREATE TABLE IF NOT EXISTS return_requests (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    order_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    created_by TEXT NOT NULL,
    status TEXT NOT NULL, -- 'PENDING_INSPECTION', 'APPROVED', 'REJECTED'
    created_at INTEGER NOT NULL,
    inspected_at INTEGER,
    inspected_by TEXT,
    notes TEXT,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (created_by) REFERENCES users(id),
    FOREIGN KEY (inspected_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_returns_company ON return_requests(company_id);
CREATE INDEX IF NOT EXISTS idx_returns_order ON return_requests(order_id);

CREATE TABLE IF NOT EXISTS return_items (
    id TEXT PRIMARY KEY,
    return_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    requested_quantity INTEGER NOT NULL,
    saleable_quantity INTEGER NOT NULL DEFAULT 0,
    damaged_quantity INTEGER NOT NULL DEFAULT 0,
    unit_price_paise INTEGER NOT NULL,
    FOREIGN KEY (return_id) REFERENCES return_requests(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS idx_return_items_return ON return_items(return_id);

-- 4. Recreate payment_ledger to allow nullable order_id and add collection_id
CREATE TABLE IF NOT EXISTS payment_ledger_new (
    id TEXT PRIMARY KEY,
    order_id TEXT, -- NULLABLE for standalone collections
    invoice_id TEXT,
    collection_id TEXT,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    entry_type TEXT NOT NULL, -- CREDIT_INCREASE, CASH_PAYMENT, UPI_PAYMENT, CHEQUE_PAYMENT, RETURN_CREDIT_NOTE
    amount_paise INTEGER NOT NULL,
    balance_after_paise INTEGER NOT NULL,
    payment_method TEXT NOT NULL,
    collected_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    idempotency_key TEXT UNIQUE,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id)
);

INSERT OR IGNORE INTO payment_ledger_new (
    id, order_id, invoice_id, collection_id, company_id, retailer_id,
    entry_type, amount_paise, balance_after_paise, payment_method, collected_by, created_at, idempotency_key
)
SELECT id, order_id, invoice_id, NULL, company_id, retailer_id, entry_type, amount_paise, balance_after_paise, payment_method, collected_by, created_at, idempotency_key 
FROM payment_ledger;

DROP TABLE IF EXISTS payment_ledger;
ALTER TABLE payment_ledger_new RENAME TO payment_ledger;

CREATE INDEX IF NOT EXISTS idx_ledger_order ON payment_ledger(order_id);
CREATE INDEX IF NOT EXISTS idx_ledger_retailer ON payment_ledger(retailer_id);
CREATE INDEX IF NOT EXISTS idx_ledger_collected_by ON payment_ledger(collected_by);
CREATE INDEX IF NOT EXISTS idx_ledger_collection ON payment_ledger(collection_id);
