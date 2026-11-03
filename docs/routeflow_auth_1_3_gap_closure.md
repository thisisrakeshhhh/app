# RouteFlow Auth-1.3 — Final Protocol and Migration Gap Closure

**Document Version:** 1.3.0  
**Phase:** Auth-1.3 Protocol & Migration Gap Closure  
**Execution Mode:** STRICT DOCUMENT-ONLY SECURITY REVIEW & DISPOSABLE MINIFLARE AUDIT  
**Scope Boundary:** Zero application code changes, zero migration execution on real databases, zero database writes to live/staging environments, zero git commits or pushes.  
**Timestamp:** 2026-11-02  
**Target Migration:** Proposed `0024_auth_memberships_canonical_roles.sql`  
**Target Systems:** Cloudflare Workers API, Cloudflare D1 (SQLite Edge Database), Flutter Pilot  

---

## E. Git and Scope Audit (Baseline & Status Transparency)

### E.1 Working Tree Baseline
```
On branch main
Your branch is ahead of 'origin/main' by 2 commits.

Changes not staged for commit:
	modified:   flutter_distributor/android/app/build.gradle.kts
	modified:   flutter_distributor/lib/data/local/app_database.dart
	modified:   flutter_distributor/lib/screens/logistics_view.dart
	modified:   flutter_distributor/lib/screens/role_shell.dart
	modified:   flutter_distributor/lib/screens/sales_view.dart
	modified:   flutter_distributor/lib/services/api_service.dart
	modified:   flutter_distributor/test/order_preview_safety_test.dart

Untracked files:
	docs/routeflow_auth_0_read_only_audit.md
	docs/routeflow_auth_1_1_security_correction.md
	docs/routeflow_auth_1_2_final_security_proof.md
	docs/routeflow_auth_1_3_gap_closure.md
	docs/routeflow_auth_1_migration_proposal.md
	docs/routeflow_auth_v1_1_final_security_spec.md
	docs/routeflow_auth_v1_2_final_security_spec.md
	docs/routeflow_b2_2_implementation_readiness_review.md
	docs/routeflow_four_role_client_readiness_report.md
	flutter_distributor/lib/domain/auth/role_routing.dart
	flutter_distributor/lib/screens/dashboards/
	flutter_distributor/lib/screens/views/
	flutter_distributor/test/delivery_safety_test.dart
	flutter_distributor/test/hardcore_four_role_crud_test.dart
	flutter_distributor/test/role_routing_test.dart
	flutter_distributor/test/ruthless_hardcore_invariant_test.dart
```

### E.2 Explanation of Markdown Status Appearance
The Markdown documentation files in `docs/` (`routeflow_auth_1_1_security_correction.md`, `routeflow_auth_1_migration_proposal.md`, `routeflow_auth_v1_2_final_security_spec.md`, `routeflow_auth_1_2_final_security_proof.md`) were created during review sessions and have **never been staged (`git add`) or committed to the Git index**. 
- In Git, any file that has never been tracked by the repository index remains in the `Untracked files:` section, even after edits.
- Files only appear under `Changes not staged for commit:` if they were already tracked in a prior commit.
- All pre-existing modified files in `flutter_distributor/` and all untracked test/dashboard files remain completely intact and preserved.

---

## A. Refresh Protocol: Complete Cryptographic Specification & Gap Closure

### A.1 Client Key Storage & Android Keystore Persistence
To survive Android process death, task swiping, and device reboots, client proof keys **must never be kept solely in volatile RAM**.

