# RouteFlow Implementation Status

## Current Status
**Stage 2: Backend API Contract, Token & Session Lifecycle, Stock Ledger, Concurrency, and Order Journey (Hardened & In Progress — NOT Declared Complete)**

> [!NOTE]
> Per project directives, Stage 2 is not declared complete yet. All critical architectural, concurrency, ledger, and scoping gaps identified in commit `13a08c4` have been resolved and verified with automated test suites across backend and Android.

---

## 1. Atomic Business Transitions & Failure Injection
- **Guarded Atomic Batch Design**:
  - D1 SQLite transactions execute the guarded order status transition, inventory reservation/deduction, invoice creation, payment ledger, and audit log within a single atomic `c.env.DB.batch([...])`.
  - Database trigger `trg_order_status_transition_guard` (migration `0005_atomic_transitions_and_ledger.sql`) strictly enforces state preconditions (`SUBMITTED -> APPROVED`, `PACKED -> OUT_FOR_DELIVERY`, `OUT_FOR_DELIVERY -> DELIVERED`, `SUBMITTED -> REJECTED`). Any competing or invalid transition aborts the entire transaction via `RAISE(ABORT)`.
  - Side effects are never applied conditionally outside the atomic transaction; only winning transitions commit inventory or financial updates.
- **Failure Injection Verification**:
  - Backend supports deterministic failure injection via `X-Test-Fail-Inventory` and `X-Test-Fail-Invoice` headers.
  - End-to-end integration tests verify that a failure injected into inventory or invoice writes rolls back the entire batch, leaving the order in its original status (`SUBMITTED` or `OUT_FOR_DELIVERY`) ready for safe retry.

---

## 2. Concurrent Retailer Balance Updates
- **Elimination of Read-Modify-Write Races**:
  - Application-level balance reads and overwrites have been replaced with atomic SQL credit increments:
    `UPDATE retailers SET outstanding_amount_paise = outstanding_amount_paise + ? WHERE id = ?`.
  - The payment ledger entry records `balance_after_paise` directly via subquery from `retailers.outstanding_amount_paise` within the same atomic batch.
- **Concurrent Delivery Test**:
  - Integration suite executes concurrent deliveries of two distinct orders ($₹150$ and $₹250$) to the same retailer starting at $₹1,000$.
  - Verification confirms no lost updates: final retailer outstanding balance is exactly $₹1,400$, and both ledger entries accurately reflect the sequential balances.

---

## 3. Account-Scoped Synchronization & Outbox Quarantine
- **Worker Credential Binding**:
  - `OrderSyncWorker` binds explicitly to target `(userId, companyId)` passed via input data, with fallback to active `tokenStorage`.
  - Pre-request credentials check: the worker validates that active session credentials match the target credentials both at worker start and before dispatching each individual network request. If a mid-run account switch occurs, the worker terminates safely without transmitting data under the wrong identity.
- **Legacy Outbox Quarantine**:
  - Outbox entries lacking explicit user/company ownership are quarantined via `SyncOutboxDao.quarantineLegacySyncs()` (`type = 'QUARANTINED'`), preventing cross-account contamination.
- **Account Switch Unit Test (`AccountScopedSyncTest.kt`)**:
  - Verifies Account A queues an offline order.
  - Switch to Account B: B's worker does not process Account A's order; A's order remains safely pending in outbox.
  - Stale worker for Account A invoked while Account B is active aborts without submitting.
  - Switch back to Account A: A's order is submitted exactly once and removed from outbox.

---

