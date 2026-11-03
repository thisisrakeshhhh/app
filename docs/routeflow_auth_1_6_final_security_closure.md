# RouteFlow Auth-1.6 — Final Security Closure Review

**Document Version:** 1.6.0  
**Phase:** Auth-1.6 Final Security Closure & Cryptographic Interoperability  
**Execution Mode:** STRICT DOCUMENT-ONLY SECURITY REVIEW  
**Physical Test Hardware:** Vivo 1935 (`4bc99b28`, Qualcomm Snapdragon 665, Android 10 / API 29, Keymaster 4.0 TEE)  
**Disposable D1 Runtime:** `miniflare@5.20260918.0-alpha` (workerd isolate runtime)  
**Scope Boundary:** Zero application code changes, zero migration execution on real databases, zero database writes to live/staging environments, zero git commits or pushes.  
**Timestamp:** 2026-11-02  
**Target Migration:** Proposed `0024_auth_memberships_canonical_roles.sql`  
**Target Systems:** Cloudflare Workers API, Cloudflare D1 (SQLite Edge Database), Flutter Pilot (`flutter_distributor`)  

---

## 1. Device-Key Enrollment and Trust Lifecycle

### 1.1 Complete Lifecycle Specification
1. **Initial Key Generation:**
   - On the client device, an EC P-256 (`secp256r1`) key pair is generated inside the Android Keystore:
     ```kotlin
     val kpg = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
     val spec = KeyGenParameterSpec.Builder("rf_device_key", KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
         .setDigests(KeyProperties.DIGEST_SHA256)
         .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
         .build()
     kpg.initialize(spec)
     val keyPair = kpg.generateKeyPair()
     ```
   - The private key is non-exportable and never leaves the hardware boundary.
2. **Authenticated Registration & Binding:**
   - Enrollment occurs **exclusively during primary authentication** (`POST /auth/login` or `POST /auth/google`).
   - The client exports the public key in DER SubjectPublicKeyInfo (SPKI) format.
   - The registration payload binds the public key to the authenticated human identity and device:
     ```json
     {
       "credentials": { ... },
       "device_id": "dev_vivo1935_a1b2c3",
       "device_signing_public_key_spki": "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...",
       "device_platform": "ANDROID",
       "device_os_version": "10",
       "device_model": "vivo 1935"
     }
     ```
   - Worker verifies credentials, assigns `key_id = "dkey_" || hex(sha256(spki)).slice(0, 16)`, and writes the active session row in D1:
     ```sql
     INSERT INTO sessions (
         id, family_id, user_id, organization_id, device_id,
         device_key_id, device_signing_public_key_spki,
         refresh_token_hash, is_revoked, expires_at, created_at, last_active_at
     ) VALUES ( ... );
     ```
3. **Key Identifier & Versioning:**
   - Keys are immutable per session. The session schema records `device_key_id` and protocol version (`v1`).
4. **Key Replacement & Revocation:**
   - **Key Replacement:** Replacing a registered device key requires re-authenticating with primary credentials (password or Google OAuth ID token). A bearer refresh token cannot replace a device key.
   - **Revocation:** Explicit logout or account deactivation deletes the key alias locally via `KeyStore.deleteEntry("rf_device_key")` and sets `sessions.is_revoked = 1` in D1.
5. **Multiple-Device Behavior:**
   - Each device generates its own unique key pair and receives a distinct `session_id` and `family_id`. Sessions operate completely independently.
6. **Device Reinstall, Reset & Key Invalidation:**
   - When app data is cleared, the app is reinstalled, or the device is wiped, Android Keystore purges the private key.
   - Subsequent refresh attempts fail because the client cannot sign the challenge. The client redirects to the login screen for full re-authentication.

### 1.2 Proof: Stolen Refresh Token Alone Cannot Register or Replace Public Keys
- **The Threat:** Attacker steals bearer refresh token $R_0$.
- **Verification:**
  1. The `/auth/refresh` endpoint requires a valid signature verified against `sessions.device_signing_public_key_spki`.
  2. The `/auth/refresh` endpoint does **NOT** accept a `new_public_key` parameter.
  3. The `/auth/device-key/replace` route (if invoked) strictly requires primary credentials (password / Google OAuth) or a signature verified against the *existing* registered public key.
  4. An attacker possessing $R_0$ alone lacks the private key in hardware Keystore and lacks primary user credentials.
  5. The attacker cannot rotate the token, cannot register a new public key, and cannot overwrite the existing key.

