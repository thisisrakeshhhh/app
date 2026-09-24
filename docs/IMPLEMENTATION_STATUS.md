# RouteFlow Implementation Status

## Current Stage
**Stage 2: Backend API Contract, Token & Session Lifecycle, Stock Ledger, Concurrency, and Order Journey (Hardened & Verified)**

---

## 1. Secrets & Credentials Isolation
- **Rotated Development JWT Secret**: The development signing secret is stored exclusively in `.dev.vars` (gitignored).
- **Session Revocation**: All prior development sessions and refresh tokens were invalidated in the D1 database.
- **Strict Secrecy**: No secrets, private keys, passwords, or token strings are committed to Git, logged, or recorded in status documents.
- **Seed Separation**: Development seed data is completely separated into `backend/seeds/dev_seeds.sql`. Production migrations (`0001_initial.sql`, `0002_seeds.sql`, `0003_order_lifecycle.sql`, `0004_security_ledger_and_sessions.sql`) contain only schema definitions, performance indices, and integrity triggers without any shared test credentials.
- **Reference Preservation**: Existing IDs (`comp_1`, `ret_1`, `prod_1`, `prod_2`) are preserved when expanding local seed data (`R1`–`R6`, `P1`–`P10`, `comp_2`, `ret_comp2_1`, `prod_comp2_1`).
- **No Plaintext Password Fallback**: Plaintext password comparison has been completely removed; passwords must verify against standard bcrypt hashes.

---

## 2. Session Management & Token Revocation
- **Per-Device Server Sessions**: The backend tracks active sessions in the `sessions` table (`id`, `user_id`, `company_id`, `device_id`, `refresh_token_hash`, `is_revoked`, `expires_at`).
- **Session-Bound Access Tokens**: Each JWT access token embeds a session ID (`sid`). On every protected request, `authMiddleware` validates that the session exists in the database and is not revoked.
- **Instant Logout Invalidation**: Logging out sets `is_revoked = 1` for the session in the database. Protected requests presenting the old access token are immediately rejected with HTTP 401.
- **Conditional & Atomic Refresh Rotation**: Refresh rotation uses conditional SQL (`UPDATE sessions SET refresh_token_hash = ?, ... WHERE id = ? AND refresh_token_hash = ? AND is_revoked = 0`), ensuring concurrent refresh calls cannot both succeed.
- **Reuse Detection Revocation**: Old refresh token hashes are archived in `revoked_refresh_tokens`. If a previously used refresh token is presented, the entire session is immediately revoked and all associated tokens return HTTP 401.
- **Live Database Permissions**: `authMiddleware` queries the user record directly from the database on every authenticated request, guaranteeing that permission or role changes are enforced immediately rather than relying on stale JWT claims.

---

## 3. Assignment Permissions & Multi-Tenant Isolation
- **Delivery Order Scoping**:
  - Delivery executives list only orders explicitly assigned to them (`delivery_employee_id = ?`).
  - Order details (`GET /orders/:id`) and delivery completion (`POST /orders/:id/deliver`) enforce that the requesting delivery executive matches `delivery_employee_id`, returning HTTP 403 Forbidden for unassigned drivers.
  - Tested with two delivery accounts (`user_delivery` and `user_delivery_2`): driver 2 cannot view, read, or fulfill driver 1's assigned order.
- **Salesperson Beat Assignment**:
  - Salespersons are assigned to specific beats via `user_beat_assignments`.
  - `GET /retailers` filters retailers by assigned beats for salespersons.
  - `POST /orders` validates that the salesperson is assigned to the retailer's beat before allowing order creation.
- **Multi-Tenant Isolation (Two Companies)**:
  - Tested with `comp_1` and `comp_2`. Retailer lists, product catalogs, and order endpoints strictly isolate company data. Cross-company order creation or viewing is rejected.

---

## 4. Same-Order Concurrency & Ledger Integrity
- **Atomic Preconditions on Transitions**:
  - `/orders/:id/approve`: Conditional transition (`UPDATE orders SET status = 'APPROVED' WHERE id = ? AND status = 'SUBMITTED'`). Stock reservation executes only if the transition is won (`meta.changes === 1`). Concurrent approval requests do not double-reserve stock.
  - `/orders/:id/dispatch`: Conditional transition (`UPDATE orders SET status = 'OUT_FOR_DELIVERY' WHERE id = ? AND status = 'PACKED'`). Inventory deduction executes exactly once.
  - `/orders/:id/deliver`: Conditional transition (`UPDATE orders SET status = 'DELIVERED' WHERE id = ? AND status = 'OUT_FOR_DELIVERY'`).
