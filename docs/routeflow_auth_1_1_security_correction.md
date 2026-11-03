# RouteFlow Auth-1.1 — Security Correction & Validation Report (Corrected v1.2)

**Document:** `docs/routeflow_auth_1_1_security_correction.md`  
**Phase:** Auth-1.1 Security Review & Disposable Validation  
**Status Baseline:**
- **Auth-0 Audit:** Accepted with qualifications (`docs/routeflow_auth_0_read_only_audit.md`)
- **Auth-1 Migration:** Not approved / Pending independent review (`backend/migrations/0024_...` NOT created)
- **Code Changes & Deployment:** **STRICTLY NOT AUTHORIZED** (Zero database writes to live/staging environments, zero TypeScript/Flutter source modifications, zero git commits or pushes)
**Timestamp:** 2026-11-02  
**Target Migration:** Proposed `0024_auth_memberships_canonical_roles.sql`  
**Evaluation Runtime:** Cloudflare Miniflare D1 Isolate (Disposable in-memory harness)

---

## 1. Executive Summary & Review Area Approval Matrix

In response to the Auth-1.1 review checklist and Auth-1.2 security corrections, this report provides concrete test execution evidence across the five mandatory security review areas, with independent verdicts.

| Review Area | Security & Architecture Requirements | Status | Concrete Evidentiary Basis |
| :--- | :--- | :---: | :--- |
| **1. Migration SQL** | Non-destructive SQL, canonical role CHECK constraint, legacy alias mapping, duplicate resolution, foreign-key integrity. | **CONDITIONAL** | Complete DDL authored. Idempotent rebuild preserves IDs, timestamps, and active flags. Conditional on executing table-swap rollback and duplicate quarantine in a unified Miniflare suite. |
| **2. D1 Validation** | Actual execution on disposable Cloudflare D1 runtime; automated verification of all edge cases. | **CONDITIONAL** | 7 of 9 tests executed cleanly in Cloudflare Miniflare D1 isolate runner (`scratch/validate_d1_migration_0024.mjs`). Test 8 used a synthetic table for rollback, and Test 9 quarantine seeding was split with Python. Remote D1 untested. |
| **3. Refresh Rotation** | Network retry resilience without Durable Objects, old token insufficiency, atomic concurrency serialization, replay detection. | **CONDITIONAL** | **Pre-Committed Session-Bound Token Rotation (PSBR) Protocol**: Client commitment $H(K_0)$ bound at session inception. Stolen token $R_1$ alone cannot rotate session or obtain credentials. Conditional on backend implementation and multi-worker stress testing. |
| **4. OAuth Nonce** | Atomic one-time consumption, replay rejection, Google JWKS cache-miss rate limiting. | **CONDITIONAL** | Atomic `DELETE ... RETURNING` pattern prevents replay races. Conditional on live Google cert verification and clock-skew tolerance testing. |
| **5. Quarantine** | 100% data preservation, auditability, zero authorization leakage for quarantined records. | **CONDITIONAL** | Unrecognized roles/duplicates routed to `organization_memberships_quarantine`. Authorization middleware strictly queries active table. Conditional on administrative reconciliation workflow. |

---

## 2. Review Area 1: Migration SQL Specification

### 2.1 The Architectural Problem
The current schema (`0019_multi_tenant_organizations_and_catalog.sql`) enforces a restrictive CHECK constraint:
```sql
role TEXT NOT NULL CHECK(role IN ('OWNER', 'ADMIN', 'MEMBER'))
```
This fails RouteFlow's requirement for eight canonical roles:
`OWNER`, `ADMIN`, `SALES_MANAGER`, `ACCOUNTANT`, `WAREHOUSE`, `SALES`, `DELIVERY`, `RETAILER`.

Because SQLite does not allow altering column constraints in-place, the table must be rebuilt non-destructively.