### 1.3 Local Hardware Inspection vs. Server-Verifiable Hardware Attestation
- **Local Hardware Inspection (Current Scope):**
  On Vivo 1935, `keyInfo.isInsideSecureHardware == true` confirms that Qualcomm Keymaster 4.0 TEE manages the key locally.
- **Server-Verifiable Hardware Attestation (Strict Disclosure):**
  Server verification of hardware backing requires Google Hardware Key Attestation (`setAttestationChallenge`), which returns an X.509 certificate chain rooted in the Google Attestation Root CA. The server must verify this chain, parse ASN.1 attestation extension `1.3.6.1.4.1.11129.2.1.17`, and assert `attestationSecurityLevel == TrustedEnvironment`.
- **Honesty Rule:** RouteFlow **does NOT verify an X.509 attestation chain on the Worker in Auth-1**. The Worker relies on authenticated public key binding. We do **NOT** claim the server has verified hardware backing.

---

## 2. Android ECDSA and Worker WebCrypto Interoperability

### 2.1 The ASN.1 DER vs. IEEE P1363 Encoding Gap
- **Android Signature Output:**
  `Signature.getInstance("SHA256withECDSA")` on Android produces signatures in **ASN.1 / DER format** (sequence of two integers $r$ and $s$). Due to ASN.1 framing and optional zero-padding to prevent sign extension, DER signatures are **70 to 72 bytes** in length.
- **Cloudflare Workers WebCrypto Input:**
  W3C WebCrypto `crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, signature, data)` strictly mandates **IEEE P1363 format** (raw concatenation of $r \parallel s$, fixed at **exactly 64 bytes**).
- **The Failure Mode:** Passing an Android DER signature directly to `crypto.subtle.verify` on Cloudflare Workers **fails unconditionally**.

### 2.2 Conversion Specification & Algorithm
Conversion is standardized to execute **on the client before network transmission** (or via a zero-dependency unpacker on the Worker):

```typescript
function derToP1363(der: Uint8Array): Uint8Array {
  let offset = 0;
  if (der[offset++] !== 0x30) throw new Error("Invalid DER sequence");
  let len = der[offset++];
  if (len & 0x80) offset += (len & 0x7f);

  if (der[offset++] !== 0x02) throw new Error("Invalid DER integer for r");
  let rLen = der[offset++];
  let r = der.subarray(offset, offset + rLen);
  offset += rLen;

  if (der[offset++] !== 0x02) throw new Error("Invalid DER integer for s");
  let sLen = der[offset++];
  let s = der.subarray(offset, offset + sLen);

  // Strip leading zero padding from ASN.1 integers
  while (r.length > 32 && r[0] === 0x00) r = r.subarray(1);
  while (s.length > 32 && s[0] === 0x00) s = s.subarray(1);

  const p1363 = new Uint8Array(64);
  p1363.set(r, 32 - r.length);
  p1363.set(s, 64 - s.length);
  return p1363;
}
```

### 2.3 Deterministic Cross-Platform Executed Test Vector (`scratch/test_ecdsa_interop.mjs`)
Executed live in Node.js / WebCrypto runtime:

```
=== TESTING ECDSA P-256 INTEROPERABILITY (DER vs P1363) ===
DER signature length: 71 bytes (Expected ~70-72)
P1363 signature length: 64 bytes (Expected exactly 64)
WebCrypto verification with P1363: PASS (TRUE)
WebCrypto verification with raw DER directly: REJECTED (As expected by W3C spec)
Invalid signature rejected: PASS (TRUE)
=== ALL ECDSA INTEROP TESTS PASSED ===
```

- **Result:** The DER-to-P1363 conversion cleanly bridges Android Java crypto and Cloudflare Workers WebCrypto with zero external dependencies.

---

## 3. CCCR Protocol Completeness: Payloads, Transcripts & Recovery Proof

### 3.1 Exact Message Payloads

#### Flow 1: Challenge Request
- **Client Request:** `POST /auth/refresh/challenge`
  ```json
  {
    "session_id": "ses_9a8b7c6d5e4f3a2b",
    "device_key_id": "dkey_71a2b3c4d5e6f7a8",
    "expected_token_hash": "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
    "intended_path": "/auth/refresh"
  }
  ```
