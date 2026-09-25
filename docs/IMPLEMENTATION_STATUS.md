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

### D. Physical-Phone Four-Role Journey Verification (Vivo 1935 / Serial 4bc99b28)
- **Host & Environment Setup**:
  - Persistent ADB daemon (`adb -P 5037 nodaemon server`) on port 5037.
  - Active ADB reverse tunnel (`adb reverse tcp:8787 tcp:8787`).
  - Local Wrangler development backend running on `http://127.0.0.1:8787`.
  - Android debug build with token auto-refresh mutex, account-scoped `SyncManager`, and `OrderSyncBadge` visual indicators.

- **Full Four-Role Journey (Order ORD-363933)**:
  1. **Role 1: Salesperson (Offline Durability, Promo Engine & Auto-Sync)**:
     - Logged in as `sales` (`user_sales`, `comp_1`).
     - Severed API tunnel (`adb reverse --remove tcp:8787`).
     - Booked order `ORD-363933` for Gupta Provisions (`R2`): 10 units of Premium Tea (`P1`, ₹450/unit) with Buy 10 Get 1 Free promo automatically applied (`quantity = 10, freeQuantity = 1`, total ₹4,500.00).
     - UI badge displayed **Saved Offline** (`SAVED_OFFLINE`).
     - App process killed (`am force-stop`) and restarted; pending order survived intact in Room `sync_outbox`.
     - Switched accounts to Owner (`user_owner`); queried D1 database to prove Account B cannot see or upload Account A's pending order.
     - Restored reverse tunnel (`adb reverse tcp:8787 tcp:8787`) and logged back in as Salesperson.
     - `SyncManager` scheduled `OrderSyncWorker` with `KEEP` policy; order synced to backend immediately and badge transitioned to **Synced** (`SYNCED`).
  2. **Role 2: Owner (Real Server Approval & Reservation)**:
     - Logged in as `owner` (`user_owner`, `comp_1`).
     - Order `ORD-363933` appeared under Pending Orders with status `SUBMITTED`.
     - Tapped **Approve**; backend executed guarded transition to `APPROVED` and atomically reserved 11 units of `P1` (10 paid + 1 promo).
  3. **Role 3: Warehouse (Server Picking & Dynamic Delivery Driver Selection)**:
     - Logged in as `warehouse` (`user_warehouse`, `comp_1`).
     - Picked `ORD-363933` from list and tapped **Start Picking**; invoked server API `POST /orders/ORD-363933/start-picking`.
     - Checked off line item and tapped **Mark as Packed** (`PACKED`).
     - Tapped **Dispatch Order**; opened dynamic driver selection dialog populated via `GET /delivery-executives`.
     - Selected active company driver **Suresh Yadav** (`user_delivery`) and dispatched. Order transitioned to `OUT_FOR_DELIVERY`.
  4. **Role 4: Delivery Executive (Verification Code & Credit Settlement)**:
     - Logged in as `delivery` (`user_delivery`, `comp_1`).
     - Verified assigned deliveries list contained `ORD-363933` (unassigned deliveries properly filtered by server query).
     - Entered verification code `4829`, selected payment method `CREDIT`, and tapped **Confirm Delivery**.
     - Backend atomically transitioned order to `DELIVERED`, issued invoice, deducted stock, and credited retailer balance.
  5. **Live D1 SQLite Database Verification**:
     - **Order Status**: `DELIVERED`, `payment_method = 'CREDIT'`.
     - **Invoice Issued**: `inv_9f87dc79-a555-4c6d-93be-dc2e3d1fed4d` (Status `ISSUED`, total 4,50,000 paise / ₹4,500.00).
     - **Inventory**: `P1` physical stock decremented by 11 units from 84 to 73 (`reserved_quantity = 0`).
     - **Retailer Balance**: `R2` outstanding balance atomically incremented by ₹4,500.00 from ₹10,800.00 to ₹15,300.00 (`1530000` paise).
     - **Payment Ledger Entry**: `led_9c4527f7-c16d-44c6-888a-8d3e6957f56f` (`CREDIT_INCREASE`, amount `450000`, `balance_after_paise = 1530000`).
  6. **Owner Dashboard Live Metric Verification**:
     - Logged back in as Owner on the physical Vivo phone.
     - Live KPI cards on `OwnerHomeScreen` immediately reflected confirmed delivery:
       - **Delivered Sales Today**: Increased from ₹6,600.00 to **₹11,100.00** (+₹4,500.00).
       - **Retailer Outstanding**: Increased from ₹66,200.00 to **₹70,700.00** (+₹4,500.00).

