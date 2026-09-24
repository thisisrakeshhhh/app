-- 0004_security_ledger_and_sessions.sql
-- Enforces per-device sessions, durable invoices & payment ledger, idempotency tracking, beat assignments and promotion rules.

-- 1. Sessions table for explicit per-device server sessions and instant revocation
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    company_id TEXT NOT NULL,
    device_id TEXT,
    refresh_token_hash TEXT NOT NULL UNIQUE,
    is_revoked INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    last_active_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (company_id) REFERENCES companies(id)
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_hash ON sessions(refresh_token_hash);

-- 2. Revoked refresh tokens (for atomic rotation and reuse detection)
CREATE TABLE IF NOT EXISTS revoked_refresh_tokens (
    token_hash TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    revoked_at INTEGER NOT NULL
);

-- 3. Salesperson beat assignments
CREATE TABLE IF NOT EXISTS user_beat_assignments (
    user_id TEXT NOT NULL,
    beat_id TEXT NOT NULL,
    company_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (user_id, beat_id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (company_id) REFERENCES companies(id)
);
CREATE INDEX IF NOT EXISTS idx_user_beats ON user_beat_assignments(user_id, beat_id);

-- 4. Durable Invoices
CREATE TABLE IF NOT EXISTS invoices (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL UNIQUE,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    total_amount_paise INTEGER NOT NULL,
    status TEXT NOT NULL, -- ISSUED, PAID
    created_at INTEGER NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id)
);

-- 5. Durable Payment Ledger
CREATE TABLE IF NOT EXISTS payment_ledger (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    invoice_id TEXT,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    entry_type TEXT NOT NULL, -- CREDIT_INCREASE, CASH_PAYMENT, UPI_PAYMENT, CHEQUE_PAYMENT
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
CREATE INDEX IF NOT EXISTS idx_ledger_order ON payment_ledger(order_id);
CREATE INDEX IF NOT EXISTS idx_ledger_retailer ON payment_ledger(retailer_id);

-- 6. Bound Idempotency Records (binds actor, operation, and request hash)
CREATE TABLE IF NOT EXISTS idempotency_records (
    key TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    response_body TEXT NOT NULL,
    response_status INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);

-- 7. Promotions Rules
CREATE TABLE IF NOT EXISTS promotions (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    min_quantity INTEGER NOT NULL,
    free_quantity INTEGER NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
