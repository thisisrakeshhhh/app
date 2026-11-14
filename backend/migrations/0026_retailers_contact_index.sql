-- 0026_retailers_contact_index.sql
-- RouteFlow Checkpoint 3: Index for fast tenant-scoped contact number queries and duplicate protection

CREATE INDEX IF NOT EXISTS idx_retailers_company_contact ON retailers(company_id, contact_number);
