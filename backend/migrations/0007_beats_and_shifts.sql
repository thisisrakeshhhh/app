-- 0007_beats_and_shifts.sql
-- Adds Master Beats, Field Shifts, Breadcrumb Locations, and Stock Idempotency

-- 1. Master Beats table
CREATE TABLE IF NOT EXISTS beats (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    working_days TEXT, -- e.g. "MON,WED,FRI"
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id)
);
CREATE INDEX IF NOT EXISTS idx_beats_company ON beats(company_id);

-- 2. Field Employee Shifts
CREATE TABLE IF NOT EXISTS shifts (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    status TEXT NOT NULL, -- ON_SHIFT, ON_BREAK, OFF_SHIFT
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    start_latitude REAL,
    start_longitude REAL,
    end_latitude REAL,
    end_longitude REAL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_shifts_user ON shifts(company_id, user_id, start_time);

-- 3. Batched Shift Location Tracking
CREATE TABLE IF NOT EXISTS shift_locations (
    id TEXT PRIMARY KEY,
    shift_id TEXT NOT NULL,
    company_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    accuracy REAL,
    timestamp INTEGER NOT NULL,
    FOREIGN KEY (shift_id) REFERENCES shifts(id),
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_shift_locations ON shift_locations(company_id, user_id, timestamp);

-- 4. Stock Adjustment Idempotency Key
ALTER TABLE stock_adjustments ADD COLUMN idempotency_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_adj_idemp ON stock_adjustments(company_id, idempotency_key);

-- 5. Product optional Hindi name
ALTER TABLE products ADD COLUMN hindi_name TEXT;

-- 6. Initial Beats for Pilot Setup
INSERT OR REPLACE INTO beats (id, company_id, name, description, working_days, is_active, created_at)
VALUES
  ('BEAT-01', 'comp_1', 'Mansarovar Central', 'Sector 1-4 Retail Shops', 'MON,WED,FRI', 1, 1726243200000),
  ('BEAT-02', 'comp_1', 'Malviya Nagar & Tonk Road', 'Main Bazaar and Commercial Complex', 'TUE,THU,SAT', 1, 1726243200000),
  ('BEAT-04', 'comp_1', 'Jaipur Junction & Station Area', 'Wholesale market cluster', 'MON,TUE,WED,THU,FRI,SAT', 1, 1726243200000);
