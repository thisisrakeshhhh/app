-- 0017_daily_operating_system.sql
-- Daily Business Operating System for Wholesale / Kirana Distributors:
-- 1. Day Book Checklists (Morning checklist & evening closing review with checklist items)
-- 2. Daily Operating Expenses (Fuel, loading/unloading, vehicle maintenance, tea/snacks)
-- 3. Purchase Planning & Low Stock Reorder tracking

-- 1. Day Book Operating Checklists & Logs
CREATE TABLE IF NOT EXISTS day_book_checklists (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    business_date TEXT NOT NULL, -- YYYY-MM-DD
    type TEXT NOT NULL,          -- 'MORNING_OPENING', 'NIGHT_CLOSING'
    status TEXT NOT NULL DEFAULT 'COMPLETED', -- 'IN_PROGRESS', 'COMPLETED'
    
    -- Checklist Verification Flags
    checklist_data TEXT NOT NULL, -- JSON object storing item-by-item verified tasks
    
    -- Financial Snapshot Summary
    sales_total_paise INTEGER NOT NULL DEFAULT 0,
    collections_cash_paise INTEGER NOT NULL DEFAULT 0,
    collections_upi_paise INTEGER NOT NULL DEFAULT 0,
    collections_cheque_paise INTEGER NOT NULL DEFAULT 0,
    expenses_total_paise INTEGER NOT NULL DEFAULT 0,
    cash_in_hand_paise INTEGER NOT NULL DEFAULT 0,
    
    -- Operational Snapshot Summary
    orders_count INTEGER NOT NULL DEFAULT 0,
    pending_approvals_count INTEGER NOT NULL DEFAULT 0,
    failed_deliveries_count INTEGER NOT NULL DEFAULT 0,
    returns_count INTEGER NOT NULL DEFAULT 0,
    low_stock_count INTEGER NOT NULL DEFAULT 0,
    active_staff_count INTEGER NOT NULL DEFAULT 0,
    
    notes TEXT,
    completed_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (completed_by) REFERENCES users(id),
    UNIQUE (company_id, business_date, type)
);
CREATE INDEX IF NOT EXISTS idx_day_book_company_date ON day_book_checklists(company_id, business_date DESC);

-- 2. Operating Business Expenses (Daily Cash Outflows)
CREATE TABLE IF NOT EXISTS business_expenses (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    category TEXT NOT NULL, -- 'FUEL_PETROL', 'LOADING_UNLOADING', 'VEHICLE_MAINTENANCE', 'TEA_SNACKS', 'PACKAGING', 'SALARY_ADVANCE', 'OTHER'
    amount_paise INTEGER NOT NULL,
    payment_mode TEXT NOT NULL DEFAULT 'CASH', -- 'CASH', 'UPI', 'BANK_TRANSFER'
    description TEXT NOT NULL,
    paid_by TEXT NOT NULL,
    vehicle_number TEXT,
    receipt_photo_url TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (paid_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_business_expenses_company ON business_expenses(company_id, created_at DESC);
