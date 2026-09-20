-- Companies table for multi-tenant isolation
CREATE TABLE companies (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

-- Users table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    username TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL, -- OWNER, SALESPERSON, WAREHOUSE_MANAGER, DELIVERY_EXECUTIVE
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

CREATE UNIQUE INDEX idx_users_username ON users(username);

-- Refresh tokens for revocable sessions
CREATE TABLE refresh_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    company_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- Retailers (scoped to company)
CREATE TABLE retailers (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    name TEXT NOT NULL,
    beat_id TEXT NOT NULL,
    address TEXT NOT NULL,
    contact_number TEXT NOT NULL,
    latitude REAL,
    longitude REAL,
    credit_limit_paise INTEGER NOT NULL,
    outstanding_amount_paise INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- Products (scoped to company)
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    price_paise INTEGER NOT NULL,
    stock_quantity INTEGER NOT NULL,
    reserved_quantity INTEGER NOT NULL DEFAULT 0,
    unit TEXT NOT NULL,
    image_url TEXT,
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- Orders
CREATE TABLE orders (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    employee_id TEXT NOT NULL,
    status TEXT NOT NULL,
    total_amount_paise INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    idempotency_key TEXT UNIQUE,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (employee_id) REFERENCES users(id)
);

-- Order Items
CREATE TABLE order_items (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    free_quantity INTEGER NOT NULL,
    price_paise_at_time INTEGER NOT NULL,
    is_picked INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Audit log
CREATE TABLE audit_logs (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    action TEXT NOT NULL,
    entity_id TEXT,
    details TEXT,
    timestamp INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id)
);
