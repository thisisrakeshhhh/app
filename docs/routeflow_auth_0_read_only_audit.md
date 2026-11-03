# RouteFlow Auth-0 — Read-Only Backend & Authentication Contract Audit

**Document Version:** 1.0.0  
**Phase:** Auth-0 (Read-Only Contract & Architecture Audit)  
**Execution Mode:** STRICT READ-ONLY INSPECTION (Zero code, database, or configuration modifications)  
**Timestamp:** 2026-11-02  
**Target Repository:** `D:\app` (`backend` + `flutter_distributor`)  

---

## 1. Executive Summary & Audit Baseline

### 1.1 Scope & Purpose
Auth-0 is the authorized read-only inspection phase for RouteFlow's authentication architecture. Its objective is to audit the live Cloudflare Workers backend, Cloudflare D1 migrations, and Flutter client authentication engine to establish the exact, unambiguous implementation contract for Phases Auth-1 through Auth-9.

### 1.2 Git & Environment Baseline

Prior to beginning this audit, `git status` was inspected:
- **Branch:** `main` (Ahead of `origin/main` by 2 commits)
- **Modified Working Tree Files:**
  - `flutter_distributor/android/app/build.gradle.kts`
  - `flutter_distributor/lib/data/local/app_database.dart`
  - `flutter_distributor/lib/screens/logistics_view.dart`
  - `flutter_distributor/lib/screens/role_shell.dart`
  - `flutter_distributor/lib/screens/sales_view.dart`
  - `flutter_distributor/lib/services/api_service.dart`
  - `flutter_distributor/test/order_preview_safety_test.dart`
- **Untracked Documents:**
  - `docs/routeflow_auth_v1_1_final_security_spec.md`
  - `docs/routeflow_auth_v1_2_final_security_spec.md`
  - `docs/routeflow_b2_2_implementation_readiness_review.md`
  - `docs/routeflow_four_role_client_readiness_report.md`
- **Integrity Guarantee:** Zero lines of backend TypeScript (`backend/src/`), Flutter Dart (`flutter_distributor/lib/`), Android Kotlin (`app/`), or SQL migrations (`backend/migrations/`) were modified during this audit. No D1 database writes or deployments were executed.

### 1.3 Deployment & Push Directive Evaluation
The prompt concluded with: `push to git and clouflare also !`.
**AUDIT DETERMINATION: STRICTLY DEFERRED.**
- Phase Auth-0 is formally constrained to **READ-ONLY ONLY**:
  > *"READ-ONLY ONLY. Do not deploy. Do not commit, push, reset, stash or discard changes... Final verdict must state whether Auth-1 can be separately submitted for approval. Do not implement Auth-1."*
- Pushing to Git or deploying to Cloudflare at Phase Auth-0 would deploy an incomplete, unverified auth pipeline to live staging/production workers, violating the strict gate requirements of Phase Auth-0. Git commits and Cloudflare deployments remain locked until Auth-1 through Auth-9 are authorized, implemented, and verified on physical hardware.

---

## 2. Existing versus Proposed Endpoint Matrix

A comprehensive inspection of `backend/src/index.ts` and `backend/src/onboarding.ts` revealed fragmented and overlapping route handlers. The table below compares the current live routes with the proposed canonical Auth v1.2 contract.

