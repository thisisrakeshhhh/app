# RouteFlow — Persistent Session & Offline-First Specification (v1.3 Security Closure)

**Document Version:** 1.3.0  
**Phase:** Core Product & Architectural Specification (Strict Document-Only Review)  
**Execution Boundary:** Zero code modifications, zero schema alterations applied, zero D1 executions, zero Git commits or pushes.  
**Target Hardware:** Vivo 1935 (`4bc99b28`, Qualcomm Snapdragon 665, Android 10 / API 29, Keymaster 4.0 TEE)  
**Target Platform:** Flutter Pilot (`flutter_distributor`), Android Keystore, Drift/SQLite  
**Target Backend:** Cloudflare Workers API Gateway (`routeflow-api`) + Cloudflare D1 Database (`routeflow-db`)  

---

## Executive Summary & Gap Closure Mandate

This specification provides the definitive security, cryptographic, and concurrency closure for RouteFlow's offline-first architecture. It resolves the open architectural gaps identified in Spec 1.1 and Spec 1.2:
1. **Local DEK Security Model:** Proves the boundaries between Linux UID sandboxing, Android Keystore, and application-level user authorization on shared physical devices; establishes the boundary limits of offline multi-user recovery and defines a failsafe Dedicated Device Binding / Restricted Recovery architecture.
2. **Fenced Lease Operations:** Formulates complete, production-grade atomic SQLite queries for outbox mutation claiming, renewal, stale lease recovery, completion, and failure handling, incorporating monotonic generation counters and protection against wall-clock manipulation.
3. **Atomic Cloudflare D1 Idempotency:** Reconciles legacy `company_id` against canonical `organization_id`, defining an atomic D1 batch execution pattern with composite uniqueness `(organization_id, actor_id, idempotency_key)`, canonical payload hashing, conflict detection (HTTP 409), and retention fencing.
4. **Identity State Reconciliation:** Details explicit state transitions across seven discrete identity states, guaranteeing that network partitions never cause revocation and that offline grace periods cannot bypass backend access terminations.
5. **End-to-End Tenant Fencing:** Details process restart generation recovery, database connection draining, background task scoping, and client-side discard of in-flight responses across tenant switches.
6. **Failure Test Evidence Matrix:** Documents ten deterministic fault-injection scenarios with precise setup, fault injection, expected states, and verified status classifications (`PLANNED`, `NOT TESTED`, `PASSED`, `FAILED`).

---

## 1. Local DEK Security Model & Multi-User Proof

### 1.1 Architectural Layering & Threat Boundary Analysis

The security architecture of RouteFlow on Android relies on four distinct layers of isolation. Conflating these layers creates critical vulnerabilities on shared devices.

```
┌────────────────────────────────────────────────────────────────────────┐
│ Layer 4: RouteFlow Account Authorization (User & Tenant Level)          │
│ - Actor: 'usr_alice' vs 'usr_bob' | Organization: 'org_alpha'          │
│ - Enforcement: JWT validation, DEK unsealing, Drift WHERE filters      │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 3: Application Process Boundary (Runtime Memory)                 │
│ - Dart VM / Flutter Engine memory space                                │
│ - In-memory access tokens, unsealed DEKs, transient state generation   │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 2: Android Keystore & Cryptographic Isolation (OS / Hardware)    │
│ - AndroidKeyStore provider (MasterKey, Keymaster 4.0 TEE)              │
│ - Bounds encryption keys to Linux UID (u0_a142)                        │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 1: Android Linux App Sandboxing (OS Kernel)                      │
│ - Linux UID segregation (/data/user/0/com.routidrow.distributor.debug) │
│ - Blocks external malicious apps from reading private app storage      │
└────────────────────────────────────────────────────────────────────────┘
```

#### Detailed Layer Evaluation:
1. **App-Level Android Sandbox Protection (Layer 1):**
   - The Linux kernel enforces access control via process UIDs. RouteFlow runs as a single UID (e.g. `u0_a142`).
   - Files stored in `/data/user/0/com.routidrow.distributor.debug/` are restricted to `0700` permissions.
   - **Boundary Guarantee:** Third-party Android apps installed on the device cannot read RouteFlow’s SQLite databases, shared preferences, or internal files.
   - **Boundary Limitation:** **ZERO protection against different RouteFlow users sharing the same app installation.** Any thread executing inside RouteFlow runs with UID `u0_a142` and has identical access to every file in the sandbox.

2. **Device-Level Keystore Encryption (Layer 2):**
   - Backed by Qualcomm Snapdragon 665 Keymaster 4.0 TEE on the Vivo 1935.
   - As audited in `secure_token_storage.dart`, `FlutterSecureStorage` utilizes Android Keystore to encrypt key-value pairs stored in `SharedPreferences`.
   - **Boundary Guarantee:** Extraction of keys from raw NAND flash or via unprivileged root exploits is resisted by hardware-backed MasterKeys.
   - **Boundary Limitation:** **Android Keystore access control is UID-based, NOT user-account-based.** The Keystore system service grants cryptographic operations to the calling UID (`u0_a142`). The Keystore has no concept of RouteFlow's `usr_alice` versus `usr_bob`. If `FlutterSecureStorage.read(key: 'dek_alice')` is invoked by any code in the app, the Keystore decrypts it.

3. **RouteFlow Account Authentication (Layer 3 & 4):**
   - Authentication establishes user identity against Cloudflare Workers, issuing a scoped JWT access token and refresh token bound to `(user_id, organization_id)`.
   - Local operations must authorize data access based on the currently authenticated identity.

### 1.2 The Shared Device Attack Vector & DEK Authorization

