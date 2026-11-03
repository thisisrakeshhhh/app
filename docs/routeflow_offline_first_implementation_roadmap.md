# RouteFlow — Offline-First Implementation Roadmap & Phase O1 Preparation

**Document Version:** 1.0.0  
**Status:** Architectural Implementation Roadmap (Planning Only — Zero Implementation)  
**Execution Boundary:** Zero code modifications, zero schema changes, zero database operations, zero Git commits or pushes.  
**Target Hardware:** Vivo 1935 (`4bc99b28`, Qualcomm Snapdragon 665, Android 10 / API 29, Keymaster 4.0 TEE)  
**Target Platform:** Flutter Pilot (`flutter_distributor`), Android Keystore, Drift/SQLite  
**Target Backend:** Cloudflare Workers API Gateway (`routeflow-api`) + Cloudflare D1 Database (`routeflow-db`)  

---

## 1. Executive Summary & Phasing Strategy

This roadmap operationalizes the architectural guarantees established in Spec 1.3 and verified in the Final Readiness Audit into eight discrete, decoupled implementation phases.

### Core Governance Principles
1. **Decoupled Client & Server Tracks:** Local client-side outbox persistence, tenant database routing, and fenced lease services (Phases O1, O2, O3, O4) do not touch remote Cloudflare D1 or require remote migration approval. They can be implemented and certified locally using automated Flutter/Drift test suites.
2. **Strict Gate Isolation for Remote D1:** Any phase touching remote Cloudflare D1 (Phases O5, O6, O8) remains strictly blocked until the prerequisite **Auth-1.6.1 Remote Staging Backup Preflight** is authorized and Migration 0024 is successfully applied.
3. **Smallest Safe First Step:** **Phase O1 (Durable Local Outbox in Drift)** is recommended as the immediate first implementation phase. It is entirely local, requires zero remote operations, and establishes the persistent foundation upon which all subsequent offline capabilities rely.

---

## 2. High-Level Dependency Graph & Phasing Matrix

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              OFFLINE-FIRST IMPLEMENTATION PHASING                      │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  LOCAL CLIENT TRACK (NO STAGING APPROVAL NEEDED)                                       │
│  ┌──────────────────────┐      ┌──────────────────────┐      ┌──────────────────────┐  │
│  │ Phase O1: Durable    │ ───> │ Phase O2: Crash-Safe │ ───> │ Phase O3: Tenant DB   │  │
│  │ Local Outbox (Drift) │      │ Sync Lease Engine    │      │ Isolation Router     │  │
│  └──────────────────────┘      └──────────────────────┘      └──────────────────────┘  │
│                                                                          │             │
│                                                                          ▼             │
│                                                              ┌──────────────────────┐  │
│                                                              │ Phase O4: User DEK   │  │
│                                                              │ & DDB Protection     │  │
│                                                              └──────────────────────┘  │
│                                                                          │             │
├──────────────────────────────────────────────────────────────────────────┼─────────────┤
│  REMOTE CLOUDFLARE D1 TRACK (REQUIRES AUTH-1.6.1 STAGING APPROVAL GATE)   │             │
│  ┌──────────────────────┐      ┌──────────────────────┐                  │             │
│  │ Gate 1: Staging D1   │ ───> │ Phase O5: Unified D1 │ <────────────────┘             │
│  │ Backup & Preflight   │      │ Idempotency Ledger   │                                │
│  └──────────────────────┘      └──────────────────────┘                                │
│                                           │                                            │
│                                           ▼                                            │
│                                ┌──────────────────────┐                                │
│                                │ Phase O6: CCCR &     │                                │
│                                │ Identity Transitions │                                │
│                                └──────────────────────┘                                │
│                                           │                                            │
│                                           ▼                                            │
│                                ┌──────────────────────┐                                │
│                                │ Phase O7: Financial  │                                │
│                                │ Ledger Reconciliation│                                │
│                                └──────────────────────┘                                │
│                                           │                                            │
│                                           ▼                                            │
│                                ┌──────────────────────┐                                │
│                                │ Phase O8: Device E2E │                                │
│                                │ Validation (Vivo)    │                                │
│                                └──────────────────────┘                                │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Phase Specifications (Phases O1 to O8)