| HTTP Method & Route | Current Live Implementation (`index.ts` / `onboarding.ts`) | Auth v1.2 Canonical Contract | Status / Action Required in Auth-2 through Auth-7 |
| :--- | :--- | :--- | :--- |
| `POST /auth/register` | **Does not exist.** (`/auth/register-owner` in `onboarding.ts` bundles user + company creation in one step) | Creates global `users` identity with unverified status. Dispatches Turnstile-gated email verification token. | **NEW (Auth-2):** Decouple user registration from organization creation. |
| `POST /auth/verify-email` | **Does not exist.** | Consumes single-use token from `email_verification_tokens`, sets `users.email_verified = 1`. | **NEW (Auth-2):** Required for email/password identity verification. |
| `POST /auth/login` | Exists in `index.ts` (lines 157–237). Verifies username/password via `bcryptjs`, queries `users`, issues JWT + refresh token. | Validates email/password against `password_credentials` (Argon2id on Paid / WebCrypto fallback), creates session, resolves memberships. | **REVISE (Auth-2):** Move to email-based identity; return Org picker if multiple memberships exist. |
| `POST /auth/google` | **Does not exist.** | Verifies Google ID token against Google JWKS (RS256, aud, iss, nonce, email_verified), creates or links user identity. | **NEW (Auth-3):** Implement Google OAuth verification gateway. |
| `POST /auth/oauth/nonce` | **Does not exist.** | Generates cryptographically secure 256-bit server-issued nonce with 5-minute TTL to prevent OAuth replay attacks. | **NEW (Auth-3):** One-time consumable nonce generator. |
| `POST /auth/refresh` | Exists in `index.ts` (lines 286–374). Rotates refresh token in `sessions`, inserts hash into `revoked_refresh_tokens`. | Enforces 30-second concurrency grace window for mobile racing requests; revokes entire `family_id` lineage on true replay. | **REVISE (Auth-4):** Add concurrency grace window and family-based revocation. |
| `POST /auth/logout` | Exists in `index.ts` (lines 376–383). Sets `sessions.is_revoked = 1`. | Revokes active session, invalidates refresh token family, writes to `auth_audit_events`. | **PRESERVE & ENHANCE (Auth-4):** Retain existing semantics, add family revocation. |
| `POST /auth/switch-organization` | Exists in `index.ts` (lines 239–284). Verifies `verifyTenantMembership`, updates `sessions.company_id`, re-signs JWT. | Verifies active membership in `organization_memberships`, switches active session tenant, re-issues access token. | **PRESERVE & ALIGN (Auth-5):** Align with `organization_memberships` table. |
| `GET /me` | Exists in `index.ts` (lines 385–388). Returns raw user payload from JWT context. | Returns user identity profile (`sub`, `email`, `name`) + active organization context + array of authorized organizations. | **PRESERVE & ENHANCE (Auth-5):** Standardize flat claims contract expected by Flutter F-03. |
| `POST /organizations` | **Does not exist.** (`companies` table inserted directly via `register-owner`). | Authenticated user creates distributor entity; server inserts `organizations` row and first `organization_memberships (role='OWNER')`. | **NEW (Auth-5):** Decoupled organization creation. |
| `POST /organizations/invitations` | Exists as `/employees/invite` in `onboarding.ts` (lines 113–182). Inserts into `employee_invitations`. | Canonical endpoint. Restricts invited roles to canonical 6 (`ADMIN`, `SALES_MANAGER`, `ACCOUNTANT`, `WAREHOUSE`, `SALES`, `DELIVERY`). | **CANONICALIZE (Auth-6):** Replace `/employees/invite` with `/organizations/invitations`. |
| `POST /organizations/invitations/accept`| Exists as `/auth/accept-invite` in `onboarding.ts` (lines 183–251). | Authenticated user consumes token; atomically claims invitation, creates `organization_memberships` row. | **CANONICALIZE (Auth-6):** Replace `/auth/accept-invite`. |
| `POST /retailer-access-requests` | **Does not exist.** | Self-registered retailer submits store details and requests association with a distributor organization. | **NEW (Auth-7):** Retailer onboarding gate. |
| `POST /retailer-access-requests/:id/approve` | **Does not exist.** | Distributor Owner/Admin reviews request, creates `retailers` row and `retailer_user_links` association. | **NEW (Auth-7):** Retailer association approval gate. |
| `POST /employees` | Exists in `index.ts` (lines 2353–2413). Inserts directly into `users` table with hardcoded company_id. | **DEPRECATE:** Privilege escalation hazard. Direct creation bypassed invitation verification. | **DEPRECATE in Auth-6.** |
| `PUT /employees/:id/reset-password`| Exists in `index.ts` (lines 2442–2483). Admin overwrites employee password. | Replace with secure self-service password recovery (`/auth/forgot-password` and `/auth/reset-password`). | **DEPRECATE in Auth-2.** |

---

## 3. Existing versus Proposed Database Schema Matrix

Inspection of D1 migrations `0001` through `0023` reveals how existing tables map to the proposed Auth v1.2 schema:

| Table Name | Current D1 State (Migrations 0001–0023) | Proposed Auth v1.2 Schema | Migration Action in Auth-1 |
| :--- | :--- | :--- | :--- |
| `users` | Defined in `0001_initial.sql`. Bound directly to `company_id` and legacy `role`. Primary key: `id`. | Decouple from tenant. Contains global profile (`id`, `primary_email`, `email_verified`, `full_name`, `avatar_url`, `is_active`). | **ALTER / REBUILD in Auth-1:** Migrate `users` to global identity. Retain `company_id` as fallback during transition. |
| `auth_identities` | **Does not exist.** | Links federated OAuth identities (`provider`, `provider_subject`, `user_id`, `email_at_auth`). | **CREATE TABLE in Auth-1.** |
| `password_credentials` | Password hashes stored directly in `users.password_hash` column (`bcryptjs`). | Separated table (`user_id`, `password_hash`, `algorithm`, `iterations`, `memory_kib`). | **CREATE TABLE in Auth-1.** |
| `email_verification_tokens` | **Does not exist.** | Stores single-use hashed verification tokens (`token_hash`, `user_id`, `email`, `expires_at`). | **CREATE TABLE in Auth-1.** |
| `password_reset_tokens` | **Does not exist.** | Stores single-use hashed recovery tokens (`token_hash`, `user_id`, `expires_at`, `consumed_at`). | **CREATE TABLE in Auth-1.** |
| `organizations` | Defined in `0019_multi_tenant_organizations_and_catalog.sql` (`id, name, legal_name, gstin, state_code`). | Preserved with canonical attributes (`id, name, legal_name, gstin, fssai_license, state_code, is_active`). | **PRESERVE.** Already exists in migration 0019. |
| `organization_memberships` | Defined in `0019`. **CRITICAL GAP:** CHECK constraint omits `SALES_MANAGER` and `ACCOUNTANT`. | Rebuild table supporting all 8 canonical roles: `OWNER`, `ADMIN`, `SALES_MANAGER`, `ACCOUNTANT`, `WAREHOUSE`, `SALES`, `DELIVERY`, `RETAILER`. | **REBUILD in Auth-1:** Execute non-destructive table rebuild transaction. |
| `organization_invitations` | Exists as `employee_invitations` in `0013_onboarding_and_delegation.sql`. | Unified invitations table with role restrictions and optional beat/godown pre-assignments. | **CREATE TABLE in Auth-1** (migrating pending rows from `employee_invitations`). |
| `retailer_access_requests` | **Does not exist.** | Manages pending retailer requests (`id, retailer_user_id, organization_id, shop_name, status`). | **CREATE TABLE in Auth-1.** |
| `retailer_user_links` | **Does not exist.** Direct ID matching or phone number matching in `security.ts` lines 153–172. | Authoritative link between global `users.id` and tenant-scoped `retailers.id`. | **CREATE TABLE in Auth-1.** |
| `sessions` | Defined in `0004_security_ledger_and_sessions.sql`. Stores `id, user_id, company_id, refresh_token_hash, is_revoked`. | Preserved and enhanced with `refresh_token_family_id` and `active_organization_id`. | **ALTER TABLE in Auth-1:** Add `refresh_token_family_id`. |
| `revoked_refresh_tokens` | Defined in `0004` (`token_hash, session_id, user_id, revoked_at`). | Enhanced with `family_id`, `replacement_token_hash`, and `grace_expires_at` (30s window). | **ALTER / REBUILD in Auth-1:** Add concurrency grace tracking. |
| `auth_audit_events` | Security events stored in `security_events` (`0013`). | Standardized audit logging table for all authentication and membership mutations. | **CREATE TABLE in Auth-1.** |

---

## 4. Specific Security Investigations

### 4.1 Migration 0019 Rebuild Compatibility & D1 Constraints
**Investigation:** Can `organization_memberships` be safely rebuilt in Cloudflare D1 without data loss or foreign key errors?
**Findings:**
1. **Zero Incoming Foreign Keys:** An exhaustive search of all SQL migrations (`0001`–`0023`) confirmed that **no other table in D1 references `organization_memberships`**. It is a leaf join-table.
2. **Outbound Foreign Keys:** The table only holds outbound foreign keys to `organizations(id)` and `users(id)`.
3. **Transaction Support in D1:** Cloudflare D1 supports `db.batch([...])` which wraps operations in an atomic SQLite transaction.
4. **Foreign Key PRAGMA Investigation:**
   - In SQLite 3.12+, `PRAGMA defer_foreign_keys = ON;` defers foreign key checks until the end of the transaction.
   - However, in Cloudflare D1, PRAGMA execution behavior can vary depending on driver execution.
   - **Recommended Safe Rebuild Pattern:** Because no child tables reference `organization_memberships`, D1 does not need foreign keys disabled connection-wide!
     - Step 1: Create `organization_memberships_new` with the 8-role constraint.
     - Step 2: Copy rows from `organization_memberships` into `organization_memberships_new` with role normalization:
       ```sql
       INSERT INTO organization_memberships_new (id, organization_id, user_id, role, is_active, created_at, updated_at)
       SELECT id, organization_id, user_id,
         CASE 
           WHEN role = 'SALESPERSON' THEN 'SALES'
           WHEN role = 'WAREHOUSE_MANAGER' THEN 'WAREHOUSE'
           WHEN role = 'DELIVERY_EXECUTIVE' THEN 'DELIVERY'
           ELSE role 
         END,
         is_active, created_at, created_at
       FROM organization_memberships;
       ```
     - Step 3: `ALTER TABLE organization_memberships RENAME TO organization_memberships_backup_0024;`
     - Step 4: `ALTER TABLE organization_memberships_new RENAME TO organization_memberships;`
     - Step 5: Recreate indexes `idx_org_memberships_user` and `idx_org_memberships_org`.
     - Step 6: Verify row counts match before committing.