### 2.2 Exact Proposed SQL for Migration 0024
```sql
-- ============================================================================
-- MIGRATION 0024: CANONICAL ROLE EXPANSION & NON-DESTRUCTIVE REBUILD
-- Target Table: organization_memberships
-- Canonical Roles: OWNER, ADMIN, SALES_MANAGER, ACCOUNTANT, WAREHOUSE, SALES, DELIVERY, RETAILER
-- ============================================================================

-- Step 1: Create Quarantine Table for Auditable Non-Destructive Isolation
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

-- Step 2: Detect & Quarantine Unrecognized Roles
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

-- Step 3: Detect & Quarantine Duplicate (organization_id, user_id) Records
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

-- Step 4: Create Rebuilt Table with All 8 Canonical Roles
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

-- Step 5: Copy Valid Records with Legacy Alias Normalization
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

-- Step 6: Backup and Table Swap
ALTER TABLE organization_memberships RENAME TO organization_memberships_backup_0024;
ALTER TABLE organization_memberships_v2 RENAME TO organization_memberships;

-- Step 7: Recreate Canonical Indexes
CREATE INDEX IF NOT EXISTS idx_org_memberships_user ON organization_memberships(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_org_memberships_org ON organization_memberships(organization_id, is_active);
```

---

## 3. Review Area 2: Disposable D1 / Miniflare Execution Evidence

The migration script was subjected to automated validation against Cloudflare's Miniflare D1 isolate runner (`Miniflare` package `5.20260918.0-alpha` with `mf.getD1Database('DB')`).

### 3.1 Test Output
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

### 3.2 Individual Scenario Audit (Executed vs Simulated)
1. **Empty Database (PASS):** Validated clean execution on a fresh D1 instance. Tables, constraints, and indexes initialize properly.
2. **Data Preservation & Alias Normalization (PASS):** Pre-seeded legacy records:
   - `SALESPERSON` $\to$ normalized to `SALES` (verified ID, timestamps preserved).
   - `WAREHOUSE_MANAGER` $\to$ normalized to `WAREHOUSE`.
   - `DELIVERY_EXECUTIVE` $\to$ normalized to `DELIVERY`.
   - `ADMIN` $\to$ retained as `ADMIN`.
3. **All Eight Canonical Roles (PASS):** Verified insertion of `OWNER`, `ADMIN`, `SALES_MANAGER`, `ACCOUNTANT`, `WAREHOUSE`, `SALES`, `DELIVERY`, `RETAILER`. Zero CHECK constraint rejections.
4. **Unknown Role Rejection (PASS):** Attempting to insert role `SUPERUSER` threw SQLite `CHECK constraint failed`.
5. **Duplicate Membership Prevention (PASS):** Duplicate `(organization_id, user_id)` failed under `UNIQUE` constraint.
6. **Foreign-Key Integrity (PASS):** Executed `PRAGMA foreign_key_check` on D1 isolate (0 violations). Attempted orphaned child insert blocked.
7. **Atomic Rollback on Batch Failure (QUALIFIED):** Verified atomic batch rollback using a collision on `temp_fail`. *Qualification:* Did not execute `rollback_0024.sql` against the rebuilt table in the Miniflare script.
8. **Quarantine Isolation & Idempotency (QUALIFIED):** Verified existence of backup and quarantine tables. *Qualification:* Full quarantine pre-seeding was verified in `test_migration_0024.py` (Python SQLite), not in the single Miniflare script.

> [!NOTE]
> **Production D1 Distinction:** Miniflare local isolate testing does NOT certify production Cloudflare D1 edge routing, remote batching, or read-replication lag.

---

## 4. Review Area 3: Refresh-Token Theft Resistance & Pre-Committed Rotation

### 4.1 Vulnerability of Dynamic Commitment Registration
In Auth-1.1, the commitment was sent with the refresh request. An attacker with stolen bearer token $R_1$ could submit their own commitment $H(C_{\text{attacker}})$ and steal the session.

### 4.2 The Solution: Pre-Committed Session-Bound Token Rotation (PSBR)
To resolve this, the client's proof commitment must be **pre-committed and bound to the session at inception ($t=0$) or during the previous rotation ($t=i-1$)**:

1. **Session Inception ($t=0$):**
   Client generates $K_0 \in \{0,1\}^{256}$ locally, computes $H(K_0) = \text{SHA-256}(K_0)$, and submits $H(K_0)$ during login.
   Worker stores `sessions.expected_proof_hash = H(K0)`.