---

### Phase O1 — Durable Local Outbox (Drift Schema v3)

#### 1. Exact Source Files to Create or Modify
- **Modify:** `flutter_distributor/lib/data/local/app_database.dart` (Add `OutboxMutations` table; increment `schemaVersion` to 3; update `MigrationStrategy`).
- **Create:** `flutter_distributor/lib/data/local/daos/outbox_dao.dart` (Atomic CRUD operations, transactional insertion with business mutations).
- **Create:** `flutter_distributor/lib/domain/outbox/outbox_models.dart` (Enums: `MutationType`, `SyncStatus`, domain entities).
- **Generate:** `flutter_distributor/lib/data/local/app_database.g.dart` (Drift build runner output).

#### 2. Dependencies on Earlier Phases
- None. This is the foundational client-side data layer.

#### 3. Existing Code That Must Be Preserved
- `Products`, `Retailers`, `InventorySnapshots`, `InventoryMovements`, and `DatabaseMetadata` tables in `app_database.dart`.
- The F-05 quarantine marker mechanism in `tenant_boundary_gate.dart`.
- All uncommitted changes in `flutter_distributor/` (Role routing, order preview safety, sales/logistics views).

#### 4. Database Changes (Drift Schema Upgrade: v2 -> v3)
- Additive table creation:
```sql
CREATE TABLE IF NOT EXISTS outbox_mutations (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    idempotency_key TEXT NOT NULL UNIQUE,
    mutation_type TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    sequence_order INTEGER NOT NULL,
    sync_status TEXT NOT NULL CHECK(sync_status IN ('PENDING', 'SYNCING', 'SYNCED', 'RETRYABLE_FAILURE', 'FAILED_PERMANENT')),
    provisional_business_id TEXT,
    lease_token TEXT,
    lease_generation INTEGER NOT NULL DEFAULT 0,
    lease_expires_at_ms INTEGER,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error_code TEXT,
    next_retry_at_ms INTEGER,
    created_at_epoch_ms INTEGER NOT NULL,
    synced_at_epoch_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_outbox_queue 
ON outbox_mutations(organization_id, user_id, sync_status, next_retry_at_ms, sequence_order);
CREATE INDEX IF NOT EXISTS idx_outbox_idempotency 
ON outbox_mutations(idempotency_key);
```

#### 5. Security Invariants
- Every outbox record must strictly contain non-null `organization_id` and `user_id` bound to the authenticated creator.
- `idempotency_key` must be a cryptographically random UUIDv4 generated locally upon user action and never modified upon retry.
- Inserting business mutations (e.g. updating local inventory or creating an order draft) and queueing the outbox record must occur inside a single SQLite transaction (`db.transaction(...)`).

#### 6. Automated Tests
- `test/outbox_schema_migration_test.dart`:
  - Verify migration from Schema v2 to Schema v3 preserves all existing product/retailer data.
  - Assert unique constraint failure on duplicate `idempotency_key`.
  - Assert atomic rollback: if outbox insertion fails, business table updates roll back.

#### 7. Physical-Device Tests
- Verify successful Drift migration execution on physical Vivo 1935 test app without SQLite open errors.

#### 8. Entry and Exit Criteria
- **Entry:** Main branch working tree clean; B1/B2.1 code preserved.
- **Exit:** Schema v3 compiled; `outbox_dao.dart` fully unit tested with 100% passing tests.

#### 9. Rollback & Recovery Strategy
- Revert `schemaVersion` to 2; drop table `outbox_mutations`. Because the migration is strictly additive, reverting causes zero data loss to B1 master data.

#### 10. Authorization & Staging Prerequisite
- **Staging Approval Required:** **NO.**
- **Authorization Required:** User authorization to edit `app_database.dart` and generate code.