- **Durable Invoices and Payment Ledger**:
  - Delivery completion records durable entries in `invoices` and `payment_ledger`.
  - Allowed payment methods (`CASH`, `CREDIT`, `UPI`, `CHEQUE`) are enforced; unknown methods return HTTP 400.
  - `CREDIT` payments update retailer outstanding balances and create `CREDIT_INCREASE` ledger records; `CASH`, `UPI`, and `CHEQUE` payments record respective ledger entries with balance tracking.
- **Bound Idempotency Records**:
  - Idempotency keys are bound in `idempotency_records` to `(company_id, actor_id, operation, request_hash)`.
  - Re-submitting with conflicting payloads returns HTTP 409 Conflict.
- **Server-Calculated Promotions**:
  - Promotional free quantities are computed server-side from active `promotions` rules (e.g. product `P1` buy 2 get 1 free), overriding client inputs.
- **Bounded Integer Validation**:
  - Order quantities, unit prices, and total amounts are strictly validated as positive bounded integers (quantities $\le 100,000$; amounts $\le 1,000,000,000$ paise).

---

## 5. Android Cache Safety & Outbox Scoping
- **Safe Selective Order Deletion**:
  - In `LoginViewModel`, pending offline orders in `sync_outbox` are identified before cache refresh.
  - `OrderDao.clearOrdersExcept(preservedOrderIds)` preserves unsynced offline orders and their items during login cache synchronization.
- **Restoration of Order Items with Headers**:
  - When caching server orders in `LoginViewModel` and `NetworkOrderRepository.syncOrdersFromServer()`, full line items are fetched via `getOrderDetails()` and inserted alongside order headers.
- **Sync Failure Visibility**:
  - `LoginViewModel` does not swallow catalog synchronization failures silently; failures update `LoginState.errorMessage` with a recoverable error message.
- **Scoped Sync Outbox**:
  - `SyncOutboxEntity` includes `userId` and `companyId`, migrated in Room version 6 (`MIGRATION_5_6`).
  - `SyncOutboxDao` provides scoped query helpers `getPendingSyncsForUser` and `getPendingSyncsForCompany`.

---

## 6. Verification Results

### Backend Verification
1. **TypeScript Typecheck**:
   - `npm run typecheck` (`tsc --noEmit`): **SUCCESS** (0 errors).
2. **Database Migrations & Seeding**:
   - `npx wrangler d1 migrations apply routeflow-db --local`: **SUCCESS** (Migration `0004` applied).
   - `npm run seed:local`: **SUCCESS** (`dev_seeds.sql` applied with multi-tenant and multi-delivery data).
3. **Integration Test Suite**:
   - `npm test` (`node --test test/integration.test.mjs`): **PASS** (7 suites, 7 passed, 0 failed in 3.98s).
     - *Suite 1*: Valid logins across all active roles and multi-company setup.
     - *Suite 2*: Auth security: rejections for invalid, disabled users, and tampered tokens.
     - *Suite 3*: Session revocation: old access token rejected after logout and refresh reuse; atomic conditional refresh.
     - *Suite 4*: Multi-tenant isolation between `comp_1` and `comp_2`.
     - *Suite 5*: Assignment permissions: two delivery accounts scoping and salesperson beat checks.
     - *Suite 6*: Server validation, promotions calculation, bounded integers, and bound idempotency keys (409 on conflict).
     - *Suite 7*: Same-order concurrency and durable ledger integrity.

### Android Application Verification
1. **Compilation**:
   - `.\gradlew.bat compileDebugSources --no-daemon`: **BUILD SUCCESSFUL**.
2. **Unit Tests**:
   - `.\gradlew.bat testDebugUnitTest --no-daemon`: **BUILD SUCCESSFUL**.
3. **Lint**:
   - `.\gradlew.bat lintDebug --no-daemon`: **BUILD SUCCESSFUL**.
4. **Assembly**:
   - `.\gradlew.bat assembleDebug --no-daemon`: **BUILD SUCCESSFUL** (APK generated).

---

## 7. Operational Boundaries & Scope Notes
- **Pending Physical Multi-Device Tests**: While multi-delivery and multi-tenant flows are verified via automated API integration tests, simultaneous physical multi-device live sync remains subject to hardware availability.
- **Stage 3 Scope**: Physical disconnected Wi-Fi endurance, background WorkManager scheduled sync, and live GPS route optimization.
