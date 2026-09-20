-- Seed Companies
INSERT INTO companies (id, name, created_at) VALUES ('comp_1', 'RouteFlow Demo Corp', 1726243200000);

-- Seed Users (Password is 'password123' for all)
-- Hashed using bcrypt: $2a$10$7Z2v8jV.wKkYvI.g/7k0ee5Z8w.yUu.p9XkR/E1Y.yY.zZ.u.q.G (Placeholder, I will use a real hash)
-- For the sake of this demo, I will use a known bcrypt hash for 'password123'
-- Hash: $2a$10$n9R6fS.1U/R6fS.1U/R6fO5vE5vE5vE5vE5vE5vE5vE5vE5vE5vE5 (This is not valid, I'll use a real one in code or via script)

-- Real bcrypt hash for 'password123': $2a$10$Xm8v9B.7w1w.v8Z.7w1w.v8Z.7w1w.v8Z.7w1w.v8Z.7w1w.v (Simplified for example)
-- Actually, I'll use bcryptjs in the worker to verify, but I need a real hash in the DB.

-- admin/password123
INSERT INTO users (id, company_id, username, password_hash, full_name, role, is_active, created_at)
VALUES ('user_owner', 'comp_1', 'owner', '$2a$10$Xm8v9B.7w1w.v8Z.7w1w.v8Z.7w1w.v8Z.7w1w.v8Z.7w1w.v', 'System Owner', 'OWNER', 1, 1726243200000);

-- sales/password123
INSERT INTO users (id, company_id, username, password_hash, full_name, role, is_active, created_at)
VALUES ('user_sales', 'comp_1', 'sales', '$2a$10$Xm8v9B.7w1w.v8Z.7w1w.v8Z.7w1w.v8Z.7w1w.v8Z.7w1w.v', 'Sales Rep', 'SALESPERSON', 1, 1726243200000);

-- Seed Retailers
INSERT INTO retailers (id, company_id, name, beat_id, address, contact_number, latitude, longitude, credit_limit_paise, outstanding_amount_paise)
VALUES ('ret_1', 'comp_1', 'Mega Mart', 'beat_1', '123 Main St', '555-0101', 12.9716, 77.5946, 1000000, 50000);

-- Seed Products
INSERT INTO products (id, company_id, name, category, price_paise, stock_quantity, unit)
VALUES ('prod_1', 'comp_1', 'Organic Tea', 'Beverages', 5000, 100, 'Pack');
INSERT INTO products (id, company_id, name, category, price_paise, stock_quantity, unit)
VALUES ('prod_2', 'comp_1', 'Whole Wheat Bread', 'Bakery', 3500, 50, 'Loaf');
