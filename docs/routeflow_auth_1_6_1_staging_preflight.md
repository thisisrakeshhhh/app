# RouteFlow Auth-1.6.1 — Remote Staging Migration Preflight & Architecture Review

**Document Version:** 1.6.1  
**Phase:** Auth-1.6.1 Remote Staging Preflight & Offline Session Governance  
**Execution Mode:** STRICT DOCUMENT-ONLY SECURITY REVIEW  
**Scope Boundary:** Zero application code changes, zero migration execution on real databases, zero database writes to live/staging environments, zero git commits or pushes.  
**Timestamp:** 2026-11-02  
**Target Migration:** Proposed `0024_auth_memberships_canonical_roles.sql`  
**Target Systems:** Cloudflare Workers API, Cloudflare D1 (SQLite Edge Database), Flutter Pilot (`flutter_distributor`), Vivo 1935 Hardware  

---

## 1. Remote D1 Backup Capability Audit (`backend/tools/backup_sqlite.py`)

### 1.1 Source Code Inspection
Direct inspection of `backend/tools/backup_sqlite.py`:
- **Line 10:**  
  `D1_DB_PATH = r"D:\app\backend\.wrangler\state\v3\d1\miniflare-D1DatabaseObject\375634d678c996ae430f25b6d6e647334f27927de84135ea4b7b9e884d21d0b2.sqlite"`
- **Line 26:**  
  `source_conn = sqlite3.connect(D1_DB_PATH)`
- **Line 38:**  
  `source_conn.backup(dest_conn, pages=100)`

### 1.2 Evaluation of Backup Capability
> [!CRITICAL]
> **Definitive Finding:** `backend/tools/backup_sqlite.py` backs up **ONLY the local Miniflare SQLite file** on the local Windows filesystem.
> - It does **NOT** connect to remote Cloudflare D1.
> - It does **NOT** authenticate via Cloudflare API tokens.
> - It has **ZERO** capability to back up, export, or verify the remote staging database (`routeflow-db-staging`).
> - Relying on this script to protect remote staging Cloudflare D1 before applying a migration is **FATALLY INSUFFICIENT**.

### 1.3 Exact Supported Method for Remote Staging D1 Backup
To protect the remote staging database, Cloudflare Wrangler's native remote export facility must be used:

1. **Identification of Staging Database:**
   In `backend/wrangler.toml`:
   ```toml
   [env.staging]
   name = "routeflow-api-staging"
   [[env.staging.d1_databases]]
   binding = "DB"
   database_name = "routeflow-db-staging"
   database_id = "0fd38279-d473-44a8-84a2-76da1a1b7b56"
   ```
2. **Export Command:**
   ```bash
   npx wrangler d1 export routeflow-db-staging --remote --output=backend/db_backups/staging_backup_pre0024.sql
   ```
3. **Artifact Integrity Verification:**
   The output SQL file must be restored into a disposable, isolated local SQLite database to test for syntactical correctness, data preservation, and foreign key integrity:
   ```bash
   sqlite3 backend/db_backups/verify_staging_restore.sqlite < backend/db_backups/staging_backup_pre0024.sql
   ```
   Followed by automated validation:
   - `PRAGMA integrity_check;` (Must return `ok`).
   - `PRAGMA foreign_key_check;` (Must return 0 violations).
   - Record count verification across `users`, `organizations`, and `organization_memberships`.
4. **Prevention of Accidental Production Targeting:**
   - Parameter fencing: Script must explicitly reject `routeflow-db` (production database name) or omitted `--env=staging`.
   - Explicit confirmation check matching `database_id == "0fd38279-d473-44a8-84a2-76da1a1b7b56"`.
   - *No backup or restore commands were executed during this review.*

---

## 2. Verification of Migration Artifacts (Proposed 0024 vs. Tested Artifacts)

### 2.1 Proposed Migration 0024 SQL
```sql
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
) OR role IS NULL;

-- Step 3: Detect & Quarantine Duplicate Memberships
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
        SELECT id, ROW_NUMBER() OVER (
            PARTITION BY organization_id, user_id 
            ORDER BY coalesce(created_at, 0) DESC, id DESC
        ) as rn
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
        'OWNER', 'ADMIN', 'SALES_MANAGER', 'ACCOUNTANT',
        'WAREHOUSE', 'SALES', 'DELIVERY', 'RETAILER'
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
    coalesce(m.is_active, 1),
    coalesce(m.created_at, CAST(strftime('%s', 'now') AS INTEGER) * 1000),
    coalesce(m.created_at, CAST(strftime('%s', 'now') AS INTEGER) * 1000)
FROM organization_memberships m
WHERE m.id NOT IN (SELECT id FROM organization_memberships_quarantine);

-- Step 6: Backup and Table Swap
ALTER TABLE organization_memberships RENAME TO organization_memberships_backup_0024;
ALTER TABLE organization_memberships_v2 RENAME TO organization_memberships;

-- Step 7: Recreate Canonical Indexes
CREATE INDEX IF NOT EXISTS idx_org_memberships_user ON organization_memberships(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_org_memberships_org ON organization_memberships(organization_id, is_active);
```