1. **Hardware-Backed Persistence:**
   - On Android, keys are persisted using `flutter_secure_storage` backed by the **Android Keystore System** (`KeyStoreProvider`).
   - Private key material is encrypted using an AES-256-GCM master key generated in hardware (`MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)`), stored within `EncryptedSharedPreferences`.
   - On iOS, keys are stored in the iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`.
2. **Key Lifecycle (Creation, Storage, Retrieval, Rotation, Deletion):**
   - **Creation ($t=0$):** At login, the client generates $K_0 \leftarrow \text{CSPRNG}(256\text{ bits})$ using platform secure random. It computes $H(K_0) = \text{SHA-256}(K_0)$.
   - **Storage:** Persisted under alias `rf_proof_key_${sessionId}` in secure storage before the network call completes.
   - **Retrieval:** Loaded by `TokenRefreshCoordinator` during 401 handling.
   - **Rotation ($t=i \to t=i+1$):** Client generates $K_{i+1}$, computes $H(K_{i+1})$, and submits $(R_i, K_i, H(K_{i+1}))$. Upon receiving HTTP 200 with replacement $(A_{i+1}, R_{i+1})$, client atomically writes $K_{i+1}$ and $R_{i+1}$ to secure storage and deletes $K_i$ and $R_i$.
   - **Deletion:** Explicit logout, tenant unlinking, or account deactivation invokes `secureStorage.delete(key)` to purge keys.
3. **Failure Handling (Key Loss or Keystore Invalidation):**
   - If the device is wiped, user clears app storage, or biometric key invalidation triggers Keystore erasure, $K_i$ is permanently unrecoverable.
   - The client cannot supply $K_i$ on the next refresh call.
   - The server fails closed with `HTTP 401 Unauthorized (Proof Required)`.
   - The mobile application redirects to the login screen. The user must re-authenticate with Google OAuth or Email/Password, issuing a brand-new session family with fresh $(R_0, K_0)$.

### A.2 AES-256-GCM Recovery Envelope Details
The recovery envelope allows legitimate retry recovery without storing plaintext refresh tokens in D1:

- **Key Derivation (HKDF-SHA256):**
  $$\text{PRK} = \text{HMAC-SHA256}(\text{salt}=\text{UTF8}(\text{session\_id}), \text{IKM}=K_i)$$
  $$K_{\text{enc}} = \text{HMAC-SHA256}(\text{PRK}, \text{info}=\text{UTF8}(\text{"RouteFlow-Refresh-Envelope-v1"}) \parallel \text{0x01})$$
  - Output key length: 256 bits (32 bytes).
- **Nonce Generation:**
  - 12-byte cryptographically random IV generated via WebCrypto: `crypto.getRandomValues(new Uint8Array(12))`.
  - Never reused for the same session key.
- **Associated Authenticated Data (AAD):**
  - Cryptographically binds ciphertext to session and token family:
    $$\text{AAD} = \text{UTF8}(\text{session\_id} \parallel \text{":"} \parallel \text{family\_id} \parallel \text{":"} \parallel \text{old\_token\_hash} \parallel \text{":"} \parallel \text{grace\_expires\_at})$$
  - Prevents envelope transplantation across sessions or replay after grace expiration.
- **Envelope Storage Format:**
  $$\text{recovery\_envelope} = \text{hex}(\text{version}(1\text{B}) \parallel \text{iv}(12\text{B}) \parallel \text{auth\_tag}(16\text{B}) \parallel \text{ciphertext})$$
  - Version byte: `0x01`.
  - Ciphertext: Encrypted replacement refresh token $R_{i+1}$ (32 bytes).

### A.3 Fixing the Concurrent Batch Design: Elimination of Unconditional Inserts
In SQLite/D1, executing an unconditional `INSERT INTO revoked_refresh_tokens` in a batch whose `UPDATE sessions` affected 0 rows would insert an orphaned recovery record.

**The Fix: Two-Stage Conditional Edge Execution:**
Instead of an unconditional batch insert, the Cloudflare Worker executes a deterministic conditional sequence:

```typescript
// Step 1: Execute atomic conditional UPDATE
const updateResult = await db.prepare(`
  UPDATE sessions 
  SET refresh_token_hash = :hash_r_next,
      expected_proof_hash = :next_commitment,
      last_active_at = :now,
      expires_at = :now + 2592000000
  WHERE id = :session_id 
    AND refresh_token_hash = :hash_r_old 
    AND expected_proof_hash = :hash_k_client 
    AND is_revoked = 0
`).bind({
  hash_r_next, next_commitment, now, session_id, hash_r_old, hash_k_client
}).run();

if (updateResult.meta.changes === 1) {
  // Step 2a: Exactly ONE isolate won the rotation. Store recovery envelope.
  await db.prepare(`
    INSERT INTO revoked_refresh_tokens (
      id, session_id, family_id, old_token_hash, replacement_token_hash,
      authorized_proof_hash, recovery_envelope, grace_expires_at, created_at
    ) VALUES (
      :rev_id, :session_id, :family_id, :hash_r_old, :hash_r_next,
      :hash_k_client, :recovery_envelope, :now + 30000, :now
    )
  `).bind({ ... }).run();

  return c.json({ access_token: A_next, refresh_token: R_next });
}