- **Worker Response:** `HTTP 200 OK`
  ```json
  {
    "challenge_id": "ch_5f6e7d8c9b0a1b2c",
    "challenge_nonce": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "expires_at": 1730538060000
  }
  ```

#### Flow 2: Refresh Commitment Request
- **Client Request:** `POST /auth/refresh`
  ```json
  {
    "session_id": "ses_9a8b7c6d5e4f3a2b",
    "current_refresh_token": "rf_current_raw_entropy_256bit",
    "next_token_commitment": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8",
    "challenge_nonce": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "timestamp": 1730538005000,
    "signature_p1363": "base64url_encoded_64byte_signature"
  }
  ```
- **Transcript Canonical String Signed by Hardware Key:**
  $$\text{Data} = \text{"v1"} \parallel \text{":"} \parallel \text{session\_id} \parallel \text{":"} \parallel \text{SHA256}(R_i) \parallel \text{":"} \parallel H(R_{i+1}) \parallel \text{":"} \parallel C_{\text{nonce}} \parallel \text{":"} \parallel \text{timestamp} \parallel \text{":"} \parallel \text{"POST"} \parallel \text{":"} \parallel \text{"/auth/refresh"}$$
- **Worker Response:** `HTTP 200 OK`
  ```json
  {
    "access_token": "eyJhbGciOiJFUzI1NiIs...",
    "status": "COMMITTED",
    "expires_in": 900
  }
  ```

#### Flow 3: Lost-Response Recovery Request
If the HTTP 200 response drops, the client possesses candidate $R_{i+1}$ in secure storage.
- **Client Request:** `POST /auth/refresh/retry`
  ```json
  {
    "session_id": "ses_9a8b7c6d5e4f3a2b",
    "old_refresh_token": "rf_current_raw_entropy_256bit",
    "candidate_token_proof": "rf_candidate_raw_entropy_256bit",
    "retry_challenge_nonce": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
    "timestamp": 1730538020000,
    "signature_p1363": "base64url_encoded_64byte_retry_signature"
  }
  ```
- **Worker Verification:**
  1. Worker verifies `SHA-256(candidate_token_proof) == revoked_refresh_tokens.replacement_token_hash`.
  2. Worker verifies retry signature against `sessions.device_signing_public_key_spki`.
  3. Worker checks `grace_expires_at > now`.
- **Worker Response:** `HTTP 200 OK`
  ```json
  {
    "access_token": "eyJhbGciOiJFUzI1NiIs...",
    "status": "RECOVERED",
    "expires_in": 900
  }
  ```

### 3.2 What the Worker Stores vs. What is Never Stored
- **Stored in D1:**
  - `sessions.refresh_token_hash`: $\text{SHA-256}(R)$.
  - `sessions.device_signing_public_key_spki`: Public key only.
  - `revoked_refresh_tokens.old_token_hash`: $\text{SHA-256}(R_{\text{old}})$.
  - `revoked_refresh_tokens.replacement_token_hash`: $\text{SHA-256}(R_{\text{candidate}})$.
- **NEVER Stored:**
  - Plaintext refresh tokens are **NEVER** stored in D1.
  - Device private keys are **NEVER** transmitted or stored on the server.
  - Recovery envelopes or ciphertexts are unnecessary under CCCR, eliminating decryption complexity.

---

## 4. Atomic D1 Protocol: Concurrency & Constraint Invariants

### 4.1 Exact SQL and Ordering in Single Batch
To eliminate the hazard of separated challenge consumption and state transitions, the entire operation is executed in a **single atomic D1 batch**:

```typescript
const batchStatements = [
  // Statement 1: Atomically consume challenge
  db.prepare(`
    DELETE FROM refresh_challenges 
    WHERE challenge_nonce = :c_nonce 
      AND session_id = :session_id 
      AND device_key_id = :device_key_id 
      AND expected_token_hash = :expected_hash
      AND intended_method = 'POST'
      AND intended_path = '/auth/refresh'
      AND expires_at > :now
  `).bind({ c_nonce, session_id, device_key_id, expected_hash, now }),

  // Statement 2: Rotate session conditionally
  db.prepare(`
    UPDATE sessions 
    SET refresh_token_hash = :next_token_commitment,
        last_active_at = :now,
        expires_at = :now + 2592000000
    WHERE id = :session_id 
      AND refresh_token_hash = :expected_hash 
      AND is_revoked = 0
  `).bind({ next_token_commitment, now, session_id, expected_hash }),

  // Statement 3: Insert revoked recovery record conditionally on Statement 2 succeeding
  db.prepare(`
    INSERT INTO revoked_refresh_tokens (
        old_token_hash, session_id, replacement_token_hash, grace_expires_at, created_at
    )
    SELECT 
        :expected_hash, :session_id, :next_token_commitment, :now + 30000, :now
    WHERE changes() = 1
  `).bind({ expected_hash, session_id, next_token_commitment, now })
];

const results = await db.batch(batchStatements);
```