---

## 8. Product Module Audit & Classification

The table below provides an exhaustive audit of all RouteFlow product modules, categorizing each into **Server-backed**, **Local-only**, **Demo/mock**, or **Not started**:

| Module / Feature | Current Classification | Architecture & Implementation Details |
| :--- | :--- | :--- |
| **Authentication & Session Lifecycle** | **Server-backed** | Multi-role JWT with D1 `sessions` table, per-device revocation, atomic refresh rotation, bearer token interceptor, and secure credential storage. |
| **Multi-Tenant Scoping & Permissions** | **Server-backed** | Database-level `company_id` enforcement across all entities; delivery driver assignment guards; salesperson beat checks; dynamic company driver discovery (`GET /delivery-executives`). |
| **Order Creation & Promotion Engine** | **Server-backed** | Offline order creation with UUID idempotency keys; Buy 10 Get 1 Free automatic calculation; Room outbox queue with sync badges (`SAVED_OFFLINE`, `SYNCING`, `SYNCED`, `NEEDS_ATTENTION`). |
| **Guarded Order Lifecycle (4-Role Journey)** | **Server-backed** | Atomic D1 batch transitions for Submit -> Approve -> Pick -> Pack -> Dispatch -> Deliver; hardware verified on Vivo 1935. |
| **Inventory & Reservation Management** | **Server-backed** | Exact physical stock tracking, reservation on approval, atomic deduction on dispatch/delivery, rollback on write failures. |
| **Invoice & Payment Ledger Settlement** | **Server-backed** | Atomic invoice generation on delivery (`CASH` -> `PAID`, `CREDIT` -> `ISSUED`), atomic retailer credit increment, immutable payment ledger recording. |
| **Retailer List & Beat Filtering** | **Server-backed** | `GET /retailers`, `RetailerEntity` Room cache, beat/day filtering in Salesperson UI. |
| **Shop Visit / Check-in / Check-out** | **Local-only** | `VisitEntity`, `VisitDao`, `ShopVisitScreen.kt` with GPS coordinates and visit duration tracking; local Room storage only without backend synchronization endpoint. |
| **In-Store Stock Check** | **Local-only / Screen Not Started** | `StockCheckEntity` and `StockCheckDao` exist in Room database schema; in-store stock check UI screen is not yet linked (`onStockCheck = { /* TODO */ }`). |
| **Delivery Proof (Verification Code)** | **Demo / Mock** | Pre-configured OTP code verification (`4829`) in `DeliveryDetailScreen.kt`; photo capture and recipient signature capture not yet started. |
| **Goods Return & Bad Stock Workflow** | **Not started** | Return requests, return item reasons (damaged, expired), stock re-entry, and credit notes require schema and API additions. |
| **Field Collections & Cash Handover** | **Local-only / Screen Not Started** | `PaymentEntity` and `PaymentDao` exist in local Room schema; end-of-day cash handover reconciliation screen between driver/salesperson and owner is not started. |
| **Owner KPI Overview Cards** | **Server-backed** | `OwnerHomeScreen` computes real-time delivered sales today, active orders, and retailer outstanding directly from confirmed server orders and retailer balances. |
| **Owner Product & Employee Management** | **Not started** | Product catalog CRUD, price tier management, and employee onboarding currently run via seed migrations; admin management screens not started. |
| **Sales Targets & Performance Reporting** | **Demo / Mock** | `TargetEntity` exists in Room; hardcoded monthly targets displayed in `SalesViewModel.kt`; historical analytics and reporting screen not started. |

---

## 9. Next Milestones & Readiness
- **Stage 2 Status**: **Hardened & Verified**. The four-role operational backbone is fully verified on real Android hardware and backed by atomic Cloudflare D1 transactions.
- **Stage 3 Roadmap**:
  1. Backend synchronization for Shop Visits (`POST /visits`) and In-Store Stock Audits (`POST /stock-checks`).
  2. Proof of Delivery enhancements: photo capture and electronic signature upload.
  3. Cash Handover and Field Collection reconciliation endpoints and Owner settlement UI.
  4. Returns & credit note lifecycle.