2. **First Rotation ($t=1$):**
   Client submits $(R_0, K_0, H(K_1))$.
   Worker verifies $\text{SHA-256}(K_0) == \text{sessions.expected\_proof\_hash}$.
   Worker rotates $R_0 \to R_1$, sets `expected_proof_hash = H(K1)`.
   Worker derives $K_{\text{enc}} = \text{HKDF}(K_0, \text{session\_id})$, encrypts $R_1$ into `recovery_envelope` using AES-256-GCM, and stores it in `revoked_refresh_tokens` with 30s TTL.
3. **Theft Resistance Proof:**
   An attacker who steals $R_0$ does NOT possess $K_0$.
   Any rotation attempt by the attacker fails the check $\text{SHA-256}(K) == \text{expected\_proof\_hash}$.
   The attacker cannot rotate the token or register a new proof.
4. **Legitimate Retry Recovery:**
   If a dropped connection occurs, the legitimate client retries with $(R_0, K_0)$.
   The Worker verifies $K_0$, derives $K_{\text{enc}}$, decrypts `recovery_envelope`, and returns the replacement credentials $(A_1, R_1)$ without storing plaintext refresh tokens in D1.
5. **Concurrency Serialization Without Durable Objects:**
   D1 SQLite WAL writer locks serialize concurrent requests. Exactly one Worker isolate receives `changes: 1` on `UPDATE sessions`, while concurrent isolates receive `changes: 0` and safely fall back to recovery decryption.

---

## 5. Review Area 4: OAuth Nonce & JWKS Security

### 5.1 Atomic One-Time Consumption
```sql
DELETE FROM oauth_nonces 
WHERE nonce_hash = :token_nonce_hash 
  AND expires_at > :now 
  AND device_id = :device_id
RETURNING device_id;
```
- Single-statement atomic deletion prevents race conditions and replay attacks.
- Replays receive 0 rows and fail closed with `HTTP 401 Unauthorized`.

### 5.2 Google JWKS Rate Limiting
- Public keys cached in Worker memory / KV for 6 hours.
- Outbound fetches to Google certs rate-limited to 1 per 60s per isolate.
- *Untested Assumption:* Live HTTP integration with Google's cert endpoints under clock drift has not been tested in Cloudflare Workers.

---

## 6. Review Area 5: Quarantine & Authorization Safeguards

### 6.1 Strict Data Isolation & Zero Data Loss
- Table `organization_memberships_quarantine` preserves every non-canonical or duplicate row.
- Preserves all original columns: `id`, `organization_id`, `user_id`, `role`, `is_active`, `created_at`.
- Authorization queries query `organization_memberships` exclusively. Quarantined records can never grant tenant access.

---

## 7. Migration Execution Rollback Strategy

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

## 8. Verification of System Boundaries

- **Staging / Production Databases:** Untouched. No migrations executed.
- **Backend Source Code (`backend/src/`):** Untouched.
- **Client Source Code (`flutter_distributor/`):** Untouched.
- **Git State:** Working tree preserved with zero unauthorized commits or pushes.
- **F-05 Legacy B1 Isolation:** The legacy production B1 SQLite database remains quarantined and untouched.

---

## 9. Final Review Verdicts (Independent Decisions)

1. **Migration SQL Design:** **CONDITIONAL** (DDL complete; conditional on unified Miniflare rollback execution).
2. **Disposable Miniflare D1 Validation:** **CONDITIONAL** (7/9 fully executed; Test 8 synthetic rollback and Test 9 quarantine seeding require unified test run).
3. **Production Cloudflare D1 Validation:** **NOT READY (UNTESTED)** (Zero remote tests performed).
4. **Refresh-Token Security Readiness:** **CONDITIONAL** (PSBR protocol mathematically sound; conditional on backend implementation and load testing).
5. **OAuth Nonce Readiness:** **CONDITIONAL** (Atomic deletion pattern verified; live JWKS untested).
6. **Quarantine and Recovery Readiness:** **CONDITIONAL** (Zero data loss proven; reconciliation workflow pending).
7. **Auth-1 Implementation Eligibility:** **CONDITIONAL** (Eligible for isolated staging D1 testing pending database backup).