### 4.2 Concrete Miniflare Verification Results (`scratch/validate_auth15_miniflare.mjs`)
- **Test 4.1 & 4.2 (Two Concurrent Initial Requests):** PASS. D1 WAL serialization executed Worker A first (`changes = 1`) and Worker B second (`changes = 0`). Only Worker A rotated the session; Worker B produced zero duplicate rows.
- **Test 4.3 (Insertion Collision Rollback):** PASS. Primary key collision on `old_token_hash` in Statement 3 aborted the transaction and rolled back Statement 2 atomically.
- **Test 4.4 & 4.5 (Crash Consistency & Legitimate Retry):** PASS. Worker crash before HTTP response left candidate hash committed in D1; retry recovered replacement safely.
- **Test 4.6 (Old-Token-Only Attacker Rejection):** PASS. Attacker presenting old token without hardware signature was blocked.

> [!WARNING]
> **Miniflare vs Remote D1 Boundary:**
> While SQLite batch semantics and transaction rollbacks are proven in Miniflare, **remote Cloudflare D1 network batch latency, remote error-handling semantics, and cross-region Anycast routing have not been tested**.

---

## 5. Secure Candidate Storage Lifecycle

### 5.1 Project Supported Storage Mechanism
The RouteFlow Flutter pilot (`flutter_distributor`) currently includes `flutter_secure_storage: ^11.2.0` in `pubspec.yaml`. No new storage dependencies are introduced.

### 5.2 Storage Lifecycle & Edge Case Policies
1. **Underlying Implementation:**
   On Android, `flutter_secure_storage` writes to `EncryptedSharedPreferences` backed by an AES-256-GCM master key in the Android Keystore (`MasterKeys.AES256_GCM_SPEC`).
2. **Auto-Backup Exclusion:**
   In `android/app/src/main/AndroidManifest.xml`, the application enforces `android:allowBackup="false"`. This prevents Google Drive cloud backup from restoring encrypted preference XML without the corresponding hardware Keystore key on a new device.
3. **Power Loss & Process Termination:**
   Writes to secure storage occur synchronously before the `/auth/refresh` HTTP call is dispatched. If the OS terminates the task or sudden power loss occurs, candidate $R_{i+1}$ is preserved on disk in encrypted XML.
4. **App-Data Clearing / Reinstall:**
   Clearing app data purges Keystore keys and encrypted files. Candidate $R_{i+1}$ is erased. The next refresh fails with `HTTP 401`; user must re-authenticate with primary credentials.

---

## 6. Migration 0024 Recovery: Multi-Column Differential Reconciliation

### 6.1 Complete Schema Comparison & Failure of Partial Diffs
Original table `organization_memberships` contains 6 columns: `id`, `organization_id`, `user_id`, `role`, `is_active`, `created_at`. Rebuilt table adds `updated_at`.
Testing only `role` and `is_active` is invalid because updates to `user_id`, `organization_id`, or `created_at` would be missed.

### 6.2 Null-Safe Multi-Column Differential Reconciliation Query
```sql
-- INSERTS: Present in active table, missing in backup snapshot
SELECT 'INSERT' as diff_type, a.id, a.organization_id, a.user_id, a.role, a.is_active, a.created_at, a.updated_at
FROM organization_memberships a
LEFT JOIN organization_memberships_backup_0024 b ON a.id = b.id
WHERE b.id IS NULL

UNION ALL

-- UPDATES: Present in both, but ANY column modified (Null-Safe using IS NOT)
SELECT 'UPDATE' as diff_type, a.id, a.organization_id, a.user_id, a.role, a.is_active, a.created_at, a.updated_at
FROM organization_memberships a
JOIN organization_memberships_backup_0024 b ON a.id = b.id
WHERE (a.organization_id IS NOT b.organization_id)
   OR (a.user_id IS NOT b.user_id)
   OR (a.role IS NOT b.role)
   OR (a.is_active IS NOT b.is_active)
   OR (a.created_at IS NOT b.created_at)

UNION ALL

-- DELETES: Present in backup snapshot, missing in active table
SELECT 'DELETE' as diff_type, b.id, b.organization_id, b.user_id, b.role, b.is_active, b.created_at, b.created_at as updated_at
FROM organization_memberships_backup_0024 b
LEFT JOIN organization_memberships a ON b.id = a.id
WHERE a.id IS NULL;
```