---

### Phase O2 — Crash-Safe Synchronization & Lease Engine

#### 1. Exact Source Files to Create or Modify
- **Create:** `flutter_distributor/lib/services/sync/outbox_sync_worker.dart` (Lease lifecycle, sync scheduler, network transport).
- **Create:** `flutter_distributor/lib/services/sync/lease_manager.dart` (Monotonic generation fencing, clock sanitization).
- **Modify:** `flutter_distributor/lib/services/api_service.dart` (Hook cold boot recovery and outbox status listeners).

#### 2. Dependencies on Earlier Phases
- Requires Phase O1 (`OutboxMutations` table and DAO).

#### 3. Existing Code That Must Be Preserved
- `api_service.dart:clearTransientState()` and `_transientGeneration`.

#### 4. Database Changes
- None (Uses Schema v3 established in Phase O1).

#### 5. Security Invariants
- Every lease mutation query must check both `lease_token = :token` AND `lease_generation = :gen`.
- Stale workers whose generation has been superseded must receive 0 updated rows and immediately abort their network completion.
- Device wall-clock adjustments must not influence lease expiry; elapsed time must use `Stopwatch.elapsedMilliseconds`.
- On cold boot, any row with `sync_status = 'SYNCING'` must be reset to `RETRYABLE_FAILURE` (`lease_generation + 1`).

#### 6. Automated Tests
- `test/outbox_lease_concurrency_test.dart`:
  - Simulate two workers attempting to claim the same outbox item; verify exactly one succeeds.
  - Simulate worker sleeping past lease window; second worker reclaims; first worker wakes up and attempts completion; assert first worker write is rejected (`changes() == 0`).
  - Cold boot recovery test: Inject row in `SYNCING` state, trigger boot recovery, assert state is `RETRYABLE_FAILURE` with incremented generation.

#### 7. Physical-Device Tests
- Execute process kill via ADB (`adb shell am kill com.routidrow.distributor.debug`) while sync is in-flight; relaunch app; verify pending item is cleanly recovered and resynchronized.

#### 8. Entry and Exit Criteria
- **Entry:** Phase O1 complete and tested.
- **Exit:** Concurrency and cold boot tests passing; zero orphaned `SYNCING` records.

#### 9. Rollback & Recovery Strategy
- Disable background sync worker service in `ApiService`; all outbox records remain safely parked in SQLite.

#### 10. Authorization & Staging Prerequisite
- **Staging Approval Required:** **NO.** Can be tested against mocked HTTP client.
- **Authorization Required:** User authorization to implement sync worker service.

---

### Phase O3 — Tenant Database Isolation Router

#### 1. Exact Source Files to Create or Modify
- **Create:** `flutter_distributor/lib/data/local/tenant_database_router.dart` (Dynamic file router, connection lifecycle manager).
- **Modify:** `flutter_distributor/lib/data/local/app_database.dart` (Parameterize database file path).
- **Modify:** `flutter_distributor/lib/services/api_service.dart` (Integrate tenant switching with database connection unmount/remount).

#### 2. Dependencies on Earlier Phases
- Requires Phase O1 and O2.

#### 3. Existing Code That Must Be Preserved
- `routidrow_clean.sqlite` must remain quarantined and untouched (preserving historical B1 data).
- `TenantBoundaryGate` quarantine checks must remain intact.

#### 4. Database Changes
- Multiple physical SQLite files created on filesystem:
  - Legacy: `routidrow_clean.sqlite` (Quarantined B1)
  - Tenants: `routeflow_tenant_${orgId}.sqlite` (Multi-tenant modern schema)

#### 5. Security Invariants
- Data from Organization Alpha must never exist in the same SQLite file as Organization Beta.
- On organization switch, the active database connection must drain in-flight transactions and close before the destination database file is opened.
- In-flight network responses bearing a stale `tenantGeneration` or mismatched `organizationId` must be discarded immediately.

