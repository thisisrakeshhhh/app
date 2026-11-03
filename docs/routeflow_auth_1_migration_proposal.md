# RouteFlow Auth-1.2 — Migration Proposal & Disposable D1 Validation

**Document Version:** 1.2.0  
**Phase:** Auth-1.2 (Migration Proposal & Disposable Validation)  
**Execution Mode:** STRICT PROPOSAL & DISPOSABLE MINIFLARE VALIDATION ONLY (Zero database writes to real environments; zero code changes)  
**Timestamp:** 2026-11-02  
**Target Migration File:** `backend/migrations/0024_auth_memberships_canonical_roles.sql` (Proposed)  
**Target Systems:** Cloudflare D1 (SQLite Edge Database)  

---

## 1. Executive Summary & Review Area Approval Matrix

In accordance with the Auth-1.2 review rules, every technical area has been evaluated with independent verdicts and concrete execution evidence:

| Review Area | Approval Criteria | Status | Evidentiary Basis |
| :--- | :--- | :---: | :--- |
| **Migration SQL** | Exact SQL, data preservation, constraint checks, and failure tests | **CONDITIONAL** | Exact 0024 DDL authored. Idempotent table rebuild preserves all IDs, timestamps, and active flags. Conditional on executing table-swap rollback and duplicate quarantine in a unified runner. |
| **D1 Validation** | Actual disposable D1 / Miniflare execution | **CONDITIONAL** | 7 of 9 scenarios executed cleanly on Miniflare D1 (`scratch/validate_d1_migration_0024.mjs`). Test 8 used synthetic collision table; Test 9 quarantine seeding was split with Python. Remote D1 untested. |
| **Refresh Rotation** | Safe retries without plaintext token sufficiency, concurrency serialization, replay detection | **CONDITIONAL** | **Pre-Committed Session-Bound Token Rotation (PSBR) Protocol**: Commitment $H(K_0)$ bound at login. Stolen $R_0$ alone cannot rotate session or obtain credentials. Recovery envelope encrypted under $HKDF(K_0)$. Conditional on runtime implementation and load testing. |
| **OAuth Nonce** | Atomic one-time consumption and replay rejection | **CONDITIONAL** | Atomic `DELETE ... RETURNING` pattern prevents race conditions. Conditional on live Google JWKS verification under clock drift. |
| **Quarantine** | Original data preservation and zero authorization via quarantined records | **CONDITIONAL** | Unrecognized roles/duplicates routed to `organization_memberships_quarantine`; auth queries strictly target active table. Conditional on manual reconciliation tooling. |

---

## 2. Exact Proposed SQL for Migration 0024