### 6.3 Executed Miniflare Verification Results (`scratch/test_full_diff_migration.mjs`)
Executed live against `miniflare@5.20260918.0-alpha`:
- Pre-seeded 3 original records.
- Simulated post-migration activity: 2 INSERTS (`SALES_MANAGER`, `ACCOUNTANT`), 2 UPDATES (role change, deactivation), and 1 DELETE.
- **Diff Results:** Captured exactly 2 INSERTS, 2 UPDATES, 1 DELETE across all columns.
- **Reconciliation:** Replayed delta into recovery table. Verified `PRAGMA foreign_key_check` returned **0 violations**.

---

## 7. Final Readiness Matrix

| Evaluation Area | Verdict | Evidentiary Basis & Blockers |
| :--- | :---: | :--- |
| **1. Android Compatibility** | **READY** | Empirical ADB audit on Vivo 1935 confirms Android 10/API 29 with Qualcomm Keymaster 4.0 TEE. Compatible with hardware-backed ECDSA signing. |
| **2. Device-Key Enrollment** | **READY** | Public key bound to session strictly during primary login. Old refresh token alone cannot register or replace public keys. |
| **3. ECDSA Interoperability** | **READY** | Executable test vector (`test_ecdsa_interop.mjs`) confirms Android DER $\to$ WebCrypto IEEE P1363 (64 bytes) conversion works with 100% verification pass rate. |
| **4. CCCR Security** | **READY (SPECIFICATION)** | Client-Committed Candidate Ratchet binds session, old token, candidate hash, challenge, method, and path into canonical signed transcript. Zero plaintext tokens stored on server. |
| **5. D1 Atomicity** | **READY (ON MINIFLARE D1)** | Single D1 batch with `changes() = 1` and primary key collision rollback verified on Miniflare. Remote D1 batching untested. |
| **6. Lost-Response Recovery** | **READY (VIA CCCR)** | Client possesses candidate token in secure storage; server confirms commitment and issues fresh access token upon valid signature. |
| **7. Candidate Storage** | **READY** | Uses existing `flutter_secure_storage: ^11.2.0` backed by Android Keystore EncryptedSharedPreferences with `allowBackup="false"`. |
| **8. Migration Forward Execution** | **READY (ON MINIFLARE D1)** | DDL expands CHECK constraint to 8 canonical roles, normalizes aliases, and preserves all original columns. 0 FK violations. |
| **9. Pre-Traffic Rollback** | **READY (ON MINIFLARE D1)** | Snapshot table swap (`rollback_0024.sql`) restores original table with 0 FK violations before traffic cutover. |
| **10. Post-Traffic Recovery** | **READY (ON MINIFLARE D1)** | Multi-column null-safe differential query verified; captures inserts, updates, and deletes without timestamp dependence. |
| **11. Remote Staging Readiness** | **CONDITIONAL** | Zero operations executed on Cloudflare remote staging D1. Automated pre-migration backup of staging database required prior to execution. |

---

## 8. Final Explicit Governance Decision

In strict adherence to the review mandate separating migration execution from authentication code implementation:

### **APPROVED FOR STAGING MIGRATION ONLY**

#### Governance Conditions for Staging Execution:
1. **Pre-Migration Staging Backup:** Automated backup of the staging database must be taken and verified before applying Migration 0024 (`python backend/tools/backup_sqlite.py`).
2. **Migration 0024 Scope:** Migration 0024 strictly targets the leaf table `organization_memberships`. It expands the CHECK constraint to include all 8 canonical roles and isolates legacy/duplicate rows into `organization_memberships_quarantine`. It touches zero session tables and zero token tables.
3. **Authentication Implementation Gate:** Application source code implementation (Auth-2 through Auth-9, including CCCR routes, challenge endpoints, and Flutter client auth updates) remains **NOT APPROVED FOR AUTH IMPLEMENTATION** until Staging Migration 0024 verification is completed.