#### 6. Automated Tests
- `test/tenant_database_router_test.dart`:
  - Create records in Tenant A database; switch to Tenant B; assert Tenant A records are invisible.
  - Simulate slow network response for Tenant A arriving after switch to Tenant B; assert response is discarded and Tenant B database is unmodified.

#### 7. Physical-Device Tests
- Switch organizations on physical Vivo 1935; verify separate SQLite database files exist in `/data/user/0/com.routidrow.distributor.debug/databases/`.

#### 8. Entry and Exit Criteria
- **Entry:** Phase O2 complete.
- **Exit:** Multi-tenant file switching passes all automated tests; zero cross-tenant data leakage.

#### 9. Rollback & Recovery Strategy
- Fall back to single database mode pointing to `routeflow_tenant_default.sqlite`.

#### 10. Authorization & Staging Prerequisite
- **Staging Approval Required:** **NO.**
- **Authorization Required:** User authorization to refactor database connection opening.

---

### Phase O4 — User-Specific Data Encryption & DDB Protection

#### 1. Exact Source Files to Create or Modify
- **Create:** `flutter_distributor/lib/data/crypto/dek_vault.dart` (Dual-layer Argon2id + Keystore DEK management).
- **Create:** `flutter_distributor/lib/screens/auth/offline_pin_dialog.dart` (Local 6-digit PIN entry dialog).
- **Modify:** `flutter_distributor/lib/data/local/daos/outbox_dao.dart` (Encrypt `payload_json` into `payload_encrypted` BLOB).
- **Modify:** `flutter_distributor/lib/services/api_service.dart` (Enforce Dedicated Device Binding logout quarantine).

#### 2. Dependencies on Earlier Phases
- Requires Phase O1, O2, and O3.

#### 3. Existing Code That Must Be Preserved
- `EncryptedSecureTokenStorage` in `secure_token_storage.dart`.

#### 4. Database Changes
- `outbox_mutations` payload columns populated: `payload_encrypted`, `payload_iv`, `payload_tag`.

#### 5. Security Invariants
- Plaintext transaction payloads must never be written to SQLite disk without AES-256-GCM encryption.
- User B on a shared phone must be mathematically incapable of unsealing User A's DEK without User A's offline PIN/password.
- If Dedicated Device Binding (DDB) is active, logging out a user with pending unsynced outbox records is blocked until records are synchronized.

#### 6. Automated Tests
- `test/dek_vault_crypto_test.dart`:
  - Seal payload under Alice's PIN; attempt unsealing with Bob's PIN; assert AES-GCM tag mismatch failure.
  - Test DDB logout block: attempt logout with 1 pending item; assert `QuarantineException` is raised.

#### 7. Physical-Device Tests
- Verify Argon2id execution time on Qualcomm Snapdragon 665 (Vivo 1935) is bounded (< 800ms for $\text{mem}=64\text{MB}, \text{iter}=3$).

#### 8. Entry and Exit Criteria
- **Entry:** Phase O3 complete.
- **Exit:** Crypto tests pass on Vivo 1935; zero plaintext payloads written to SQLite.

#### 9. Rollback & Recovery Strategy
- Disable payload encryption flag; fall back to plaintext SQLite storage inside app sandbox.

#### 10. Authorization & Staging Prerequisite
- **Staging Approval Required:** **NO.**
- **Authorization Required:** User authorization to integrate cryptographic libraries (`cryptography: ^2.7.0`).

---

### Phase O5 — Unified Backend D1 Idempotency Ledger (Migration 0025)

#### 1. Exact Source Files to Create or Modify
- **Create:** `backend/migrations/0025_unified_d1_idempotency_ledger.sql` (Creates `d1_idempotency_ledger`).
- **Create:** `backend/src/middleware/idempotency.ts` (Unified Hono middleware for idempotency pre-check and replay).
- **Modify:** `backend/src/index.ts` (Refactor `/orders` to use unified ledger).
- **Modify:** `backend/src/daily-cycle.ts` (Refactor `/collections` and `/handovers` to use unified ledger).

