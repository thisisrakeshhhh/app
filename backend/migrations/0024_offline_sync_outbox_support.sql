-- 0024_offline_sync_outbox_support.sql
-- RouteFlow Phase O1.1 / B2.2: Cloudflare D1 Support for Offline Outbox Mutations & Class Governance

-- 1. Server Outbox Mutations Ledger (Stores deduplicated wire mutations)
CREATE TABLE IF NOT EXISTS server_outbox_audit (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    mutation_type TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    provisional_business_id TEXT,
    server_business_id TEXT,
    client_sequence_order INTEGER NOT NULL,
    server_sequence_order INTEGER NOT NULL,
    processed_at_epoch_ms INTEGER NOT NULL,
    CONSTRAINT unq_org_idempotency UNIQUE (organization_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_server_outbox_org_seq 
ON server_outbox_audit (organization_id, server_sequence_order);

-- 2. Retailer Classification Governance Table
CREATE TABLE IF NOT EXISTS retailer_class_settings (
    organization_id TEXT NOT NULL,
    class_name TEXT NOT NULL,
    default_credit_limit_paise INTEGER NOT NULL DEFAULT 0,
    credit_days INTEGER NOT NULL DEFAULT 0,
    visit_frequency_days INTEGER NOT NULL DEFAULT 7,
    updated_at_epoch_ms INTEGER NOT NULL,
    PRIMARY KEY (organization_id, class_name)
);

-- Pre-seed default FMCG classes
INSERT OR IGNORE INTO retailer_class_settings (organization_id, class_name, default_credit_limit_paise, credit_days, visit_frequency_days, updated_at_epoch_ms)
VALUES 
    ('default', 'Class A', 5000000, 15, 7, 1793680000000),
    ('default', 'Class B', 2500000, 10, 7, 1793680000000),
    ('default', 'Class C', 1000000, 7, 14, 1793680000000),
    ('default', 'Class D', 0, 0, 14, 1793680000000),
    ('default', 'NEW', 0, 0, 7, 1793680000000);