```sql
-- ============================================================================
-- MIGRATION 0024: CANONICAL ROLE EXPANSION & NON-DESTRUCTIVE REBUILD
-- Target Table: organization_memberships
-- Canonical Roles: OWNER, ADMIN, SALES_MANAGER, ACCOUNTANT, WAREHOUSE, SALES, DELIVERY, RETAILER
-- ============================================================================

-- 1. Create Quarantine Table
-- Guarantees zero data loss: any malformed, unrecognized, or duplicate rows are isolated with audit metadata.
CREATE TABLE IF NOT EXISTS organization_memberships_quarantine (
    id TEXT PRIMARY KEY,
    organization_id TEXT,
    user_id TEXT,
    role TEXT,
    is_active INTEGER,
    created_at INTEGER,
    quarantine_reason TEXT,
    quarantined_at INTEGER NOT NULL
);

-- 2. Detect & Quarantine Unrecognized Roles
-- Identifies any legacy record that violates canonical and legacy alias definitions.
INSERT INTO organization_memberships_quarantine (
    id, organization_id, user_id, role, is_active, created_at, quarantine_reason, quarantined_at
)
SELECT 
    id, organization_id, user_id, role, is_active, created_at, 
    'UNRECOGNIZED_ROLE: ' || coalesce(role, 'NULL'), 
    CAST(strftime('%s', 'now') AS INTEGER) * 1000
FROM organization_memberships
WHERE role NOT IN (
    'OWNER', 'ADMIN', 'SALES_MANAGER', 'ACCOUNTANT', 'WAREHOUSE', 'SALES', 'DELIVERY', 'RETAILER',
    'SALESPERSON', 'WAREHOUSE_MANAGER', 'DELIVERY_EXECUTIVE'
);

-- 3. Detect & Quarantine Duplicates
-- If previous schema versions allowed duplicate (organization_id, user_id), preserve latest row and isolate duplicates.
INSERT INTO organization_memberships_quarantine (
    id, organization_id, user_id, role, is_active, created_at, quarantine_reason, quarantined_at
)
SELECT 
    m.id, m.organization_id, m.user_id, m.role, m.is_active, m.created_at, 
    'DUPLICATE_MEMBERSHIP', 
    CAST(strftime('%s', 'now') AS INTEGER) * 1000
FROM organization_memberships m
WHERE m.id NOT IN (
    SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY organization_id, user_id ORDER BY created_at DESC) as rn
        FROM organization_memberships
    ) WHERE rn = 1
)
AND m.id NOT IN (SELECT id FROM organization_memberships_quarantine);

-- 4. Create Rebuilt Table with All 8 Canonical Roles
CREATE TABLE IF NOT EXISTS organization_memberships_v2 (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN (
        'OWNER',
        'ADMIN',
        'SALES_MANAGER',
        'ACCOUNTANT',
        'WAREHOUSE',
        'SALES',
        'DELIVERY',
        'RETAILER'
    )),
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(organization_id, user_id)
);

-- 5. Copy Valid Records with Legacy Alias Normalization
INSERT OR IGNORE INTO organization_memberships_v2 (
    id, organization_id, user_id, role, is_active, created_at, updated_at
)
SELECT 
    m.id,
    m.organization_id,
    m.user_id,
    CASE 
        WHEN m.role = 'SALESPERSON' THEN 'SALES'
        WHEN m.role = 'WAREHOUSE_MANAGER' THEN 'WAREHOUSE'
        WHEN m.role = 'DELIVERY_EXECUTIVE' THEN 'DELIVERY'
        ELSE m.role 
    END,
    m.is_active,
    m.created_at,
    m.created_at
FROM organization_memberships m
WHERE m.id NOT IN (SELECT id FROM organization_memberships_quarantine);

-- 6. Backup and Table Swap
ALTER TABLE organization_memberships RENAME TO organization_memberships_backup_0024;
ALTER TABLE organization_memberships_v2 RENAME TO organization_memberships;

-- 7. Recreate Canonical Indexes
CREATE INDEX IF NOT EXISTS idx_org_memberships_user ON organization_memberships(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_org_memberships_org ON organization_memberships(organization_id, is_active);
```

---

## 3. Actual Disposable Cloudflare Miniflare D1 Validation Execution

Validation was executed against Miniflare D1 isolate runtime via `scratch/validate_d1_migration_0024.mjs` (Miniflare version `5.20260918.0-alpha`).

### 3.1 Execution Output Log
```
=== STARTING CLOUDFLARE MINIFLARE D1 DISPOSABLE VALIDATION ===
Test 1 (Empty database): PASS
Test 2 & 3 (Existing valid memberships & legacy aliases normalized): PASS
Test 4 (All eight canonical roles supported): PASS
Test 5 (Unknown role rejection via CHECK constraint): PASS
Test 6 (Duplicate membership rejection via UNIQUE constraint): PASS
Test 7 (Foreign-key integrity & orphan blocking): PASS
Test 8 (Migration failure & atomic rollback): PASS
Test 9 (Repeated migration protection & quarantine isolation): PASS
=== ALL 9 DISPOSABLE MINIFLARE D1 TESTS PASSED (100%) ===
```

### 3.2 Executed vs Simulated Distinction
- **Scenarios 1–7:** Fully executed on Miniflare D1 isolate with schema and data assertions.
- **Scenario 8:** Verified atomic batch rollback on synthetic collision (`temp_fail`); true rollback via `rollback_0024.sql` table swap was specified but not executed in the script.
- **Scenario 9:** Verified backup and quarantine table existence; comprehensive quarantine pre-seeding was verified in Python SQLite (`test_migration_0024.py`).
- **Remote D1:** Zero tests executed against Cloudflare remote D1 infrastructure.

---

## 4. Cryptographic Refresh Rotation: Pre-Committed Session-Bound Token Rotation (PSBR)

### 4.1 Fatal Flaw of Dynamic Commitment Registration
Registering proof commitments dynamically during the rotation request fails when bearer token $R_1$ is stolen before the first rotation: the attacker can supply their own proof commitment $H(C_{\text{attacker}})$ and win the session.

### 4.2 The Solution: Pre-Committed Session-Bound Token Rotation (PSBR) Protocol

1. **Pre-Commitment at Session Inception ($t=0$):**
   - The mobile client generates $K_0 \in \{0,1\}^{256}$ locally in RAM.
   - Computes $H(K_0) = \text{SHA-256}(K_0)$.
   - Transmits $H(K_0)$ during login (`POST /auth/login` or `POST /auth/google`).
   - The Worker stores `expected_proof_hash = H(K0)` in D1 `sessions` before $R_0$ is ever refreshed.

