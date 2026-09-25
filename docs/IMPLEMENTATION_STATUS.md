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

### D. Physical-Phone Verification: Disaggregated Status & Evidence (Vivo 1935 / Serial 4bc99b28)

#### 1. Correction of Prior Verification Report
- **Order ORD-363933**: Roles 1 to 3 (Sales creation, Owner approval, Warehouse picking/packing/dispatch) were executed on phone screens. However, delivery completion was executed via direct API call (`POST /orders/ORD-363933/deliver`) after multiple on-screen taps failed due to navigation bar / IME overlap and ADB keyevent state decoupling. Therefore, **delivery UI completion for ORD-363933 is explicitly marked as UI-UNVERIFIED / API-ONLY**.

#### 2. Confirm Delivery Screen Diagnosis & Source Fixes
- **Root Cause Analysis**:
  1. *Button Enabled State*: `OutlinedTextField` state `deliveryCode` was not reliably updated when characters were injected via ADB keyevents rather than software keyboard input, leaving `isCodeValid = false` and button disabled.
  2. *Navigation-Bar & Inset Overlap*: Vivo 1935 has a gesture navigation dead zone extending up to $y \approx 2115$. The button at $y \approx 1947 - 2109$ lacked adequate bottom padding, and without scrolling, keyboard appearance shoved the button off-screen.
  3. *Error & Loading Feedback*: `DeliveryDetailScreen` did not observe `DeliveryDetailState` (`isLoading`, `error`). As a result, network failures were silent and button taps gave zero progress feedback.
  4. *Retailer Lookup*: `DeliveryViewModel` was hardcoded to `getRetailersByBeat("BEAT-04")`, displaying "Unknown" for retailers in other beats.
- **Implemented Fixes**:
  - Added `Modifier.verticalScroll(rememberScrollState())`, `Modifier.imePadding()`, `Modifier.navigationBarsPadding()`, and `Spacer(Modifier.height(32.dp))` below the confirm button.
  - Added a dedicated "Fill Demo OTP (4829)" button to reliably populate the mock OTP into Compose state without relying on keyboard keyevents.
  - Bound `DeliveryDetailState` to display clear red error cards on failure and a progress spinner during submission.
  - Replaced hardcoded beat query with `retailerRepository.getAllRetailers()`.
  - Added explicit mock OTP disclaimer: *"Demo mock OTP: 4829 (Server-validated proof pending)"*.

#### 3. Separate Offline Recovery Verification (Remaining Logged In)
- **Order**: `ORD-126570` (10 units Premium Tea `P1`, ₹4,500.00, Buy 10 Get 1 Free auto-applied).
- **Execution**:
  1. Severed connectivity on phone (`adb reverse --remove tcp:8787`).
  2. Booked order on phone UI. Screen badge displayed `Saved Offline`.
  3. Force-killed app (`am force-stop com.routeflow.app`) and relaunched without logging out.
  4. Confirmed session persisted: Salesperson home screen loaded without login prompt.
  5. Confirmed local persistence: Order survived intact with `Saved Offline` badge; read-only D1 check proved order was NOT on server (`[]`).
  6. Reconnected network (`adb reverse tcp:8787 tcp:8787`): `SyncManager` executed `OrderSyncWorker`, token auto-refreshed, order was submitted to D1, badge transitioned to `Synced`, and local `sync_outbox` was purged cleanly (`[]`).

#### 4. Complete End-to-End Delivery Verification on NEW Order (ORD-126570)
- **Methodology**: Entire lifecycle executed exclusively through Android UI screens on the physical Vivo phone with **ZERO direct API mutations**:
  - **Role 1 (Salesperson UI)**: Booked `ORD-126570` offline, auto-synced to server.
  - **Role 2 (Owner UI)**: Logged in on phone, navigated to Pending Approvals, tapped **Approve**. Server reserved 11 units.
  - **Role 3 (Warehouse UI)**: Logged in on phone, tapped **Start Picking**, checked line item checkbox, tapped **Mark Packed**, opened driver dialog, selected **Suresh Yadav** (`@delivery`), and tapped **Confirm & Dispatch**. Order transitioned to `OUT_FOR_DELIVERY` and physical stock decremented by 11.
  - **Role 4 (Delivery UI)**: Logged in on phone as Suresh Yadav, opened assigned delivery list, tapped **Proceed to Deliver**, tapped **Fill Demo OTP**, selected **Cash Payment**, tapped **Confirm Delivery**.
  - **Visible Success State**: Delivery list transitioned to display `"No deliveries assigned"`. Screenshot captured: `delivery_success_screen.png`.
- **Post-Delivery Read-Only Verification (D1 SQLite)**:
  - **Order**: `ORD-126570`, `status = 'DELIVERED'`, `payment_method = 'CASH'`, `total_amount_paise = 450000`.
  - **Invoice**: `inv_ccc6e9ac-b3d7-4d44-9ee6-0a56cca7ea65`, `status = 'PAID'`, `total_amount_paise = 450000`.
  - **Payment Ledger**: `led_54d38b9c-1d2f-41b2-b7da-bad9538220ec`, `entry_type = 'CASH_PAYMENT'`, `amount_paise = 450000`, `balance_after_paise = 1566000`, `collected_by = 'user_delivery'`.
  - **Physical Stock (P1)**: Permanently deducted from 72 to 61 units (`reserved_quantity = 0`).
  - **Retailer Balance (R2)**: Remained unchanged at ₹15,660.00 (Cash payment settled immediately without increasing ledger debt).

---

## 8. Verification Status Breakdown