// Step 2b: Update affected 0 rows -> Concurrent request, retry, or replay.
// FALLBACK TO RECOVERY OR REJECTION (See A.4)
```

**Proof of Exactly One Winner:**
Because SQLite WAL mode serializes writes, if two Worker isolates run this query concurrently for the same session:
1. Isolate A's `UPDATE` matches `refresh_token_hash = :hash_r_old` and executes. `changes === 1`.
2. Isolate B's `UPDATE` executes immediately after. Since the token hash was updated to `:hash_r_next`, Isolate B matches 0 rows (`changes === 0`).
3. Isolate B **does NOT insert into `revoked_refresh_tokens`**. Instead, Isolate B enters the recovery branch.

### A.4 Edge Retry, Concurrency & Failure Scenarios
1. **Lost Response (Network Drop):**
   Client retries with $(R_i, K_i)$. `UPDATE` returns `changes: 0`. Worker queries `revoked_refresh_tokens WHERE old_token_hash = H(R_i)`. Worker verifies `grace_expires_at > now` and $\text{SHA-256}(K_i) == \text{authorized\_proof\_hash}$. Decrypts `recovery_envelope` using $\text{HKDF}(K_i)$, mints fresh $A_{i+1}$, and returns $(A_{i+1}, R_{i+1})$.
2. **Concurrent Edge Requests:**
   Mobile coordinator queues requests to single-flight. If two requests slip through to edge, Isolate A wins (`changes: 1`); Isolate B falls into recovery path, decrypts envelope, and returns the identical replacement credentials.
3. **Worker Restarts / Multi-DC Workers:**
   State is fully committed in D1 tables. No in-memory cache or KV is consulted. Any isolate in any datacenter can process the recovery.
4. **Client Crashes Before Response:**
   On app restart, client reads $(R_i, K_i)$ from Android Keystore. Sends refresh request. Recovers replacement credentials seamlessly.
5. **Request After Grace Period (> 30s):**
   Worker detects old token with `:now > grace_expires_at`. **Active replay/theft detected.** Worker triggers immediate cascade:
   ```sql
   UPDATE sessions SET is_revoked = 1 WHERE family_id = :family_id;
   ```
   Entire token family revoked. HTTP 401 returned.

### A.5 Database Dump & Attacker Threat Model Analysis
- **Attacker Threat Model 1: Stolen Database Dump**
  - Database stores: $\text{SHA-256}(R)$, $\text{SHA-256}(K)$, and AES-256-GCM ciphertexts.
  - Attacker lacks client hardware Keystore.
  - Because $K$ is in client Keystore, attacker cannot compute $K_{\text{enc}} = \text{HKDF}(K)$.
  - **Result:** Zero plaintext tokens or secrets recoverable from database dump.
- **Attacker Threat Model 2: Intercepted $R_0$ Over Network / Logs**
  - Attacker holds $R_0$.
  - Database requires $K_0$ such that $\text{SHA-256}(K_0) == \text{expected\_proof\_hash}$.
  - Attacker lacks $K_0$.
  - **Result:** Attacker cannot rotate session or obtain credentials.
- **Attacker Threat Model 3: Client Holding Both $R_0$ and $K_0$ Accessing Database Dump**
  - If a user has their own $K_0$, they can decrypt *their own* recovery envelope from a dump.
  - They CANNOT decrypt any other user's envelope because every envelope is keyed by that user's unique $K$.
- **Attacker Threat Model 4: Full Physical Device Compromise (Root / Keystore Dump)**
  - If the adversary gains physical root access and extracts $R_0$ AND $K_0$ from the Android Keystore, the adversary is cryptographically indistinguishable from the authentic client.
  - *Mitigation:* Bounded session expiry (30 days), remote distributor owner deactivation, and single active session per organization.

### A.6 Test Status Disclosure
> [!CAUTION]
> While the cryptographic mathematics and SQL sequence are fully specified, **this refresh rotation and recovery flow has NOT been tested in live Cloudflare Worker code**, because Phase Auth-4 (refresh route implementation) has not been built.
> **Verdict: NOT READY (UNTESTED RUNTIME).**

---

## B. Migration Rollback, Schema Comparison & Data Preservation

### B.1 Complete Column-by-Column Schema Comparison

| Column Name | Original `organization_memberships` (0019) | Rebuilt `organization_memberships` (0024) | `organization_memberships_quarantine` | Preservation Status |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `TEXT PRIMARY KEY` | `TEXT PRIMARY KEY` | `TEXT PRIMARY KEY` | **100% Preserved** |
| `organization_id` | `TEXT NOT NULL, FK(organizations)` | `TEXT NOT NULL, FK(organizations)` | `TEXT` | **100% Preserved** |
| `user_id` | `TEXT NOT NULL, FK(users)` | `TEXT NOT NULL, FK(users)` | `TEXT` | **100% Preserved** |
| `role` | `TEXT NOT NULL CHECK(role IN (9 legacy roles))` | `TEXT NOT NULL CHECK(role IN (8 canonical roles))` | `TEXT` | **100% Preserved** (Mapped or Quarantined) |
| `is_active` | `INTEGER NOT NULL DEFAULT 1` | `INTEGER NOT NULL DEFAULT 1` | `INTEGER` | **100% Preserved** |
| `created_at` | `INTEGER NOT NULL` | `INTEGER NOT NULL` | `INTEGER` | **100% Preserved** |
| `updated_at` | *Did not exist in 0019* | `INTEGER NOT NULL` (seeded from `created_at`) | *N/A* | **Added in 0024** |
| `quarantine_reason`| *N/A* | *N/A* | `TEXT NOT NULL` | **Added for Audit Trail** |
| `quarantined_at` | *N/A* | *N/A* | `INTEGER NOT NULL` | **Added for Audit Trail** |

**Zero Column Data Loss:** Every single row and every attribute from the original table survives intact in either the active table or the quarantine table.

### B.2 Deterministic Duplicate Resolution
If the legacy database permitted duplicate `(organization_id, user_id)` memberships, tie-breaking must be strictly deterministic across equal or NULL timestamps:

```sql
SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (
        PARTITION BY organization_id, user_id 
        ORDER BY coalesce(created_at, 0) DESC, id DESC
    ) as rn
    FROM organization_memberships
) WHERE rn > 1;
```
- **Newer timestamps win:** `created_at DESC`.
- **Equal timestamps:** Broken deterministically by alphanumeric primary key: `id DESC`.
- **NULL timestamps:** `coalesce(created_at, 0)` treats NULL as epoch 0 (oldest), guaranteeing valid timestamped rows take precedence.
- Exactly one row ($rn = 1$) is promoted to the rebuilt table; all others ($rn > 1$) are routed to `organization_memberships_quarantine`.

### B.3 Post-Migration Writes & Snapshot Rollback Disclosure

> [!WARNING]
> **Snapshot Rollback Discards Post-Migration Writes:**
> Executing `rollback_0024.sql` (renaming `organization_memberships_backup_0024` back to `organization_memberships`) is a **table-snapshot restore**.
> If new users were invited or new roles (`SALES_MANAGER`, `ACCOUNTANT`) were written *after* Migration 0024 ran, **those post-migration writes will be discarded upon rollback**.
> Therefore, snapshot rollback is NOT lossless for post-migration activity. If post-migration writes exist, a **forward-reconciliation script** must be used instead of a raw snapshot swap.

### B.4 Actual Miniflare D1 Rollback & FK Execution Evidence
Executed directly against `miniflare@5.20260918.0-alpha` in `scratch/validate_auth13_miniflare.mjs`:

```
=== STARTING AUTH-1.3 MINIFLARE D1 VERIFICATION ===
Pre-seed completed. Running Migration 0024...
Active rows count: 3
Scenario B.2: Deterministic duplicate tie-breaker (equal timestamp + id sort): PASS
Quarantine rows count: 4
Scenario B.1: Malformed & duplicate quarantine preservation: PASS
Scenario B.6: PRAGMA foreign_key_check after migration: PASS (0 violations)
Simulating post-migration writes (new canonical roles)...
Executing Rollback 0024 SQL...
Restored rows count: 7
Scenario B.3 & B.4: Rollback restores original table; post-migration writes are discarded by snapshot restore (PROVEN: snapshot rollback is NOT lossless for post-writes!): PASS
Scenario B.6: PRAGMA foreign_key_check after rollback: PASS (0 violations)
Scenario B.5: Quarantine table survives rollback: PASS
=== ALL AUTH-1.3 MINIFLARE D1 CHECKS PASSED ===
```

- **FK Integrity:** `PRAGMA foreign_key_check` returned 0 violations after forward migration, and 0 violations after rollback.
- **Quarantine Survival:** Quarantine table survives rollback completely.

---

## C. Miniflare Evidence Correction & Verification

### C.1 Installed Miniflare Version Resolution
- **Exact Installed Version:** `miniflare@5.20260918.0-alpha` (located in `backend/node_modules/miniflare/package.json` and `backend/package-lock.json`).
- **Resolution of "Miniflare 3 vs Miniflare 5" Inconsistency:**
  - Cloudflare introduced the C++ `workerd` isolate architecture in Miniflare v3.
  - In Wrangler 4+, the internal package version was bumped to 5.x.
  - Previous reports colloquially used "Miniflare 3" to indicate the *workerd architecture*, whereas the actual npm package version is **`5.20260918.0-alpha`**. This report standardizes on the exact installed package version.

### C.2 Exact Test Command & Execution Evidence
- **Command:**
  ```powershell
  node "C:\Users\Rakesh kumar\.gemini\antigravity\brain\809621ce-2d19-4eeb-9f07-7064006df622\scratch\validate_auth13_miniflare.mjs"
  ```
- **Results:** 100% pass rate on disposable Miniflare D1 isolate.

> [!NOTE]
> **Production Cloudflare D1 Disclosure:**
> All tests were executed in local disposable Miniflare D1 isolates. **Zero queries or migrations have been run on Cloudflare remote staging or production D1.**

---

## D. OAuth Nonce Specification & Untested Boundaries

1. **Login Attempt Binding:**
   Client calls `POST /auth/oauth/nonce` with `device_id`.
   Server creates a unique attempt identifier: `attempt_id = 'att_' || hex(randomblob(16))`.
   Server generates 256-bit random nonce $N$, hashes it $H(N) = \text{SHA-256}(N)$, and stores:
   ```sql
   INSERT INTO oauth_nonces (nonce_hash, attempt_id, device_id, expires_at, created_at)
   VALUES (:hash_n, :attempt_id, :device_id, :now + 300000, :now);
   ```
2. **Atomic One-Time Consumption:**
   When client submits Google ID token to `POST /auth/google`:
   ```sql
   DELETE FROM oauth_nonces 
   WHERE nonce_hash = :token_nonce_hash 
     AND device_id = :request_device_id 
     AND expires_at > :now
   RETURNING attempt_id;
   ```
   - If 1 row returned: Nonce is valid and consumed. Attempt is bound.
   - If 0 rows returned: Nonce was already consumed, expired, or bound to a different device. Rejection with `HTTP 401 Unauthorized`.
3. **Google ID Token Nonce Comparison:**
   Worker parses JWT claims, asserting `claims.nonce === raw_nonce_from_client`.
4. **Untested Boundary Disclosure:**
   Live Google JWKS verification, network rate-limiting under partition, and clock-skew tolerances are **UNTESTED in live Cloudflare Worker code**.
   **Verdict: NOT READY (UNTESTED RUNTIME).**

---

## F. Final Independent Verdicts

In strict accordance with the Auth-1.3 mandate, separate independent verdicts are rendered:

| Evaluation Area | Verdict | Justification & Evidentiary Basis |
| :--- | :---: | :--- |
| **1. Refresh-Token Security** | **NOT READY** | The PSBR protocol, hardware Keystore storage, AES-256-GCM envelope, and conditional D1 updates are fully specified. However, runtime code in Cloudflare Workers has **not yet been implemented or load-tested**. |
| **2. Migration Forward Execution** | **READY** | Migration 0024 DDL expands CHECK constraint to 8 canonical roles, normalizes legacy aliases, and isolates malformed/duplicates. Validated on Miniflare D1 isolate. |
| **3. Migration Rollback / Recovery** | **CONDITIONAL** | Snapshot rollback is verified on Miniflare D1 (0 FK violations). **Conditional on:** acknowledging that snapshot restore discards post-migration writes, requiring forward-reconciliation if new writes exist. |
| **4. Miniflare Validation** | **READY** | Verified on `miniflare@5.20260918.0-alpha` with forward migration, duplicate tie-breaking, malformed quarantine, FK checks, and rollback. |
| **5. Production D1 Readiness** | **NOT READY** | **Zero remote tests executed.** Miniflare local simulation does not certify remote edge replication, remote timeouts, or network batch atomicity. |
| **6. OAuth Nonce** | **NOT READY** | Atomic deletion pattern and attempt-binding specified, but backend endpoint and live Google cert integration remain **untested in runtime code**. |
| **7. Auth-1 Implementation Eligibility** | **CONDITIONAL** | Migration 0024 strictly targets `organization_memberships` (a leaf table with 0 foreign key dependents). It can be approved for staging D1 deployment **only after** an automated pre-migration backup of the staging database is verified. |

---

> [!IMPORTANT]
> **No implementation or deployment has been authorized or performed.**
> Backend source code, migrations directory, Flutter client code, and database state remain completely untouched.