#### 2. Dependencies on Earlier Phases
- Requires Gate 1 (Staging D1 Backup Preflight & Migration 0024 completion).

#### 3. Existing Code That Must Be Preserved
- Historical rows in `idempotency_records` (0004) and `operation_receipts` (0009).
- Credit reservation triggers in `0009_daily_cycle_integrity.sql`.

#### 4. Database Changes (Cloudflare D1 Migration 0025)
```sql
CREATE TABLE IF NOT EXISTS d1_idempotency_ledger (
    organization_id TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    operation TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    response_status INTEGER NOT NULL,
    response_body TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('PROCESSING', 'COMMITTED')),
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    PRIMARY KEY (organization_id, actor_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_retention 
ON d1_idempotency_ledger(expires_at);
```

#### 5. Security Invariants
- Composite primary key `(organization_id, actor_id, idempotency_key)` guarantees zero cross-tenant key collisions.
- Submitting an identical key with an altered payload must return `HTTP 409 Conflict`.
- Business mutations and idempotency receipts must commit in the same atomic `env.DB.batch([...])`.

#### 6. Automated Tests
- `backend/test/unified_idempotency.test.mjs` (Miniflare test):
  - Parallel submission of identical order payload: assert single order created, second returns replayed response.
  - Submission of identical key with different line item: assert HTTP 409 Conflict.

#### 7. Physical-Device Tests
- N/A (Server-side D1 test).

#### 8. Entry and Exit Criteria
- **Entry:** Auth-1.6.1 Staging Backup certified; Migration 0024 applied.
- **Exit:** Migration 0025 applied to staging; all idempotency tests 100% passing.

#### 9. Rollback & Recovery Strategy
- Rollback statements in migration script; endpoints fall back to reading legacy `idempotency_records`.

#### 10. Authorization & Staging Prerequisite
- **Staging Approval Required:** **YES.** Strict user authorization required before running Wrangler migration on staging.

---

### Phase O6 — Persistent Identity & CCCR Session Lifecycle (Migration 0026)

#### 1. Exact Source Files to Create or Modify
- **Create:** `backend/migrations/0026_auth_sessions_cccr.sql` (Creates `sessions` table).
- **Create:** `backend/src/auth-cccr.ts` (Endpoints: `/auth/refresh/challenge`, `/auth/refresh`, `/auth/refresh/retry`).
- **Modify:** `flutter_distributor/lib/data/auth/auth_repository.dart` (Integrate CCCR client candidate generation and Android Keystore signing).
- **Modify:** `flutter_distributor/lib/services/api_service.dart` (Implement 7-state offline identity machine).

#### 2. Dependencies on Earlier Phases
- Requires Phase O5 and Gate 1.

#### 3. Existing Code That Must Be Preserved
- `security.ts:verifyTenantMembership()`.
- Flutter `RoleRouting` and role shell screens.