### 2.2 Verification Against Tested SQL
- The proposed SQL above was verified to be **semantically and structurally identical** to the SQL tested in `scratch/validate_auth13_miniflare.mjs`.
- It preserves all 6 original columns (`id, organization_id, user_id, role, is_active, created_at`), maps legacy aliases (`SALESPERSON` $\to$ `SALES`, `WAREHOUSE_MANAGER` $\to$ `WAREHOUSE`, `DELIVERY_EXECUTIVE` $\to$ `DELIVERY`), adds `updated_at`, and isolates malformed/duplicate rows with zero data loss.

---

## 3. Staging Schema Compatibility & Required Preflight Inspection

### 3.1 Intended Schema vs. Remote Drift Risks
Migration 0024 assumes that the staging database matches the schema established through migrations 0001–0023:
- Table `organizations` exists with primary key `id`.
- Table `users` exists with primary key `id`.
- Table `organization_memberships` has zero incoming foreign key dependencies.
- No unrecognized columns or third-party indexes exist on `organization_memberships`.

### 3.2 Required Preflight Inspection Commands (Read-Only)
Because accessing remote staging Cloudflare D1 requires remote credentials (`CLOUDFLARE_API_TOKEN` or interactive Wrangler login), and this review is strictly document-only, **no remote queries were executed**.

Before executing Migration 0024 on staging, the following four read-only preflight commands must be run by an authorized operator to certify zero schema drift:

```bash
# 1. Inspect actual columns and types on staging
npx wrangler d1 execute routeflow-db-staging --remote --command="PRAGMA table_info(organization_memberships);"

# 2. Check for pre-existing foreign key violations
npx wrangler d1 execute routeflow-db-staging --remote --command="PRAGMA foreign_key_check;"

# 3. Audit existing role distribution on staging
npx wrangler d1 execute routeflow-db-staging --remote --command="SELECT coalesce(role, 'NULL') as role, count(*) FROM organization_memberships GROUP BY role;"

# 4. Check for existing duplicate memberships
npx wrangler d1 execute routeflow-db-staging --remote --command="SELECT organization_id, user_id, count(*) FROM organization_memberships GROUP BY organization_id, user_id HAVING count(*) > 1;"
```

---

## 4. Android ECDSA Evidence Verification: Synthetic vs. Physical Device

### 4.1 Audit of `scratch/test_ecdsa_interop.mjs`
Direct inspection of the test harness executed in Auth-1.6:
- Line 6: `crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' })`
- Line 14: `const signer = crypto.createSign('SHA256'); signer.sign(privateKey);`

### 4.2 Classification of Evidence
> [!IMPORTANT]
> **Definitive Finding:** The signature tested in `test_ecdsa_interop.mjs` was **generated synthetically in Node.js using OpenSSL's EC engine**.
> - It was **NOT** generated on the connected Vivo 1935 hardware.
> - It was **NOT** captured from an actual Android `Signature.getInstance("SHA256withECDSA")` operation.
> - While the test proves the mathematical validity of the `derToP1363()` unpacker in converting OpenSSL DER to WebCrypto P1363, **true Android-to-Worker hardware interoperability remains classified as NOT TESTED**.
> - Live hardware verification requires capturing a signature generated by `AndroidKeyStore` on Vivo 1935 and verifying it against Cloudflare Workers WebCrypto.

---

## 5. CCCR Recovery Failure Matrix

The Client-Committed Candidate Ratchet (CCCR) handles all device, key, and network failure modes deterministically:

| Failure Scenario | Local Client State | Server D1 State | Expected System Behavior | Re-Authentication Required? | New Device Key Enrolled? |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **1. Candidate & Key Available** | Holds $R_i, R_{i+1}$, Keystore key | $H(R_{i+1})$ committed in D1; recovery active | Client signs retry challenge. Worker verifies signature and confirms $H(R_{i+1})$. Returns fresh access token. | **NO** (Seamless recovery) | **NO** |
| **2. Candidate Available, Key Invalidated** | Holds $R_{i+1}$; Keystore key wiped | $H(R_{i+1})$ committed in D1 | Client cannot sign challenge. Worker returns `HTTP 401 Unauthorized`. Client redirects to login screen. | **YES** (Password / Google OAuth) | **YES** |
| **3. Key Available, Candidate Lost** | Holds Keystore key; $R_{i+1}$ unwritten | $H(R_{i+1})$ committed in D1 | Client cannot produce matching candidate token. Worker rejects retry. Client redirects to login screen. | **YES** | **NO** (Key preserved) |
| **4. Both Unavailable** | App data wiped / storage corrupt | $H(R_{i+1})$ committed in D1 | Client has zero session state. Clean redirect to login screen. | **YES** | **YES** |
| **5. App Reinstall / Data Cleared** | Clean sandbox; Keystore alias absent | Session active or expired in D1 | Keystore keys deleted by OS. Next launch presents login screen. | **YES** | **YES** |
| **6. Device Replacement** | New device (no keys, no tokens) | Old device session active in D1 | New device generates fresh key pair. Primary login binds new device key to a distinct session row. | **YES** | **YES** (New key for Device B) |
| **7a. Stolen Refresh Token Alone** | Authentic client active | Attacker holds $R_i$ | Attacker lacks Keystore private key. Cannot sign challenge. Cannot rotate token or recover candidate. | **NO** (Attacker blocked) | **NO** |
| **7b. Stolen Primary Password** | Authentic client active | Attacker logs in on Device B | Attacker authenticates with password, enrolling their own device key. Multi-factor / audit alert triggered. | **YES** (Legitimate owner resets password) | **YES** |