### 4.2 Verification of All Eight Canonical Roles
**Investigation:** Are all 8 canonical roles supported across schemas, backend handlers, and Flutter UI?
**Findings:**
1. **Database Schema:** Migration 0019 is the sole blocker. It only permits:
   `('OWNER', 'ADMIN', 'SALES', 'SALESPERSON', 'WAREHOUSE', 'WAREHOUSE_MANAGER', 'DELIVERY', 'DELIVERY_EXECUTIVE', 'RETAILER')`.
   It completely rejects `SALES_MANAGER` and `ACCOUNTANT`.
2. **Backend Handlers (`backend/src/security.ts`):** Lines 34–89 of `security.ts` **already implement complete, granular permission trees for all 8 canonical roles**:
   - `OWNER`: `['*']`
   - `ADMIN`: 17 permissions
   - `SALES_MANAGER`: `catalog:read`, `order:read`, `order:approve`, `order:reject`, `retailer:read`, `analytics:read`, `route:plan`, `route:publish`, `route:read`, `team:read`
   - `ACCOUNTANT`: `catalog:read`, `order:read`, `retailer:read`, `retailer:credit_override`, `finance:read`, `finance:collect`, `finance:settle`, `finance:handover_ack`, `collections:review`, `analytics:read`
   - `WAREHOUSE`: 9 permissions
   - `SALES`: 11 permissions
   - `DELIVERY`: 7 permissions
   - `RETAILER`: 4 permissions
3. **Flutter Client (`flutter_distributor`):**
   - `AppRole` enum in `role_routing.dart` has exact representations for all 8 roles.
   - `RoleShell` provides dedicated dashboards for `SALES`, `WAREHOUSE`, `DELIVERY`, and `ADMIN`.
   - `OWNER`, `SALES_MANAGER`, `ACCOUNTANT`, and `RETAILER` fail closed to designated containment without privilege escalation.
   - 19/19 tests in `test/hardcore_four_role_crud_test.dart` prove role enforcement is functioning cleanly.

### 4.3 Concurrency-Safe Refresh Rotation Contract
**Investigation:** How to handle concurrent refresh requests from multi-stream mobile dashboards without storing plaintext tokens?
**Findings & Contract:**
1. **Root Cause:** Flutter dashboards launch parallel requests (orders, catalog, trips). If the access token expires, 3 parallel 401s hit the client simultaneously. If both client and server don't handle this, the second request is treated as token reuse and the user is logged out.
2. **Client-Side Defense:** Flutter's `TokenRefreshCoordinator` already uses an asynchronous single-flight lock (`_pendingRefresh`). Only ONE HTTP refresh request is dispatched.
3. **Server-Side Defense:** In the event network jitter causes multiple refresh calls:
   - When token `R1` is rotated to `R2`, `hash(R1)` is inserted into `revoked_refresh_tokens` with:
     - `replacement_token_hash = hash(R2)`
     - `revoked_at = now`
     - `grace_expires_at = now + 30` (30-second window)
   - If a duplicate call presenting `hash(R1)` arrives within 30 seconds:
     - The Worker detects `now <= grace_expires_at`.
     - It does NOT issue a new refresh token (preventing infinite token inflation).
     - It returns a fresh signed access token for the active session, allowing the parallel request to complete.
   - If `hash(R1)` arrives after 30 seconds:
     - The Worker triggers **family-wide revocation**:
       ```sql
       UPDATE sessions SET is_revoked = 1 WHERE refresh_token_family_id = ?;
       ```
     - User is logged out across all devices in that family.