#### 4. Database Changes (Cloudflare D1 Migration 0026)
```sql
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    organization_id TEXT NOT NULL,
    device_key_spki TEXT NOT NULL,
    refresh_token_hash TEXT NOT NULL,
    candidate_token_hash TEXT,
    challenge TEXT,
    challenge_expires_at INTEGER,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

#### 5. Security Invariants
- Access tokens must live strictly in RAM with a 15-minute maximum TTL.
- Server must never receive or store plaintext refresh tokens (only SHA-256 hashes).
- Network disconnects must never revoke sessions (transition exclusively to `AUTHENTICATED_OFFLINE`).
- Server revocation on reconnect must immediately override client offline grace.

#### 6. Automated Tests
- `backend/test/cccr_token_rotation.test.mjs`:
  - Complete candidate commitment, challenge generation, signature verification, and hash rotation.
  - Lost response simulation: retry with candidate token; assert recovery succeeds without re-login.

#### 7. Physical-Device Tests
- Vivo 1935 captures hardware Keystore ECDSA P-256 signature; verify WebCrypto IEEE P1363 verification in Cloudflare Worker.

#### 8. Entry and Exit Criteria
- **Entry:** Phase O5 complete; staging backup valid.
- **Exit:** CCCR rotation verified on physical Vivo device.

#### 9. Rollback & Recovery Strategy
- Fall back to standard session token validation in `security.ts`.

#### 10. Authorization & Staging Prerequisite
- **Staging Approval Required:** **YES.**

---

### Phase O7 — Financial Reconciliation & Invariant Sync

#### 1. Exact Source Files to Create or Modify
- **Modify:** `backend/src/daily-cycle.ts` (Strict server-side validation of offline collection/handover submissions).
- **Modify:** `flutter_distributor/lib/screens/dashboards/sales_dashboard.dart` (Display provisional vs confirmed collection totals).
- **Modify:** `flutter_distributor/lib/screens/dashboards/logistics_dashboard.dart` (Display provisional vs confirmed delivery handovers).

#### 2. Dependencies on Earlier Phases
- Requires Phase O1, O2, O5, and O6.

#### 3. Existing Code That Must Be Preserved
- `credit_reservations` and `reserve_order_credit` trigger in `0009_daily_cycle_integrity.sql`.
- Cash handover verification state machine in `daily-cycle.ts`.

#### 4. Database Changes
- None (Uses established financial ledger tables).

#### 5. Security Invariants
- Client must display provisional status until server acknowledgment is received.
- Collections in cash must increment salesperson custody only upon server confirmation.
- Stock movements must follow append-only ledger entries; negative inventory overrides must require managerial authorization.

#### 6. Automated Tests
- `backend/test/financial_reconciliation.test.mjs`:
  - Submit offline collection created while retailer credit was valid; credit exhausted online before sync; assert graceful rejection or credit override queueing.

#### 7. Physical-Device Tests
- Execute offline order creation, offline cash collection, and subsequent online sync on Vivo 1935; verify khata ledger balance matches.

#### 8. Entry and Exit Criteria
- **Entry:** Phase O6 complete.
- **Exit:** Khata and cash reconciliation tests 100% passing.

#### 9. Rollback & Recovery Strategy
- Disable offline collection feature flag; restrict collections to online-only mode.

#### 10. Authorization & Staging Prerequisite
- **Staging Approval Required:** **YES.**

---

### Phase O8 — Device & Integration Validation (Ten Failure Scenarios)

#### 1. Exact Source Files to Create or Modify
- **Create:** `test/integration/ten_failure_scenarios_test.dart` (Automated integration runner).
- **Create:** `docs/routeflow_phase_o8_final_certification_report.md` (Certification deliverable).

#### 2. Dependencies on Earlier Phases
- Requires all earlier phases (O1 through O7).

#### 3. Existing Code That Must Be Preserved
- Entire Flutter, backend, and documentation suite.

#### 4. Database Changes
- None.

#### 5. Security Invariants
- Every test in the 10-scenario matrix must execute on physical Vivo 1935 (`4bc99b28`) with observable database assertions.

#### 6. Automated & Physical-Device Test Execution Matrix
1. **TEST-01 (Shared Phone DEK Barrier):** Attempt to read Alice's outbox from Bob's session -> Verified Tag mismatch.
2. **TEST-02 (Lockscreen Invalidation):** `adb shell locksettings clear` -> Verified `KeystoreInaccessibleException`.
3. **TEST-03 (Concurrent Worker Race):** Two isolates claiming same item -> Verified single lease winner.
4. **TEST-04 (Stale Worker Completion):** Worker sleeps 70s -> Reclamation -> Stale write matches 0 rows.
5. **TEST-05 (Device Clock Leaps):** `adb shell date` altered +/- 4 hours -> Monotonic order preserved.
6. **TEST-06 (Concurrent D1 Idempotency):** Parallel identical requests -> Exactly 1 order in D1; identical 201 replay.
7. **TEST-07 (Lost Response Network Cut):** Cut Wi-Fi mid-response -> Resend key -> Verified cached replay.
8. **TEST-08 (Payload Tampering):** Modified total with reused key -> HTTP 409 Conflict.
9. **TEST-09 (Tenant Switch In-Flight):** Switch tenant while HTTP pending -> Response discarded; clean DB.
10. **TEST-10 (Server Revocation While Offline):** Revoke user in D1 -> Online sync -> Immediate 403 & lockdown.

#### 7. Physical-Device Evidence
- Capture ADB logcat, SQLite DB dumps before/after, and Cloudflare D1 query results.

#### 8. Entry and Exit Criteria
- **Entry:** Phases O1 to O7 deployed to staging and physical testbed.
- **Exit:** All 10 tests classified as `PASSED`; zero failures.

#### 9. Rollback & Recovery Strategy
- If critical invariant fails, revert affected phase and quarantine release.

#### 10. Authorization & Staging Prerequisite
- **Staging Approval Required:** **YES.**
- **Authorization Required:** User sign-off on final certification report.

---

## 4. Phase Independence & Staging Gate Isolation

| Implementation Phase | Client Only or Backend? | Touches Remote Staging D1? | Can Proceed Without Auth-1.6.1 Staging Approval? |
| :--- | :--- | :--- | :--- |
| **Phase O1: Durable Local Outbox (Drift v3)** | Client Only | **NO** | **YES** |
| **Phase O2: Crash-Safe Sync & Lease Engine** | Client Only | **NO** | **YES** |
| **Phase O3: Tenant Database Isolation Router** | Client Only | **NO** | **YES** |
| **Phase O4: User DEK & DDB Protection** | Client Only | **NO** | **YES** |
| **Phase O5: Unified D1 Idempotency Ledger** | Backend & D1 | **YES** (Migration 0025) | **NO (Blocked on Gate 1)** |
| **Phase O6: CCCR Sessions & Identity States** | Full Stack | **YES** (Migration 0026) | **NO (Blocked on Gate 1)** |
| **Phase O7: Financial Reconciliation** | Full Stack | **YES** | **NO (Blocked on Gate 1)** |
| **Phase O8: Device & Integration Validation** | Physical Device | **YES** | **NO (Blocked on Gate 1)** |

---

## 5. Recommendation for Smallest Safe First Phase

### Recommendation: **Execute Phase O1 (Durable Local Outbox in Drift)**

#### Why Phase O1 is the Safest and Best First Step:
1. **Zero Remote Risk:** It operates 100% inside `flutter_distributor/`. It does not make network calls, touch Cloudflare Workers, or modify remote D1 databases.
2. **Strictly Additive:** Drift Schema version increments from 2 to 3 by adding the new `outbox_mutations` table. All existing tables (`Products`, `Retailers`, `InventorySnapshots`, `InventoryMovements`) and pre-existing B1 data in `routidrow_clean.sqlite` remain untouched.
3. **Comprehensive Automated Verification:** The entire migration and transactional DAO can be unit tested locally with in-memory SQLite and file-based test databases.
4. **Unlocks All Subsequent Phases:** Neither the sync engine (Phase O2), tenant router (Phase O3), nor encrypted storage (Phase O4) can function without the underlying outbox schema.

---

## 6. Git Working Tree Status Verification

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
  docs/routeflow_offline_first_final_readiness_audit.md
  docs/routeflow_offline_first_implementation_roadmap.md
  docs/routeflow_persistent_session_and_offline_first_spec.md
  docs/routeflow_persistent_session_and_offline_first_spec_1_1.md
  docs/routeflow_persistent_session_and_offline_first_spec_1_2.md
  docs/routeflow_persistent_session_and_offline_first_spec_1_3.md
  [...]
```

*Planning Complete. Zero code modifications executed. Zero Git commits or pushes made.*
