-- ============================================================================
-- DEVELOPMENT / LOCAL TEST SEEDS ONLY
-- DO NOT DEPLOY TO PRODUCTION ENVIRONMENTS
-- ============================================================================

-- 1. Demo Companies (Two companies to test tenant isolation)
INSERT OR REPLACE INTO companies (id, name, created_at)
VALUES 
  ('comp_1', 'RouteFlow Demo Corp', 1726243200000),
  ('comp_2', 'RouteFlow Second Corp', 1726243200000);

-- 2. Development Users (bcrypt hash for development credential)
-- Preserves existing user IDs
INSERT OR REPLACE INTO users (id, company_id, username, password_hash, full_name, role, is_active, created_at)
VALUES
  ('user_owner', 'comp_1', 'owner', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'System Owner', 'OWNER', 1, 1726243200000),
  ('user_sales', 'comp_1', 'sales', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'Rakesh Kumar', 'SALESPERSON', 1, 1726243200000),
  ('user_warehouse', 'comp_1', 'warehouse', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'Manoj Kumar', 'WAREHOUSE_MANAGER', 1, 1726243200000),
  ('user_delivery', 'comp_1', 'delivery', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'Suresh Yadav', 'DELIVERY_EXECUTIVE', 1, 1726243200000),
  ('user_delivery_2', 'comp_1', 'delivery2', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'Ramesh Singh', 'DELIVERY_EXECUTIVE', 1, 1726243200000),
  ('user_disabled', 'comp_1', 'disabled', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'Disabled Employee', 'SALESPERSON', 0, 1726243200000),
  -- Company 2 users for cross-company tests
  ('user_owner_comp2', 'comp_2', 'owner_comp2', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'Owner Two', 'OWNER', 1, 1726243200000),
  ('user_sales_comp2', 'comp_2', 'sales_comp2', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'Sales Two', 'SALESPERSON', 1, 1726243200000),
  ('user_delivery_comp2', 'comp_2', 'delivery_comp2', '$2b$10$5qNkxkfpmB3mQrKeAd6wC.wa8sprQau53l3h3VMiIw3fCu9F.f/w2', 'Delivery Two', 'DELIVERY_EXECUTIVE', 1, 1726243200000);

-- 3. Salesperson Beat Assignments
INSERT OR REPLACE INTO user_beat_assignments (user_id, beat_id, company_id, created_at)
VALUES
  ('user_sales', 'BEAT-04', 'comp_1', 1726243200000),
  ('user_sales_comp2', 'BEAT-99', 'comp_2', 1726243200000);

-- 4. Retailers (Preserving ret_1, adding BEAT-04 retailers R1-R6, plus comp_2 retailer)
INSERT OR REPLACE INTO retailers (id, company_id, name, beat_id, address, contact_number, latitude, longitude, credit_limit_paise, outstanding_amount_paise)
VALUES
  ('ret_1', 'comp_1', 'Mega Mart', 'BEAT-04', '123 Main St, Sector 1', '9829000001', 26.85, 75.76, 1000000, 50000),
  ('R1', 'comp_1', 'Sharma General Store', 'BEAT-04', 'Main Market, Sector 1', '9829012345', 26.85, 75.76, 5000000, 1250000),
  ('R2', 'comp_1', 'Gupta Provision Store', 'BEAT-04', 'Near Central Station, Sector 2', '9829023456', 26.86, 75.77, 3000000, 450000),
  ('R3', 'comp_1', 'Balaji Kirana Store', 'BEAT-04', 'SFS Colony, Sector 3', '9829034567', 26.87, 75.78, 2000000, 890000),
  ('R4', 'comp_1', 'City Super Mart', 'BEAT-04', 'VT Road, Sector 4', '9829045678', 26.88, 75.79, 10000000, 2500000),
  ('R5', 'comp_1', 'Modern General Store', 'BEAT-04', 'Patel Marg, Sector 5', '9829056789', 26.89, 75.80, 1500000, 120000),
  ('R6', 'comp_1', 'Mahadev Departmental Store', 'BEAT-04', 'Central Path, Sector 6', '9829067890', 26.90, 75.81, 4000000, 670000),
  ('ret_comp2_1', 'comp_2', 'Company 2 Retail Store', 'BEAT-99', '99 Industrial Area', '9829099999', 28.50, 77.20, 2000000, 0);

-- 5. Products (Preserving prod_1, prod_2, adding P1-P10, plus comp_2 product)
INSERT OR REPLACE INTO products (id, company_id, name, category, price_paise, stock_quantity, reserved_quantity, unit, image_url)
VALUES
  ('prod_1', 'comp_1', 'Organic Tea', 'Beverages', 5000, 100, 0, 'Pack', NULL),
  ('prod_2', 'comp_1', 'Whole Wheat Bread', 'Bakery', 3500, 50, 0, 'Loaf', NULL),
  ('P1', 'comp_1', 'Premium Tea', 'Beverages', 45000, 100, 0, '1kg Pack', NULL),
  ('P2', 'comp_1', 'Spices Pack', 'Groceries', 12000, 200, 0, '200g Pouch', NULL),
  ('P3', 'comp_1', 'Basmati Rice 5kg', 'Groceries', 65000, 50, 0, 'Bag', NULL),
  ('P4', 'comp_1', 'Cooking Oil 5L', 'Groceries', 85000, 80, 0, 'Can', NULL),
  ('P5', 'comp_1', 'Soap Case (12 units)', 'Personal Care', 36000, 150, 0, 'Box', NULL),
  ('P6', 'comp_1', 'Detergent Powder 2kg', 'Home Care', 28000, 120, 0, 'Pack', NULL),
  ('P7', 'comp_1', 'Salt Pack', 'Groceries', 2500, 500, 0, '1kg Pouch', NULL),
  ('P8', 'comp_1', 'Sugar 5kg', 'Groceries', 22000, 60, 0, 'Bag', NULL),
  ('P9', 'comp_1', 'Pulse Mix 1kg', 'Groceries', 14000, 300, 0, 'Pack', NULL),
  ('P10', 'comp_1', 'Biscuits Family Pack', 'Snacks', 8000, 400, 0, 'Pack', NULL),
  ('prod_comp2_1', 'comp_2', 'Widget Comp2', 'Hardware', 10000, 50, 0, 'Unit', NULL);

-- 6. Promotions Rules
INSERT OR REPLACE INTO promotions (id, company_id, product_id, min_quantity, free_quantity, is_active)
VALUES
  ('promo_p1', 'comp_1', 'P1', 2, 1, 1),
  ('promo_prod1', 'comp_1', 'prod_1', 5, 1, 1);