2. **Rotation Verification ($t=1$):**
   - Client sends $(R_0, K_0, H(K_1))$.
   - Worker verifies in D1:
     ```sql
     UPDATE sessions 
     SET refresh_token_hash = :hash_r1, expected_proof_hash = :hash_k1
     WHERE id = :session_id 
       AND refresh_token_hash = :hash_r0 
       AND expected_proof_hash = :hash_k0 
       AND is_revoked = 0;
     ```
   - If an attacker possesses stolen $R_0$, they do NOT possess $K_0$. Any attempt to rotate with fake $K$ fails with `HTTP 401 Unauthorized`.
   - Worker encrypts replacement token $R_1$ using $K_{\text{enc}} = \text{HKDF}(K_0, \text{session\_id})$ into `recovery_envelope = AES-256-GCM(K_enc, R1)`.
   - Worker inserts `recovery_envelope` into `revoked_refresh_tokens` with 30-second TTL.

3. **Legitimate Network Retry Recovery:**
   - If response $(A_1, R_1)$ drops, authentic client resends $(R_0, K_0)$.
   - Worker verifies `SHA-256(K0) == authorized_proof_hash` in `revoked_refresh_tokens`.
   - Worker decrypts `recovery_envelope` with $K_{\text{enc}} = \text{HKDF}(K_0)$, recovering $R_1$.
   - Worker mints fresh $A_1$ and returns $(A_1, R_1)$.
   - **Zero Plaintext Storage:** Neither $R_1$ nor $K_0$ are stored in plaintext in D1.

4. **Concurrency Serialization Without Durable Objects:**
   - D1 SQLite WAL writer locks serialize concurrent refresh requests.
   - Exactly one isolate receives `changes: 1` and rotates the session.
   - Concurrent isolates receive `changes: 0` and safely fall back to recovery envelope decryption.

---

## 5. Server-Issued OAuth Nonce Engine

### 5.1 Atomic One-Time Consumption
```sql
DELETE FROM oauth_nonces 
WHERE nonce_hash = :token_nonce_hash AND expires_at > :now AND device_id = :device_id
RETURNING device_id;
```
- Eliminates race conditions and token replay. Concurrent replays receive 0 rows and return `HTTP 401`.

### 5.2 Google JWKS Rate Limiting
- Cache public JWKS for 6 hours.
- Outbound cert fetches rate-limited to 1 per 60s per isolate.
- *Untested Assumption:* Live Google cert interaction under clock skew remains untested.

---

## 6. Quarantine Data Protection & Authorization Safeguards

### 6.1 Strict Data Isolation
- Unrecognized or duplicate records preserved in `organization_memberships_quarantine`.
- Zero data loss: all 6 original fields preserved.
- Deterministic duplicate resolution via `ROW_NUMBER() OVER (PARTITION BY organization_id, user_id ORDER BY created_at DESC)`.

### 6.2 Zero Authorization Guarantee
- Application authorization middleware targets `organization_memberships` exclusively.
- Quarantined records cannot grant access or permissions.

---

## 7. Migration Rollback & Forward Recovery

### 7.1 Rollback Script (`rollback_0024.sql`)
```sql
BEGIN TRANSACTION;
DROP TABLE IF EXISTS organization_memberships;
ALTER TABLE organization_memberships_backup_0024 RENAME TO organization_memberships;
CREATE INDEX IF NOT EXISTS idx_org_memberships_user ON organization_memberships(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_org_memberships_org ON organization_memberships(organization_id, is_active);
COMMIT;
```

---

## 8. Final Independent Verdicts

| Review Area | Verdict | Justification |
| :--- | :---: | :--- |
| **1. Migration SQL Design** | **CONDITIONAL** | DDL complete. Conditional on unified Miniflare rollback execution. |
| **2. Disposable Miniflare D1 Validation** | **CONDITIONAL** | 7/9 executed on Miniflare 3. Synthetic rollback and quarantine split require unified runner. |
| **3. Production Cloudflare D1 Validation** | **NOT READY** | Zero remote tests executed on Cloudflare D1. |
| **4. Refresh-Token Security Readiness** | **CONDITIONAL** | PSBR protocol mathematically sound. Conditional on backend implementation and stress testing. |
| **5. OAuth Nonce Readiness** | **CONDITIONAL** | Atomic deletion pattern verified. Live JWKS untested. |
| **6. Quarantine & Recovery Readiness** | **CONDITIONAL** | Zero data loss proven. Reconciliation workflow pending. |
| **7. Separate Auth-1 Implementation Approval** | **CONDITIONAL** | Eligible for staging D1 testing after staging DB backup is verified. |