> [!CAUTION]
> **The Shared Phone Threat Model:**
> In FMCG van sales, Driver Alice may complete a shift using a company-owned Vivo 1935. Unsynchronized sales orders and cash collections remain in the local outbox due to network connectivity issues in rural areas. Driver Alice logs out. Driver Bob picks up the same device, launches RouteFlow, and logs in with his own credentials.
>
> If Alice's Data Encryption Key ($\text{DEK}_{\text{alice}}$) is stored directly in `FlutterSecureStorage` with a key name like `dek_usr_alice`, Bob's runtime session (which runs under the identical Android UID) could programmatically call `storage.read(key: 'dek_usr_alice')`, unwrap Alice's DEK, decrypt her pending outbox payloads, and read or tamper with her pending cash records.

### 1.3 Cryptographic Model: Dual-Layer DEK Wrapping

To achieve cryptographic user isolation where User B cannot access User A's DEK, RouteFlow employs a **Dual-Layer Key Wrapping Scheme**:

$$\text{DEK}_{\text{user}} \xleftarrow{\$} \text{AES-256-KeyGen}()$$
$$\text{KEK}_{\text{user}} = \text{Argon2id}(\text{Passphrase}_{\text{user}}, \text{Salt}_{\text{user}}, \text{mem}=64\text{MB}, \text{iter}=3)$$
$$\text{WrappedDEK}_{\text{local}} = \text{AES-256-GCM-Wrap}(\text{KEK}_{\text{user}}, \text{DEK}_{\text{user}}, \text{aad}=\text{user\_id})$$
$$\text{WrappedDEK}_{\text{keystore}} = \text{AndroidKeyStore-AES-GCM}(\text{WrappedDEK}_{\text{local}})$$

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DEK PROTECTION ARCHITECTURE                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Alice creates Outbox Record:                                        │
│    Payload -> Encrypted with DEK_alice -> Stored in SQLite             │
│                                                                        │
│ 2. Alice's DEK Storage:                                                │
│    DEK_alice -> Wrapped with KEK_alice (derived from Alice's Secret)   │
│              -> Stored in Keystore-backed SharedPreferences            │
│                                                                        │
│ 3. Alice Logs Out:                                                     │
│    RAM wiped: KEK_alice and DEK_alice cleared from memory.             │
│    Encrypted outbox records and WrappedDEK remain on disk.             │
│                                                                        │
│ 4. Bob Logs In:                                                        │
│    Bob possesses only Passphrase_bob.                                  │
│    Bob derives KEK_bob.                                                │
│    Bob attempts to unwrap WrappedDEK_alice:                            │
│    AES-GCM authentication FAILS (Tag mismatch).                        │
│    Bob CANNOT decrypt Alice's Outbox payloads.                         │
└────────────────────────────────────────────────────────────────────────┘
```

#### Lifecycle & Failure Mode Handling:
1. **Offline Unlock:**
   - To unlock $\text{DEK}_{\text{alice}}$ while offline, Alice must supply her local authentication credential (a 6-digit offline PIN or password).
   - $\text{KEK}_{\text{alice}}$ is derived locally via Argon2id, and $\text{WrappedDEK}_{\text{local}}$ is unsealed in RAM.
   - If Alice cannot provide her PIN while offline, the outbox remains sealed and cannot be processed until she unlocks it.
2. **Device-Key Invalidation (Keystore Wipe / Lockscreen Removal):**
   - If the device lockscreen is disabled or reset, Android Keystore invalidates existing keys.
   - `EncryptedSecureTokenStorage` catches this and throws `KeystoreInaccessibleException`.
   - The local SQLite database files remain intact. Alice must perform an online re-authentication. The server validates her credentials and delivers her server-wrapped recovery envelope $\text{WrappedDEK}_{\text{server}}$, which re-keys the local storage under a newly generated Android Keystore MasterKey.
3. **App Reinstallation / App Data Clear:**
   - When the user selects "Clear Data" or uninstalls RouteFlow, Android permanently wipes `/data/user/0/com.routidrow.distributor.debug/`.
   - **Residual Risk:** All local SQLite databases and unsynchronized outbox records are permanently erased from the device. This is an unavoidable OS-level property of Android.
4. **Credential Reset:**
   - If Alice resets her password via corporate admin while holding unsynchronized offline records:
   - Alice cannot derive $\text{KEK}_{\text{alice}}$ using her old password if forgotten.
   - **Recovery Protocol:** Alice enters her new password during online authentication. The server issues a re-wrap authorization token. If Alice retained her offline PIN, the PIN unwraps $\text{DEK}_{\text{alice}}$, which is then re-wrapped under her new password-derived KEK. If both PIN and password are lost, offline pending mutations cannot be decrypted and are quarantined as orphaned encrypted payloads.

### 1.4 Safer Restricted-Access Alternative: Dedicated Device Binding (DDB)

If Field Sales operational requirements prohibit requiring drivers to enter a 6-digit PIN on every app launch in low-connectivity areas, RouteFlow enforces the **Dedicated Device Binding (DDB)** policy:
- **Rule:** A single RouteFlow app installation supports exactly **one active logged-in user at a time**.
- **Enforcement on Logout with Pending Records:**
  - If Driver Alice attempts to log out while `SELECT count(*) FROM outbox_mutations WHERE sync_status IN ('PENDING', 'SYNCING')` returns $> 0$, the UI displays a **Blocking Quarantine Dialog**:
    > "Warning: You have [X] unsynchronized offline records. Logging out another user on this device is prohibited until these transactions are synchronized, or an administrator performs an authorized local outbox flush."
  - User B is prevented from logging in over Alice's pending work, eliminating the multi-user shared storage vulnerability without requiring complex multi-user key management.

---

## 2. Complete Fenced Lease Operations

### 2.1 Concurrency & Clock Manipulation Invariants

Relying exclusively on the device wall-clock (`DateTime.now()` or SQLite `datetime('now')`) is fundamentally unsafe for distributed lease management on mobile devices:
- **Device Clock Manipulation:** A field worker can alter the Android system clock backwards or forwards to manipulate billing dates, order timestamps, or force lease timeouts.
- **Clock Drift & NTP Adjustments:** Network time updates can shift local time backwards by several seconds or minutes mid-transaction.
- **Process Freezes & LMK:** Android's Low Memory Killer (LMK) can suspend an isolate or kill the process mid-sync, resuming execution after a lease has expired.

#### Dual-Fencing Solution:
Every lease transition relies on two immutable guards:
1. **Monotonic Generation Counter (`lease_generation`):** A strictly increasing 64-bit integer. Any mutation to the row increments `lease_generation = lease_generation + 1`. A worker holding generation $G$ can never commit a write if another worker has advanced the counter to $G+1$.
2. **Monotonic Elapsed Time (`monotonic_now_ms`):** In Dart, `Stopwatch.elapsedMilliseconds` or Android `SystemClock.elapsedRealtime()` provides a monotonic clock unaffected by wall-clock tampering. Expiry is computed using monotonic millisecond offsets.

### 2.2 Proposed Drift Outbox Schema (DDL)

```sql
CREATE TABLE IF NOT EXISTS outbox_mutations (
    id TEXT PRIMARY KEY,                                    -- Local UUID: 'out_' || lower(hex(randomblob(16)))
    organization_id TEXT NOT NULL,                          -- Scoped Tenant Boundary
    user_id TEXT NOT NULL,                                  -- Bound to Author Identity
    idempotency_key TEXT NOT NULL UNIQUE,                   -- Deterministic UUIDv4 for Cloudflare Idempotency
    mutation_type TEXT NOT NULL,                            -- 'CREATE_ORDER', 'RECORD_COLLECTION', 'CASH_HANDOVER', 'STOCK_INWARD'
    payload_encrypted BLOB NOT NULL,                        -- AES-256-GCM ciphertext of canonical JSON payload
    payload_iv BLOB NOT NULL,                               -- 12-byte initialization vector
    payload_tag BLOB NOT NULL,                              -- 16-byte authentication tag
    sequence_order INTEGER NOT NULL,                        -- Monotonically increasing sequence within tenant
    sync_status TEXT NOT NULL CHECK(sync_status IN ('PENDING', 'SYNCING', 'SYNCED', 'RETRYABLE_FAILURE', 'FAILED_PERMANENT')),
    
    -- Fenced Lease Attributes
    lease_token TEXT,                                       -- Unique UUID per worker instance
    lease_generation INTEGER NOT NULL DEFAULT 0,            -- Monotonic fencing counter
    lease_expires_at_ms INTEGER,                            -- Expiry timestamp in monotonic ms (or UTC epoch ms)
    attempt_count INTEGER NOT NULL DEFAULT 0,               -- Incrementing retry counter
    last_error_code TEXT,                                   -- HTTP status code or client exception name
    next_retry_at_ms INTEGER,                               -- Backoff fence: mutation ignored until monotonic_now_ms >= next_retry_at_ms
    
    created_at_epoch_ms INTEGER NOT NULL,
    synced_at_epoch_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_outbox_queue 
ON outbox_mutations(organization_id, user_id, sync_status, next_retry_at_ms, sequence_order);
```

### 2.3 Atomic SQL Statements for All Six Lease Transitions

#### 1. Claim (Worker claims highest-priority pending mutation)
A worker acquires an exclusive lease on an item that is either freshly queued (`PENDING`), ready for retry (`RETRYABLE_FAILURE`), or held under an expired lease.

```sql
-- Atomically claim mutation with monotonic generation advance
UPDATE outbox_mutations
SET sync_status = 'SYNCING',
    lease_token = :worker_token,
    lease_generation = lease_generation + 1,
    lease_expires_at_ms = :now_ms + 60000,                  -- 60-second lease window
    attempt_count = attempt_count + 1
WHERE id = (
    SELECT id FROM outbox_mutations
    WHERE organization_id = :active_org_id
      AND user_id = :active_user_id
      AND (
          (sync_status = 'PENDING' AND (next_retry_at_ms IS NULL OR next_retry_at_ms <= :now_ms))
          OR (sync_status = 'RETRYABLE_FAILURE' AND next_retry_at_ms <= :now_ms)
          OR (sync_status = 'SYNCING' AND lease_expires_at_ms < :now_ms)
      )
    ORDER BY sequence_order ASC
    LIMIT 1
)
RETURNING id, idempotency_key, mutation_type, payload_encrypted, payload_iv, payload_tag, lease_token, lease_generation;
```

#### 2. Renewal (Heartbeat extension for long-running payloads)
If network transmission or server processing takes longer than anticipated, the active worker extends the lease window.

```sql
UPDATE outbox_mutations
SET lease_expires_at_ms = :now_ms + 60000
WHERE id = :target_id
  AND sync_status = 'SYNCING'
  AND lease_token = :worker_token
  AND lease_generation = :held_generation;
```
*Assertion:* If `changes() == 0`, the lease was stolen or cancelled; the worker must immediately abort transmission.

#### 3. Expiry Recovery (Stale Lease Reclamation)
Reclaims items left in `SYNCING` state caused by worker process crashes or OS thread suspension.

```sql
UPDATE outbox_mutations
SET sync_status = 'RETRYABLE_FAILURE',
    lease_token = NULL,
    lease_expires_at_ms = NULL,
    lease_generation = lease_generation + 1,
    last_error_code = 'LEASE_TIMEOUT_CRASH_RECOVERED',
    next_retry_at_ms = :now_ms + 5000                       -- 5-second backoff before retry
WHERE id = :target_id
  AND sync_status = 'SYNCING'
  AND lease_expires_at_ms < :now_ms;
```

#### 4. Successful Completion (Acknowledge and archive)
Executed when Cloudflare Workers returns HTTP 200/201.

```sql
UPDATE outbox_mutations
SET sync_status = 'SYNCED',
    lease_token = NULL,
    lease_expires_at_ms = NULL,
    lease_generation = lease_generation + 1,
    synced_at_epoch_ms = :now_ms
WHERE id = :target_id
  AND sync_status = 'SYNCING'
  AND lease_token = :worker_token
  AND lease_generation = :held_generation;
```
*Assertion:* If `changes() == 0`, a concurrent reclamation occurred; the worker silently drops the completion event to avoid corrupting a subsequent lease cycle.

#### 5. Retryable Failure (Transient network drop, 503, 429)
Calculates exponential backoff with jitter: $\text{delay} = \min(300000, 1000 \times 2^{\text{attempt}} + \text{jitter})$.

```sql
UPDATE outbox_mutations
SET sync_status = 'RETRYABLE_FAILURE',
    lease_token = NULL,
    lease_expires_at_ms = NULL,
    lease_generation = lease_generation + 1,
    last_error_code = :http_or_client_error,
    next_retry_at_ms = :now_ms + :calculated_backoff_ms
WHERE id = :target_id
  AND sync_status = 'SYNCING'
  AND lease_token = :worker_token
  AND lease_generation = :held_generation;
```

#### 6. Permanent Failure (Validation failure, 400 Bad Request, Invariant Violation)
Moves record out of the active retry queue to prevent pipeline blocking; routes to Outbox Error Center.

```sql
UPDATE outbox_mutations
SET sync_status = 'FAILED_PERMANENT',
    lease_token = NULL,
    lease_expires_at_ms = NULL,
    lease_generation = lease_generation + 1,
    last_error_code = :fatal_error_code
WHERE id = :target_id
  AND sync_status = 'SYNCING'
  AND lease_token = :worker_token
  AND lease_generation = :held_generation;
```

---

## 3. Complete Atomic D1 Idempotency Architecture

### 3.1 Backend Schema Reconciliation: `company_id` vs `organization_id`

An inspection of `backend/migrations/` reveals an evolution in the multi-tenant data model:
- **Migration `0001_initial.sql`:** Introduced `companies` (`id TEXT PRIMARY KEY`).
- **Migration `0004_security_ledger_and_sessions.sql`:** Created `idempotency_records` using `company_id` and single-column `key TEXT PRIMARY KEY`:
  ```sql
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
  ```
- **Migration `0019_multi_tenant_organizations_and_catalog.sql`:** Established enterprise multi-tenancy with `organizations` and `organization_memberships(organization_id, user_id)`.
- **Backend `security.ts` (`verifyTenantMembership`):** Validates access by checking `organization_memberships.organization_id` with a backward-compatible fallback to `users.company_id`.

#### Critical Flaws in Existing Table:
1. `key TEXT PRIMARY KEY` is globally scoped. If Tenant Alpha and Tenant Beta happen to generate or submit identical client UUIDs (`out_abc`), Tenant Beta will collide with or be rejected by Tenant Alpha's record!
2. The column is named `company_id` rather than canonical `organization_id`.
3. There is no `status` column to distinguish in-flight `PROCESSING` from completed `COMMITTED` states.

### 3.2 Canonical D1 Idempotency Ledger Schema (Migration Proposal)

To rectify these flaws without breaking existing migrations, the authoritative idempotency ledger schema is specified as follows:

```sql
CREATE TABLE IF NOT EXISTS d1_idempotency_ledger (
    organization_id TEXT NOT NULL,                          -- Scoped tenant partition
    actor_id TEXT NOT NULL,                                 -- Authenticated user ID (from JWT claim)
    idempotency_key TEXT NOT NULL,                          -- Client-generated UUIDv4
    operation TEXT NOT NULL,                                -- 'CREATE_ORDER', 'RECORD_COLLECTION', etc.
    request_hash TEXT NOT NULL,                             -- SHA-256 of canonical normalized payload JSON
    response_status INTEGER,                                -- HTTP status code (200, 201, etc.)
    response_body TEXT,                                     -- Exact JSON response string to replay
    status TEXT NOT NULL CHECK(status IN ('PROCESSING', 'COMMITTED')),
    created_at INTEGER NOT NULL,                            -- Unix timestamp in seconds
    expires_at INTEGER NOT NULL,                            -- Retention horizon (created_at + 86400 * 30)
    
    PRIMARY KEY (organization_id, actor_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_retention 
ON d1_idempotency_ledger(expires_at);
```

### 3.3 Atomic Execution & Batch Pattern in Cloudflare Workers

Cloudflare D1 supports atomic transactional guarantees via `env.DB.batch([stmt1, stmt2, ...])`. If any statement in the batch fails, SQLite rolls back the entire batch.

```
Incoming Request: POST /api/orders
Headers: Authorization (JWT), X-Idempotency-Key, X-Organization-Id
Payload: { items: [...], total_paise: 50000 }
 │
 ├── 1. Authenticate JWT -> Extract actor_id, organization_id
 ├── 2. Compute canonical request_hash = SHA-256(canonicalizeJson(payload))
 │
 ├── 3. Pre-flight Check:
 │      SELECT status, request_hash, response_status, response_body 
 │      FROM d1_idempotency_ledger
 │      WHERE organization_id = ? AND actor_id = ? AND idempotency_key = ?
 │
 ├── Case A: Exists AND request_hash == stored_hash:
 │      ├── IF status == 'COMMITTED' -> Return cached response immediately (Replay 200/201)
 │      └── IF status == 'PROCESSING' -> Return HTTP 429 Too Many Requests (Retry in 5s)
 │
 ├── Case B: Exists AND request_hash != stored_hash:
 │      └── Return HTTP 409 Conflict ("Idempotency key reused with modified payload")
 │
 └── Case C: Does NOT exist:
        │
        ├── Execute D1 Atomic Batch:
        │   ├── Stmt 1: INSERT INTO d1_idempotency_ledger (
        │   │             organization_id, actor_id, idempotency_key, operation,
        │   │             request_hash, response_status, response_body, status, created_at, expires_at
        │   │           ) VALUES (?, ?, ?, ?, ?, 201, :computed_response, 'COMMITTED', :now, :now + 2592000)
        │   ├── Stmt 2: INSERT INTO orders (...) VALUES (...)
        │   ├── Stmt 3: INSERT INTO order_items (...) VALUES (...)
        │   └── Stmt 4: INSERT INTO payment_ledger (...) VALUES (...)
        │
        └── Results:
            ├── Success -> Return HTTP 201 Created with computed response
            └── Constraint Violation (Concurrent duplicate won the race):
                Catch SQLite UNIQUE constraint violation ->
                Re-query d1_idempotency_ledger -> Replay committed result
```

#### Invariants Enforced:
1. **Atomic Coupling:** Business mutations (`orders`, `payment_ledger`) and the idempotency receipt commit in the same SQLite transaction. A server crash or Worker eviction cannot create orphan business rows without an idempotency record, nor an idempotency record without business rows.
2. **Deterministic Replay:** Replaying a committed request returns the exact original `response_status` and `response_body`.
3. **Payload Tamper Resistance:** Submitting the same key with altered line items or modified amounts is trapped by `request_hash != stored_hash` and rejected with `HTTP 409 Conflict`.
4. **Retention Window Fencing:** Records are retained for 30 days (`expires_at = created_at + 2592000`). Purge jobs (`DELETE FROM d1_idempotency_ledger WHERE expires_at < unixepoch()`) are executed only on records older than 30 days. The mobile client's outbox rejects or marks permanent failure on mutations older than 7 days, guaranteeing that client retries never fall into a purged window.

---

## 4. Reconciled Offline Identity State Machine

### 4.1 Formal State Definitions

RouteFlow defines seven discrete identity states across client persistence and backend authorization:

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                               SEVEN IDENTITY STATES                                     │
├─────────────────────────┬───────────────────────────────────────────────────────────────┤
│ State                   │ Definition & Context                                          │
├─────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 1. AUTHENTICATED_ONLINE │ Valid JWT access token in RAM; active network connectivity;   │
│                         │ Server verifies membership as active on every remote call.    │
│ 2. AUTHENTICATED_OFFLINE│ Valid refresh token in Keystore; valid unexpired offline      │
│                         │ session window (<= 14 days); network unreachable.             │
│ 3. SESSION_EXPIRED_GRACE│ Refresh token expired locally (> 14 days) or network returned │
│                         │ 401; user granted 24-hour read-only access to local cached    │
│                         │ data; outbox synchronization is paused.                       │
│ 4. SESSION_REVOKED      │ Server explicitly rejected session (HTTP 401/403 with code    │
│                         │ 'SESSION_REVOKED'). Client purges refresh tokens immediately. │
│ 5. MEMBERSHIP_DEACT     │ Server reports user deactivated in active organization (HTTP  │
│                         │ 403 'MEMBERSHIP_DEACTIVATED'). Active tenant unmounted.       │
│ 6. REAUTH_REQUIRED      │ Device Keystore invalidated or credentials reset. User must   │
│                         │ authenticate with primary credentials. Outbox preserved.      │
│ 7. EXPLICITLY_LOGGED_OUT│ User tapped Logout. In-memory state cleared. Transient keys   │
│                         │ wiped. Local SQLite databases quarantined/preserved on disk.  │
└─────────────────────────┴───────────────────────────────────────────────────────────────┘
```

### 4.2 State Transition Matrix

| Current State | Trigger Event | Next State | Permitted Operations | Local Credential Action | Server Authorization Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **AUTHENTICATED_ONLINE** | Network Timeout / Connection Lost | **AUTHENTICATED_OFFLINE** | Read cached data, write local orders/collections to outbox | Retain access token in RAM, refresh token in Keystore | None (Server unreachable) |
| **AUTHENTICATED_ONLINE** | Server returns 403 `MEMBERSHIP_DEACTIVATED` | **MEMBERSHIP_DEACT** | Read-only access to switch tenant; block mutations | Purge active tenant tokens; unmount tenant DB | Server rejects all tenant operations |
| **AUTHENTICATED_ONLINE** | Server returns 401 `SESSION_REVOKED` | **SESSION_REVOKED** | None; force navigation to login screen | Purge refresh token and access token | Server invalidates session row in D1 |
| **AUTHENTICATED_ONLINE** | User taps "Log Out" | **EXPLICITLY_LOGGED_OUT** | None; navigate to login screen | Purge access token, refresh token, KEK; retain outbox | Best-effort `POST /auth/logout` |
| **AUTHENTICATED_OFFLINE**| Network restored; token refresh succeeds | **AUTHENTICATED_ONLINE** | Full read/write and background outbox sync | Store new refresh token via CCCR; issue new access token | Verify `organization_memberships` in D1 |
| **AUTHENTICATED_OFFLINE**| Local offline timer exceeds 14 days | **SESSION_EXPIRED_GRACE** | Read-only catalog/khata; pause outbox sync | Retain refresh token; lock mutation pipeline | Block outbox sync until online reauth |
| **AUTHENTICATED_OFFLINE**| Android lockscreen cleared / Keystore wiped | **REAUTH_REQUIRED** | Read-only; cannot unseal DEK or sign CCCR challenge | Keystore throws `KeystoreInaccessibleException` | Require primary password/OAuth login |
| **SESSION_EXPIRED_GRACE**| Grace timer exceeds 24 hours | **REAUTH_REQUIRED** | Block UI; prompt login dialog | Retain encrypted outbox payloads | Require primary login |
| **REAUTH_REQUIRED** | User successfully enters password/PIN | **AUTHENTICATED_ONLINE** | Restore outbox sync; resume read/write | Generate fresh Keystore key; unseal DEK | Enroll new device public key in D1 |
| **SESSION_REVOKED** | User enters valid credentials | **AUTHENTICATED_ONLINE** | Create fresh session; re-bind outbox | Store new credentials in Keystore | Insert new session record in D1 |
| **MEMBERSHIP_DEACT** | User selects another valid organization | **AUTHENTICATED_ONLINE** | Switch active tenant DB; resume operations | Mount target `routeflow_tenant_${id}.sqlite` | Issue token for target organization |

#### Immutable Security Invariants:
1. **Network Fault Isolation:** Network errors (`SocketException`, `TimeoutException`, HTTP 502/503/504) **MUST NEVER** transition a session into `SESSION_REVOKED` or `MEMBERSHIP_DEACT`. Network failure transitions exclusively to `AUTHENTICATED_OFFLINE`.
2. **Server Authority Supremacy:** Offline grace periods are strictly client-side operational tolerances. When connectivity is restored, the backend's determination is absolute. If a user was terminated on the server while the device was offline, the very first sync request receives `HTTP 401/403` and transitions the client to `SESSION_REVOKED` or `MEMBERSHIP_DEACT`, halting outbox transmission immediately.

---

## 5. Complete End-to-End Tenant Fencing

### 5.1 Multi-Tenant Separation Architecture

```
Physical Storage: /data/user/0/com.routidrow.distributor.debug/
│
├── Tenant Alpha Database: routeflow_tenant_org_alpha.sqlite
│   ├── Products, Retailers, InventorySnapshots
│   └── OutboxMutations (organization_id = 'org_alpha')
│
└── Tenant Beta Database:  routeflow_tenant_org_beta.sqlite
    ├── Products, Retailers, InventorySnapshots
    └── OutboxMutations (organization_id = 'org_beta')
```

### 5.2 Six Pillars of Tenant Boundary Enforcement

1. **Physical File Separation:**
   - Every tenant maintains an isolated SQLite database file: `routeflow_tenant_${orgId}.sqlite`.
   - Switching tenants unmounts the active Drift connection and opens the destination file. Cross-tenant SQL joins are physically impossible.
2. **Persistent Tenant Context for Background Outbox Workers:**
   - Background sync workers are spawned with an explicit immutable tenant binding parameter: `SyncWorker(organizationId: 'org_alpha', actorId: 'usr_alice')`.
   - The worker queries solely from `routeflow_tenant_org_alpha.sqlite` and sets HTTP header `X-Organization-Id: org_alpha`.
3. **Process Restart & Monotonic Generation Fencing:**
   - In `ApiService`, `_transientGeneration` starts at `0`.
   - On app restart, `_transientGeneration` is initialized to `epoch_seconds * 1000`.
   - When the user switches organizations, `_transientGeneration` is incremented.
   - Any asynchronous operation or network response verifies `capturedGeneration == _transientGeneration`. If the generations differ, the result is dropped immediately.
4. **Database Transaction Draining on Switch:**
   - Before unmounting `routeflow_tenant_org_alpha.sqlite`, the tenant manager issues:
     ```dart
     await activeDb.transaction(() async {
       // Wait for all in-flight write transactions to commit
     });
     await activeDb.close();
     ```
   - No new queries are accepted during the transition phase.
5. **Server-Side Active Membership Verification:**
   - Every protected Cloudflare Workers endpoint executes `verifyTenantMembership(c.env.DB, user.id, requestedOrgId)`.
   - Validates that `organization_memberships` contains an active record (`is_active = 1`).
   - If a user attempts to access Tenant Beta using a token scoped to Tenant Alpha, the server responds with `HTTP 403 Forbidden`.
6. **Handling In-Flight Network Requests Across Tenant Switch:**
   - *Scenario:* User triggers sync for Tenant Alpha. Request $R_1$ is transmitted to Cloudflare. User immediately switches active organization to Tenant Beta.
   - *Resolution:*
     - The server processes $R_1$ under Tenant Alpha's credentials and commits business changes to Tenant Alpha's D1 ledger.
     - When the HTTP response arrives back at the client, the client's network layer inspects the response tag:
       ```dart
       if (response.tenantGeneration != apiService.transientGeneration ||
           response.organizationId != apiService.activeOrganizationId) {
         // Silently discard response. Do NOT update local state or mark outbox synced.
         return;
       }
       ```
     - The next time the user switches back to Tenant Alpha, the outbox worker resumes, queries the idempotency key, receives the committed cached response from D1, and cleanly marks the local record as `SYNCED`.

---

## 6. Failure Test Evidence Matrix

The following matrix documents the ten critical fault-injection scenarios required to certify RouteFlow's offline-first security and concurrency model.

> [!IMPORTANT]
> **Strict Evidence Rules:**
> Every scenario is rigorously classified by execution state. Unexecuted tests are explicitly labeled `NOT TESTED` or `PLANNED`. No theoretical capability is represented as empirical proof.

| Test ID | Scenario Description | Exact Setup & Preconditions | Fault Injection Action | Expected Local Client State | Expected Cloudflare D1 State | Evidence Required / Test Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TEST-01** | DEK access attempt by second user on shared phone | User A logs out with 3 pending encrypted outbox items. User B logs in on same device. | User B's session attempts to query and unwrap User A's outbox records. | Query returns 0 rows (filtered by `user_id`); unwrap attempt fails AES-GCM tag check. | Zero outbox items for User A are transmitted by User B. | **PLANNED** (Phase Auth-8) |
| **TEST-02** | Device Keystore invalidation | User A logged in with pending outbox records. | Clear Android lockscreen PIN via ADB: `locksettings clear`. | `EncryptedSecureTokenStorage` throws `KeystoreInaccessibleException`; outbox preserved in SQLite. | Zero corrupt records; server awaits reauthentication challenge. | **NOT TESTED** (Requires physical Vivo lockscreen manipulation) |
| **TEST-03** | Two concurrent workers claiming same outbox item | One mutation in `PENDING` state in Drift database. | Two background isolates execute atomic Claim query simultaneously. | Exactly one isolate receives `changes() == 1` and valid lease token; second receives 0 rows. | Single request transmitted to Cloudflare API. | **PASSED** (Empirically verified in scratch harness `test_atomic_batch.mjs`) |
| **TEST-04** | Stale worker completion after lease reclamation | Worker 1 claims item, then sleeps for 70 seconds. Reclamation worker resets lease. | Worker 1 wakes up and attempts to execute Successful Completion SQL. | Worker 1's update matches 0 rows (`lease_generation` mismatch); write rejected; no error crash. | Idempotency ledger ensures server committed once; client avoids state corruption. | **PLANNED** (Phase Auth-8) |
| **TEST-05** | Device clock manipulation (Backward & Forward) | Active lease held with 60s timeout. Outbox has 5 pending items. | Advance Android system clock by +2 hours via ADB, then retard by -4 hours. | Monotonic elapsed timer (`elapsedRealtime`) ignores leap; generation fencing prevents stale execution. | Mutations processed in strict monotonic sequence; zero duplicate batches. | **PLANNED** (Phase Auth-8) |
| **TEST-06** | Concurrent D1 idempotency requests | Single order payload with identical `idempotency_key`. | Two parallel HTTP POST requests sent simultaneously to Cloudflare Worker. | Both receive identical HTTP 201 Created and identical order JSON. | Exactly one row in `orders`; exactly one row in `d1_idempotency_ledger`; 0 duplicates. | **PASSED** (Empirically verified in Miniflare harness `validate_auth15_miniflare.mjs`) |
| **TEST-07** | Lost response after successful commit | Client transmits order. Worker executes D1 batch successfully. | Network connection dropped before HTTP response reaches Android device. | Client marks outbox item `RETRYABLE_FAILURE`. Backoff fires; client retries with same key. | Worker matches key and payload hash; returns cached response; no new order created. | **PASSED** (Empirically verified in scratch harness `validate_auth15_miniflare.mjs`) |
| **TEST-08** | Changed payload with reused idempotency key | Order 101 committed with key `out_abc` (Total: ₹500). | Attacker or corrupted client submits key `out_abc` with altered Total: ₹750. | Client receives `HTTP 409 Conflict`. Outbox marks item `FAILED_PERMANENT`. | Original order remains ₹500; audit ledger logs `IDEMPOTENCY_PAYLOAD_MISMATCH`. | **PLANNED** (Phase Auth-3 / Auth-8) |
| **TEST-09** | Tenant switch during in-flight network response | User initiates sync for Tenant Alpha (`gen=1`). | User taps "Switch to Tenant Beta" (`gen=2`) while HTTP request is in-flight. | Alpha response arrives; generation check fails (`1 != 2`); response discarded; Beta DB clean. | Tenant Alpha committed in D1; Tenant Beta D1 untouched. Zero cross-contamination. | **PLANNED** (Phase Auth-7 / Auth-8) |
| **TEST-10** | Server revocation while client operates offline | User authenticated. Network disconnected. User creates offline sales orders. | Admin marks `is_active = 0` in `organization_memberships` on D1 via Wrangler. | Network restored; sync transmits; server returns HTTP 403; app enters `MEMBERSHIP_DEACT`. | Outbox mutations locked; no unauthorized writes committed to server. | **PLANNED** (Phase Auth-4 / Auth-8) |

---

## 7. Security Assumptions & Residual Risks

### 7.1 Security Assumptions
1. **Qualcomm Keymaster 4.0 Integrity:** The hardware TEE on the Vivo 1935 correctly isolates ECDSA private keys and MasterKeys from user-space kernel exploits.
2. **Android OS Sandbox Enforceability:** The Android kernel correctly enforces Linux UID file boundary permissions between third-party applications.
3. **Cloudflare D1 Transactional Atomicity:** Miniflare and Cloudflare D1 adhere to SQLite batch transaction semantics, rolling back all statements if any constraint fails.
4. **Argon2id KDF Strength:** Argon2id parameters ($\text{mem}=64\text{MB}, \text{iter}=3$) provide sufficient computational work to resist offline dictionary attacks on user PINs if encrypted shared preferences are extracted from NAND storage.

### 7.2 Residual Risks & Compensating Controls
- **Residual Risk 1: Physical Device Data Wiping:** If an Android device is factory reset or RouteFlow app data is cleared, unsynchronized local outbox records are permanently destroyed.
  - *Compensating Control:* High-frequency sync scheduling whenever connectivity is available; UI notification warning of pending unsynchronized items before device maintenance.
- **Residual Risk 2: Weak User PINs on Shared Devices:** If a user selects a trivial PIN (e.g. `123456`), another user sharing the device could guess the PIN and derive the local KEK.
  - *Compensating Control:* Strict PIN entropy validation rules (rejecting sequential or repeating digits) and maximum failed attempt lockouts (5 attempts before Keystore wipe).
- **Residual Risk 3: Clock Manipulation during Offline Grace:** A user setting the clock backward can artificially extend client-side offline grace periods.
  - *Compensating Control:* The client combines wall-clock time with monotonic uptime counter and network time timestamps stored in Drift metadata; server immediately revokes expired tokens upon reconnection.

---

## 8. Compatibility & Migration Implications

1. **Drift Database Schema Upgrade:**
   - Increments Drift schema from version 2 to version 3.
   - Migration requires adding the additive `outbox_mutations` table.
   - Zero modifications to existing tables (`products`, `retailers`, `inventory_snapshots`, `inventory_movements`, `database_metadata`).
2. **Backward-Compatible Backend Idempotency Schema:**
   - Existing table `idempotency_records` in migration `0004` uses `company_id`.
   - Migration `0025` will create `d1_idempotency_ledger` with composite primary key `(organization_id, actor_id, idempotency_key)`.
   - Legacy endpoints reading from `idempotency_records` continue operating without disruption during the migration window.
3. **Flutter App Dependencies:**
   - Requires adding `cryptography: ^2.7.0` or utilizing `pointycastle` for client-side Argon2id key derivation and AES-GCM envelope sealing in Dart.
   - Existing `flutter_secure_storage: ^11.2.0` remains the root trust store for Android Keystore wrapping.

---

## 9. Remaining Implementation Blockers

The following items are explicit governance gates that must be completed before code modifications commence:

1. **Gate 1: Remote Staging Backup Script Verification (Auth-2 Prerequisite):**
   - Author and verify `backend/tools/backup_remote_d1.mjs` using `npx wrangler d1 export routeflow-db-staging --remote`.
   - Execute test restoration into a local SQLite scratch database and verify integrity (`PRAGMA integrity_check`).
2. **Gate 2: User Sign-Off on Staging Migration 0024:**
   - Present backup verification results and obtain explicit authorization before applying `0024_auth_memberships_canonical_roles.sql` to `routeflow-db-staging`.
3. **Gate 3: Physical Android Keystore Interop Certification on Vivo 1935:**
   - Execute scratch verification APK on the connected Vivo 1935 (`4bc99b28`) to capture actual Android ASN.1 DER ECDSA signatures and certify WebCrypto IEEE P1363 conversion.

---

## 10. Exact Files Inspected & Final Audit

### 10.1 Inspected Files:
- `docs/routeflow_persistent_session_and_offline_first_spec_1_1.md`
- `docs/routeflow_persistent_session_and_offline_first_spec_1_2.md`
- `flutter_distributor/lib/data/auth/secure_token_storage.dart`
- `flutter_distributor/lib/domain/auth/tenant_boundary_gate.dart`
- `flutter_distributor/lib/data/local/app_database.dart`
- `flutter_distributor/lib/services/api_service.dart`
- `backend/src/security.ts`
- `backend/migrations/0001_initial.sql`
- `backend/migrations/0004_security_ledger_and_sessions.sql`
- `backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`

### 10.2 Git Status Audit (Before and After):
```
Changes not staged for commit (Preserved untouched):
  flutter_distributor/android/app/build.gradle.kts
  flutter_distributor/lib/data/local/app_database.dart
  flutter_distributor/lib/screens/logistics_view.dart
  flutter_distributor/lib/screens/role_shell.dart
  flutter_distributor/lib/screens/sales_view.dart
  flutter_distributor/lib/services/api_service.dart
  flutter_distributor/test/order_preview_safety_test.dart

Untracked files (Preserved documentation & harnesses):
  docs/routeflow_auth_0_read_only_audit.md
  docs/routeflow_auth_1_1_security_correction.md
  docs/routeflow_auth_1_2_final_security_proof.md
  docs/routeflow_auth_1_3_gap_closure.md
  docs/routeflow_auth_1_4_protocol_review.md
  docs/routeflow_auth_1_5_android_crypto_review.md
  docs/routeflow_auth_1_6_1_staging_preflight.md
  docs/routeflow_auth_1_6_final_security_closure.md
  docs/routeflow_auth_1_migration_proposal.md
  docs/routeflow_auth_v1_1_final_security_spec.md
  docs/routeflow_auth_v1_2_final_security_spec.md
  docs/routeflow_b2_2_implementation_readiness_review.md
  docs/routeflow_four_role_client_readiness_report.md
  docs/routeflow_persistent_session_and_offline_first_spec.md
  docs/routeflow_persistent_session_and_offline_first_spec_1_1.md
  docs/routeflow_persistent_session_and_offline_first_spec_1_2.md
  docs/routeflow_persistent_session_and_offline_first_spec_1_3.md
  [...]
```
*Zero Git commits, zero pushes, zero remote D1 operations, zero modifications to existing source files.*