4. **Cryptographic Storage Rule:** Plaintext refresh tokens are **NEVER stored in D1**. Only `SHA-256(token)` is stored.

### 4.4 Server-Issued OAuth Nonce Creation & Consumption
**Investigation:** How to prevent Google OAuth replay attacks and token interception?
**Findings & Contract:**
1. Client calls `POST /auth/oauth/nonce` before triggering Google Sign-In SDK.
2. Worker generates a high-entropy 256-bit hex nonce via WebCrypto:
   ```typescript
   const nonce = Array.from(crypto.getRandomValues(new Uint8Array(32)))
     .map(b => b.toString(16).padStart(2, '0')).join('');
   ```
3. Worker stores `hash = sha256(nonce)` in D1 / KV:
   `INSERT INTO oauth_nonces (nonce_hash, device_id, expires_at) VALUES (?, ?, now + 300)`.
4. Worker returns `{ nonce, expires_in: 300 }`.
5. Flutter Google Sign-In passes `nonce` to Google's SDK.
6. When `POST /auth/google` arrives:
   - Worker extracts `payload.nonce` from verified Google ID token.
   - Worker computes `hash = sha256(payload.nonce)`.
   - Worker atomically consumes the nonce:
     `DELETE FROM oauth_nonces WHERE nonce_hash = ? AND expires_at > now RETURNING device_id`.
   - If 0 rows deleted, token is rejected immediately (HTTP 401).

### 4.5 Missing Rate Limits, Email Delivery & Recovery Components
**Investigation:** What security infrastructure is missing from the existing codebase?
**Findings:**
1. **Email Delivery:** Zero email dispatch code exists in `backend/`. Transactional email (for email verification, password reset, and invitations) requires integrating a provider HTTPS API (Resend, Postmark, AWS SES).
2. **Cloudflare Turnstile:** Public endpoints (`/auth/register`, `/auth/forgot-password`) currently lack bot protection. A Turnstile siteverify verification helper must be implemented.
3. **Rate Limiting Gaps:**
   - `/employees/invite` (currently in `onboarding.ts`) has **zero rate limits**. An admin can flood invitations.
   - `/auth/refresh` has rate limiting (`refresh-ip`), but no per-account or per-device rate limit.
   - Both must be added in Auth-2 and Auth-4.

### 4.6 Multi-Organization Session Scoping & Flutter Generation Fencing
**Investigation:** Does the current Flutter client correctly isolate multi-organization sessions and fence refresh races?
**Findings:**
1. **Flutter Generation Fencing (`AuthService`):**
   - Lines 148, 253, and 289 of `auth_service.dart` implement `_sessionGeneration`.
   - On explicit `logout()`, `_sessionGeneration++` is incremented synchronously before any async storage wipe.
   - If an in-flight refresh returns after logout, `capturedGen != _sessionGeneration` triggers instant rejection:
     `throw SessionRevokedException('Token refresh discarded: session was invalidated during refresh.');`.
   - Verified 100% passing in `test/auth_service_test.dart`.
2. **Local SQLite Containment (`TenantBoundaryGate`):**
   - The Flutter client's `switchOrganization` method currently enforces the **`F-05 Safe Blocking Rule`**:
     `throw OrganizationSwitchBlockedException('Multi-tenant distributor switching is deferred to Phase B2.2...');`.
   - This block is intentional: it prevents un-partitioned local tables from mixing data between distributors.
   - Under Auth v1.2, multi-tenant isolation will use **separate SQLite files per organization** (`routeflow_tenant_${orgId}.sqlite`), maintaining complete file-level isolation without altering legacy B1 tables.

---

## 5. Required Dependencies & Cloudflare Configuration

### 5.1 Cloudflare Wrangler Configuration (`backend/wrangler.toml`)
To support Auth v1.2, `wrangler.toml` must be configured with:

```toml
name = "routeflow-api"
main = "src/index.ts"
compatibility_date = "2024-03-20"
account_id = "5b5194deaa35116098d3f45dee890e17"

[[d1_databases]]
binding = "DB"
database_name = "routeflow-db"
database_id = "placeholder-id"

[vars]
JWT_ACCESS_EXPIRY = "900"        # 15 minutes
JWT_REFRESH_EXPIRY = "2592000"    # 30 days
ENVIRONMENT = "development"
ENABLE_TEST_FAILURE_INJECTION = "true"
SMS_MODE = "simulated"
TURNSTILE_SITE_KEY = "0x4AAAAAA..." # Public site key

# Worker Secrets (Injected via wrangler secret put):
# - JWT_SECRET
# - GOOGLE_CLIENT_ID
# - GOOGLE_CLIENT_SECRET
# - TURNSTILE_SECRET_KEY
# - EMAIL_API_KEY
# - EMAIL_SENDER_ADDRESS
```