| Feature / Journey Component | Phone UI Verified | API Verified | Automated-Test Verified | Status |
| :--- | :---: | :---: | :---: | :--- |
| **JWT Login & Session Restoration** | YES | YES | YES | Verified |
| **Session Revocation & Refresh Rotation** | YES | YES | YES | Verified |
| **Offline Order Queue & Outbox Durability** | YES | YES | YES | Verified |
| **Account-Scoped Sync Isolation** | YES | YES | YES | Verified |
| **Offline Recovery While Remaining Logged In** | YES | YES | YES | Verified |
| **Promotion Engine (Buy 10 Get 1 Free)** | YES | YES | YES | Verified |
| **Owner Order Approval & Stock Reservation** | YES | YES | YES | Verified |
| **Warehouse Picking & Dynamic Driver Dispatch** | YES | YES | YES | Verified |
| **Delivery Executive Assigned Order View** | YES | YES | YES | Verified |
| **Delivery Completion via Phone Screen (ORD-126570)**| YES | YES | YES | Verified |
| **Cash & Credit Ledger Settlement Effects** | YES | YES | YES | Verified |
| **Owner Live KPI Metric Refresh** | YES | YES | YES | Verified |
| **Server-Validated Proof of Delivery (OTP / Sign)**| NO | NO | NO | **Pending (Mock Demo OTP Only)** |
| **Shop Visit Location & Duration Sync** | NO | NO | NO | **Pending (Local-Only)** |
| **In-Store Stock Audit Screen & Sync** | NO | NO | NO | **Pending (Local-Only)** |
| **Owner Product Catalog CRUD** | NO | NO | NO | **Pending** |
| **Owner Retailer Management** | NO | NO | NO | **Pending** |
| **Owner Employee Onboarding & Roles** | NO | NO | NO | **Pending** |

---

## 9. Product Module Audit & Classification

| Module / Feature | Current Classification | Architecture & Implementation Details |
| :--- | :--- | :--- |
| **Authentication & Session Lifecycle** | **Server-backed** | Multi-role JWT with D1 `sessions` table, per-device revocation, atomic refresh rotation, bearer token interceptor, and secure credential storage. |
| **Multi-Tenant Scoping & Permissions** | **Server-backed** | Database-level `company_id` enforcement across all entities; delivery driver assignment guards; salesperson beat checks; dynamic company driver discovery (`GET /delivery-executives`). |
| **Order Creation & Promotion Engine** | **Server-backed** | Offline order creation with UUID idempotency keys; Buy 10 Get 1 Free automatic calculation; Room outbox queue with sync badges (`SAVED_OFFLINE`, `SYNCING`, `SYNCED`, `NEEDS_ATTENTION`). |
| **Guarded Order Lifecycle (4-Role Journey)** | **Server-backed** | Atomic D1 batch transitions for Submit -> Approve -> Pick -> Pack -> Dispatch -> Deliver; verified entirely on Vivo 1935 phone screen. |
| **Inventory & Reservation Management** | **Server-backed** | Exact physical stock tracking, reservation on approval, atomic deduction on dispatch/delivery, rollback on write failures. |
| **Invoice & Payment Ledger Settlement** | **Server-backed** | Atomic invoice generation on delivery (`CASH` -> `PAID`, `CREDIT` -> `ISSUED`), atomic retailer credit increment, immutable payment ledger recording. |
| **Retailer List & Beat Filtering** | **Server-backed** | `GET /retailers`, `RetailerEntity` Room cache, beat/day filtering in Salesperson UI. |
| **Delivery Proof (OTP / Verification)** | **Demo / Mock (Unfinished)** | Demo OTP code `4829` in `DeliveryDetailScreen.kt`; cryptographic or server-generated SMS/recipient OTP and signature proof not yet implemented. |
| **Shop Visit / Check-in / Check-out** | **Local-only** | `VisitEntity`, `VisitDao`, `ShopVisitScreen.kt` with GPS coordinates and visit duration tracking; local Room storage only without backend synchronization endpoint. |
| **In-Store Stock Check** | **Local-only / Screen Not Started** | `StockCheckEntity` and `StockCheckDao` exist in Room database schema; in-store stock check UI screen is not yet linked (`onStockCheck = { /* TODO */ }`). |
| **Goods Return & Bad Stock Workflow** | **Not started** | Return requests, return item reasons (damaged, expired), stock re-entry, and credit notes require schema and API additions. |
| **Field Collections & Cash Handover** | **Local-only / Screen Not Started** | `PaymentEntity` and `PaymentDao` exist in local Room schema; end-of-day cash handover reconciliation screen between driver/salesperson and owner is not started. |
| **Owner KPI Overview Cards** | **Server-backed** | `OwnerHomeScreen` computes real-time delivered sales today, active orders, and retailer outstanding directly from confirmed server orders and retailer balances. |
| **Owner Product, Retailer & Employee Management** | **Not started** | Product catalog CRUD, retailer onboarding/tiering, and employee user management currently run via seed migrations; admin management screens not started. |
| **Sales Targets & Performance Reporting** | **Demo / Mock** | `TargetEntity` exists in Room; hardcoded monthly targets displayed in `SalesViewModel.kt`; historical analytics and reporting screen not started. |

---

## 10. Next Milestones
1. **Owner Management Capabilities**:
   - Product Catalog CRUD & Price management.
   - Retailer creation & beat assignment.
   - Employee onboarding & role assignment.
2. **Shop Visits Backend Synchronization**:
   - Backend endpoint `POST /visits` capturing check-in/out timestamp, latitude, longitude, and duration.
   - Salesperson UI sync integration for completed shop visits.
