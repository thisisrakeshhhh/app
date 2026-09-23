-- Migration 0002: Performance indices (production-safe)
-- Note: Development and test accounts have been isolated to backend/seeds/dev_seeds.sql
CREATE INDEX IF NOT EXISTS idx_users_company ON users(company_id);
CREATE INDEX IF NOT EXISTS idx_retailers_company ON retailers(company_id);
CREATE INDEX IF NOT EXISTS idx_products_company ON products(company_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