---

## 6. Offline-First Architecture & Persistent Role Session State

To address the specific requirement for field sales operations:

```
[Sales Representative Workflow]
User logs in as SALES ──► Session persisted in FlutterSecureStorage & Local Drift/SQLite
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
       [ONLINE MODE]                    [OFFLINE MODE]
  • Direct sync with Cloudflare     • Operates 100% locally from SQLite
  • CCCR refresh updates token       • Takes orders, collections, routes
  • Fetches inventory & orders       • Orders queued in local outbox
               │                               │
               └───────────────┬───────────────┘
                               ▼
    [RECONNECT EVENT] ──► Background Sync Engine pushes queued
                          orders & reconciles ledger with Cloudflare
```

1. **Persistent Role Session (Login Until Explicit Logout):**
   - When a sales representative logs in, the authenticated session (`active_role = SALES`, `active_organization_id`, `access_token`, `refresh_token`, and device keys) is stored in `flutter_secure_storage` and the local Drift database (`routeflow_tenant_${orgId}.sqlite`).
   - The user remains logged in across process termination, task swiping, and device reboot. They are **never logged out simply because network connectivity is lost**.
2. **Offline-First Resilience:**
   - In network dead zones, the Flutter client **does not block or fail**. All screens (Sales catalog, Retailer lists, Order entry, Cash handover review) operate directly against the local SQLite database.
   - New orders are assigned local UUIDs with `sync_status = PENDING` and committed to the local ledger.
3. **Why Cloudflare Sync is Necessary:**
   - While daily operations proceed offline, Cloudflare Workers + D1 remain the central authority for inventory allocation across multiple vans/godowns, GST invoice number sequencing, and distributor-level credit limit enforcement.
   - When network connectivity resumes, the client sync coordinator transmits the queued outbox to Cloudflare, reconciles ledger transactions, and fetches updated stock levels.

---

## 7. Final Governance Readiness Matrix

| Evaluation Area | Verdict | Justification & Remaining Blockers |
| :--- | :---: | :--- |
| **1. Remote Staging Backup Capability** | **NOT READY** | `backend/tools/backup_sqlite.py` backs up only local Miniflare SQLite. Remote D1 export script (`wrangler d1 export`) is not yet automated or verified. |
| **2. Backup Restore Verification** | **NOT READY** | Remote staging backup artifact has not been created or restored into a disposable SQLite verification instance. |
| **3. Migration Artifact Verification** | **READY** | Migration 0024 SQL is fully verified on Miniflare D1; preserves all 6 columns, normalizes legacy aliases, and isolates malformed/duplicates. |
| **4. Staging Schema Compatibility** | **CONDITIONAL** | Assumed schema matches migrations 0001–0023. Remote preflight inspection commands are specified but have not been executed on remote staging D1. |
| **5. Android ECDSA Interoperability** | **NOT TESTED** | `test_ecdsa_interop.mjs` was executed with synthetic Node.js OpenSSL keys; signature capture from actual Vivo 1935 hardware Keystore remains pending. |
| **6. CCCR Recovery Completeness** | **READY** | Failure matrix, state transitions, transcript bindings, and offline-first persistence model are completely specified. |
| **7. Migration 0024 Staging Execution** | **NOT READY** | Blocked on automated remote staging D1 backup creation and preflight schema verification. |
| **8. Auth Implementation Eligibility** | **NOT READY** | Separate gate. Blocked on staging migration execution, remote backup verification, and live Android Keystore signature capture. |

---

## 8. Final Governance Decision

### **NOT APPROVED FOR STAGING MIGRATION**

#### Mandatory Blockers Before Staging Migration Can Be Approved:
1. **Remote Staging Backup Tooling:** Create and verify an automated remote backup script utilizing `npx wrangler d1 export routeflow-db-staging --remote` that restores into an isolated SQLite database and verifies `PRAGMA foreign_key_check`.
2. **Read-Only Remote Preflight Audit:** Execute the four specified read-only preflight inspection queries against `routeflow-db-staging` to certify zero schema drift and zero pre-existing foreign key violations.
3. **Hardware Signature Capture:** Capture an actual DER signature from `AndroidKeyStore` on the connected Vivo 1935 device and verify it against Cloudflare Workers WebCrypto using `derToP1363()`.

*Authentication implementation (Auth-2 through Auth-9) remains strictly unapproved under its separate governance gate.*