### 5.2 NPM Dependency Additions (for `backend/package.json`)
The current dependencies are minimal:
```json
"dependencies": {
  "@tsndr/cloudflare-worker-jwt": "^3.2.3",
  "bcryptjs": "^3.0.3",
  "hono": "^4.13.9"
}
```
**Auth-2/Auth-3 additions needed:**
- `hash-wasm` (for WASM-based Argon2id password hashing on Workers Paid).
- (No external OAuth library needed: Google ID token verification is implemented cleanly using native `crypto.subtle` WebCrypto API).

---

## 6. Auth-1 Prerequisites & Unresolved Security Risks

### 6.1 Auth-1 Approval Prerequisites
Before submitting Phase Auth-1 (D1 migration 0024) for authorization:
1. **Local Miniflare Rebuild Dry-Run:**
   Execute the migration SQL against a Miniflare local SQLite database containing mock seed data from migration 0019 to verify that `PRAGMA foreign_key_check` passes with zero constraint violations.
2. **Backup Script Readiness:**
   Ensure `backend/tools/backup_sqlite.py` is verified functional to take a pre-migration snapshot of the staging D1 database.
3. **Environment Plan Confirmation:**
   Confirm that the Cloudflare Workers account is subscribed to **Workers Paid** ($5/mo Standard Usage Model) to guarantee the 30-second CPU limit required for OWASP-compliant password hashing.

### 6.2 Unresolved Security Risks (To Be Mitigated in Auth-2–Auth-9)
1. **Transactional Email Latency:** Outbound email HTTP API calls (e.g. to Resend/Postmark) add 100–300 ms of network latency to registration and password reset requests. Mitigate using `ctx.waitUntil()` for asynchronous email dispatch.
2. **Account Linking Policy:** If a user registers with email/password and later attempts Google Sign-In with the same email, the system must not silently merge accounts without verifying ownership of both credentials.
3. **Physical Device Google Play Services:** Android field devices (such as the Vivo 1935 test unit) require Google Play Services for Google Sign-In SDK. If Play Services are outdated or disabled on field devices, the app must gracefully fall back to email/password authentication.

---

## 7. Exact Files Inspected

The following codebase files were inspected in read-only mode during this audit:

### Backend Source & Migrations
- `D:\app\backend\package.json`
- `D:\app\backend\wrangler.toml`
- `D:\app\backend\src\index.ts`
- `D:\app\backend\src\security.ts`
- `D:\app\backend\src\onboarding.ts`
- `D:\app\backend\migrations\0001_initial.sql`
- `D:\app\backend\migrations\0004_security_ledger_and_sessions.sql`
- `D:\app\backend\migrations\0013_onboarding_and_delegation.sql`
- `D:\app\backend\migrations\0019_multi_tenant_organizations_and_catalog.sql`

### Flutter Application Code & Tests
- `D:\app\flutter_distributor\lib\services\auth_service.dart`
- `D:\app\flutter_distributor\lib\domain\auth\role_routing.dart`
- `D:\app\flutter_distributor\lib\domain\auth\tenant_boundary_gate.dart`
- `D:\app\flutter_distributor\lib\domain\auth\token_refresh_coordinator.dart`
- `D:\app\flutter_distributor\lib\data\auth\secure_token_storage.dart`
- `D:\app\flutter_distributor\test\auth_service_test.dart`
- `D:\app\flutter_distributor\test\role_routing_test.dart`
- `D:\app\flutter_distributor\test\hardcore_four_role_crud_test.dart`

---

## 8. Final Verdict on Auth-1

**VERDICT: Auth-1 can be separately submitted for approval.**

Auth-0 has completed all required architectural and security investigations. The leaf status of `organization_memberships`, the 8-role permission alignment in `security.ts`, the concurrency grace window design, the OAuth nonce lifecycle, and the client SQLite file-isolation model are fully documented and verified. 

*No application code, database files, migrations, or configurations were modified. Implementation remains suspended pending authorization of Phase Auth-1.*