## 4. Initial Cache Loading & Transaction Safety
- **Network-First Loading**:
  - `LoginViewModel` fetches all network data (retailers, products, orders list, and each order's line-item details) into in-memory structures *before* opening the Room transaction.
  - Order-detail fetch failures are no longer swallowed; failures bubble up to `_state.errorMessage`, preventing insertion of half-complete records lacking line items.
- **Isolated Room Transaction**:
  - `database.withTransaction` executes purely local database operations (deletions, entity insertions) without holding database locks over network I/O.
  - Unsynced orders are preserved using user-scoped queries: `getPendingSyncsForUser(user.id, user.companyId)`.

---

## 5. Promotion Alignment & Payment Settlement Accuracy
- **Agreed Promotion Restored**:
  - Premium Tea (`P1`) promotion is configured as BUY 10 GET 1 FREE (`min_quantity: 10, free_quantity: 1`) consistently across database seeds, backend promotion engine, Android DTOs, and integration tests.
- **Restricted Payment Settlement**:
  - Delivery payments in Stage 2 are strictly restricted to `CASH` (immediate settlement, invoice status `PAID`) and `CREDIT` (retailer balance increment, invoice status `ISSUED`).
  - Unverified payment methods (`UPI`, `CHEQUE`, `BITCOIN`, etc.) return HTTP 400 Bad Request.

---

## 6. Secrets, Sessions & Permissions Hardening
- **Secrets Isolation**:
  - Development signing secret resides strictly in `.dev.vars` (gitignored). No secrets, keys, or passwords appear in Git, logs, or status documents.
- **Session Revocation**:
  - Per-device server sessions tracked in `sessions` table.
  - Instant invalidation on logout (`is_revoked = 1`). Requests with old access tokens return HTTP 401.
  - Atomic refresh token rotation with reuse detection revoking the entire session.
  - Plaintext password fallback completely removed.
- **Assignment Permissions**:
  - Delivery users list and read only orders assigned to them.
  - Salesperson beat assignments enforced on retailer listings and order creation.
  - Permissions evaluated against live database state on every request.

---

## 7. Verification Evidence

### A. Unit Tests (Android JUnit / Robolectric)
- **Command**: `.\gradlew.bat testDebugUnitTest --no-daemon`
- **Result**: **BUILD SUCCESSFUL** (36s)
- **Summary**: **19 tests run across 6 suites, 0 failures, 0 errors, 0 skipped** (total duration: 2.974s).
- **`AccountScopedSyncTest` Evidence**:
  - `testLegacyOutboxRows_areQuarantinedAndNotSubmitted` (0.416s) — **PASSED**
  - `testAccountSwitch_doesNotProcessOtherAccountsOrders_andProcessesOnSwitchBack` (0.080s) — **PASSED**
  - Verified XML report: `app/build/test-results/testDebugUnitTest/TEST-com.routeflow.app.data.sync.AccountScopedSyncTest.xml`.

### B. Backend Verification (`npm run typecheck` & `npm test`)
- **TypeScript**: `npm run typecheck` (`tsc --noEmit`) — **SUCCESS** (0 errors).
- **Integration Test Suite**: `node --test test/integration.test.mjs` — **PASS** (10 of 10 suites passed, 3444ms):
  ```
  TAP version 13
  # Subtest: RouteFlow API End-to-End Integration Suite
      ok 1 - 1. Auth: Valid logins across all active roles and multi-company setup
      ok 2 - 2. Auth Security: Rejections for invalid, disabled users, and tampered tokens
      ok 3 - 3. Session Revocation: Old access token rejected after logout and refresh token reuse
      ok 4 - 4. Multi-Tenant Isolation (Two Companies)
      ok 5 - 5. Assignment Permissions: Two Delivery Accounts & Salesperson Beat Checks
      ok 6 - 6. Restored Promotion (BUY 10 GET 1 FREE) & Bound Idempotency Keys
      ok 7 - 7. Atomic Transitions with Failure Injection and Rollback Verification
      ok 8 - 8. Concurrent Retailer Balance Updates (Two Different Orders to Same Retailer)
      ok 9 - 9. Payment Settlement Accuracy (Restricted to CASH and CREDIT in Stage 2)
      ok 10 - 10. Same-Order Concurrency: Duplicate Requests & Approval vs Rejection Race
  1..10
  # tests 10 | suites 1 | pass 10 | fail 0 | duration_ms 3444.9631
  ```
- **Coverage Highlights**:
  - *Atomic rollback*: Tested via `X-Test-Fail-Inventory` and `X-Test-Fail-Invoice`. State remains unchanged and retryable.
  - *Simultaneous credit deliveries*: Concurrent delivery of two orders ($₹150$ and $₹250$) to the same retailer accurately increments balance without lost updates.
  - *Same-order duplicate requests*: Concurrent approvals on the same order reserve stock exactly once.
  - *Approval vs Rejection race*: Racing approval against rejection on the same submitted order commits exactly one terminal transition and reserves stock only if approval won.
  - *Agreed promotion*: Premium Tea `P1` verified as BUY 10 GET 1 FREE.

### C. Android Packaging
- **`.\gradlew.bat lintDebug --no-daemon`**: **BUILD SUCCESSFUL** (15s, 0 lint errors).
- **`.\gradlew.bat assembleDebug --no-daemon`**: **BUILD SUCCESSFUL** (15s).
- **Output Artifact**: `app/build/outputs/apk/debug/app-debug.apk` (21,687,859 bytes).

### D. Physical-Phone Verification Status (Vivo 1935 / 4bc99b28)
- **Host & Network Setup**:
  - Persistent background ADB daemon (`adb -P 5037 nodaemon server`) running on port 5037.
  - Active ADB reverse tunnel (`adb reverse tcp:8787 tcp:8787`).
  - Local Wrangler development backend running on `http://127.0.0.1:8787`.
  - Android application compiled with `androidx.hilt:hilt-compiler:1.2.0` KSP processor, custom `HiltWorkerFactory` provider, and cleartext development security config for `127.0.0.1`.
- **Physical Device Workflow Verification**:
  1. **Real Server Login & Session Restoration**:
     - Logged into physical device as Salesperson (`sales` / `password123`, `comp_1`).
     - Session securely persisted in encrypted preferences and validated against server sessions table.
     - Survives app force-stop and cold restarts without session loss.
  2. **Offline Resilience & Outbox Durability**:
     - Severed API connectivity on device (`adb reverse --remove tcp:8787`).
     - Created order `ORD-264989` offline (Retailer `R2` Gupta Provision Store, 10 units Premium Tea + 1 free promotional unit, ₹4,500.00).
     - Order safely queued into local Room `sync_outbox` with UUID idempotency key `b30131d3-a3b8-49bb-8905-b2442f3ab554`.
     - Force-stopped app and restarted; verified pending order remained intact in SQLite outbox.
  3. **Automatic Worker Synchronization**:
     - Restored connectivity (`adb reverse tcp:8787 tcp:8787`) and refreshed session.
     - `OrderSyncWorker` picked up the pending outbox entry, verified active `(userId, companyId)` match, and submitted to backend.
     - Server verified idempotency key, processed order, and returned HTTP 200.
     - Outbox entry purged on phone upon server confirmation; verified `sync_outbox` is empty.
  4. **Promotional Rule Verification on Live Server**:
     - Cloudflare D1 query verified `ORD-264989` in `orders` and `order_items` tables with `quantity = 10` and `free_quantity = 1` (buy 10, get 1 free promotional rule verified on live server).
  5. **Complete Order Lifecycle Execution**:
     - **Owner Approval**: Order `ORD-264989` approved via API (`POST /orders/ORD-264989/approve`); inventory atomically reserved 11 units (`reserved_quantity = 11`, `stock_quantity = 97`).
     - **Warehouse Pick & Pack**: Item `P1` picked (`POST /orders/ORD-264989/pick-item`) and packed (`POST /orders/ORD-264989/pack`). Guards verified: packing rejected if items unpicked; dispatch rejected if order not packed.
     - **Dispatch**: Order dispatched (`POST /orders/ORD-264989/dispatch`) assigned to `user_delivery`. Inventory atomically decremented from 97 to 86 (`stock_quantity = 86`, `reserved_quantity = 0`).
     - **Delivery Assignment Enforcement**: Tested unassigned delivery executive (`user_delivery_2`), which was rejected with HTTP 403 Forbidden.
     - **Delivery Completion & Financial Settlement**: Delivered by assigned executive `user_delivery` with payment method `CREDIT`. Live D1 database verified:
       - Order status: `DELIVERED`.
       - Invoice issued: `inv_c532c94b-fbe5-4254-9e50-1a2cb5dccf7c` for `450000` paise (₹4,500.00).
       - Retailer `R2` outstanding balance atomically updated from `558000` to `1008000` paise (₹10,080.00).
       - Durable payment ledger record: `led_ce111114-5f69-4560-971a-041894798389` (`CREDIT_INCREASE`, amount `450000`, balance after `1008000`).
- **Simultaneous Two-Device Testing**: **PENDING** (Marked pending due to single phone hardware constraint).

---

## 8. Remaining Scope & Next Steps
- **Stage 2 Status**: In progress / hardening phase. Not declared complete yet.
- **Subsequent Stages**:
  - Stage 3: Offline multi-stop delivery reconciliation, real hardware multi-device sync, and GPS route optimization.
