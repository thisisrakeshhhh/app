# RouteFlow Product Acceptance Matrix

**Date**: September 25, 2026  
**Target Pilot**: Jaipur Wholesaler Pilot (Warehouse to Retailer FMCG Distribution)  
**Hardware Verification**: Vivo 1935 Physical Device (`4bc99b28`) & Cloudflare D1 Backend (`http://127.0.0.1:8787`)  

---

## 1. Executive Summary & Verification Standard

This acceptance matrix documents the live state of the codebase. In accordance with strict product acceptance standards, a feature is **not marked complete** merely because a database entity, API endpoint, translation key, or UI placeholder exists. Full completion requires:
1. Usable native Android Compose UI.
2. Verified navigation without stack corruption or blank states.
3. Durable API and local Room synchronization.
4. Active multi-tenant isolation (`company_id`) and role permission checks.
5. Offline durability and idempotency.
6. Bilingual English and Hindi wiring across the user interface.
7. Verification on the physical device.

---

## 2. Feature-by-Feature Acceptance Matrix

### A. Core Architecture & Multi-Tenancy

| Feature | Screen Exists? | Navigation Works? | API / DB Connected? | Permissions Enforced? | Offline Behavior? | EN/HI Wired? | Verified in App? | Remaining Work |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Multi-Tenant Isolation** | N/A (System) | Yes | Yes (D1 + Room) | Yes (`company_id` filter on all queries) | Account-scoped DB | Yes | Yes | Retain isolation on all newly added field endpoints. |
| **Token & Session Lifecycle** | Yes (`LoginScreen`) | Yes | Yes (`/auth/login`, `/auth/refresh`, `/auth/logout`) | Yes (DB session checks on every call) | Cached active session with PIN/fingerprint unlock in backlog | Partial | Yes | Add pre-login language switch. |
| **Bilingual Language Selection** | Partial (Dialog in Dev) | Partial | N/A (Client pref) | N/A | Persisted locally in Preferences DataStore | In Progress | No (XML keys exist, Compose UI wiring in progress) | Wire `stringResource` across all screens and add top-bar/settings language switcher. |

---

### B. Owner Role Workspace

| Feature | Screen Exists? | Navigation Works? | API / DB Connected? | Permissions Enforced? | Offline Behavior? | EN/HI Wired? | Verified in App? | Remaining Work |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **5-Tab Navigation** (Home, Orders, Business, Team, Activity) | Yes (`RouteFlowApp`) | Yes | Yes | Yes (OWNER role required) | Read-only cache | Yes | Yes | Complete. |
| **Pending Order Approvals** | Yes (`OrderApprovalScreen`) | Yes | Yes (`POST /orders/:id/approve`, `POST /orders/:id/reject`) | Yes (OWNER only) | Approvals queued online | Yes | Yes | Complete. |
| **Product Master Setup** (SKU, category, unit, wholesale price, MRP, Hindi name) | Yes (`OwnerProductsScreen`) | Yes | Yes (`GET/POST/PUT /products`) | Yes (OWNER only) | Cached in Room | Yes | Yes | Complete. |
| **Stock Adjustment & Receipts** | Yes (`OwnerProductsScreen` dialog) | Yes | Yes (`POST /inventory/adjust`) | Yes (OWNER / WAREHOUSE) | Queued if offline | Yes | Yes | Complete with idempotency key. |
| **Retailer Master & Onboarding** (Beat, credit limit, location, terms) | Yes (`OwnerRetailersScreen`) | Yes | Yes (`GET/POST/PUT /retailers`) | Yes (OWNER only) | Cached in Room | Yes | Yes | Complete. |
| **Employee & Staff Onboarding** (Role, active status, beats) | Yes (`OwnerEmployeesScreen`) | Yes | Yes (`GET/POST /employees`, deactivation) | Yes (OWNER only) | Cached in Room | Yes | Yes | Complete. |
| **Beat Master Setup** (Name, shops, visit order, assigned salesperson) | Yes (`OwnerBeatsScreen`) | Yes | Yes (`GET/POST /beats`, `/assign`) | Yes (OWNER only) | Cached in Room | Yes | Yes | Complete. |
| **Team Location & Shift Monitor** | Yes (`OwnerTeamScreen`) | Yes | Yes (`GET /team/status`) | Yes (OWNER only) | Live polling / cached | Yes | Yes | Complete. |
| **Daily Field Activity Review** (Planned vs completed, duration, exceptions) | Yes (`OwnerFieldActivityScreen`) | Yes | Yes (`GET /owner/visits/daily`) | Yes (OWNER only) | Cached | Yes | Yes | Complete. |
| **Cash Handover Acknowledgement & Discrepancies** | Yes (`OwnerHandoversScreen`) | Yes | Yes (`GET /owner/handovers`, `POST /owner/handovers/:id/acknowledge`) | Yes (OWNER only) | Server-confirmed | Yes (EN+HI) | **Yes (Vivo 1935 device-verified)** | Complete. Auto-calculates shortage/excess with mandatory notes. |
| **UPI / Cheque Verification & Payment Reversal** | Yes (`OwnerCollectionsScreen`) | Yes | Yes (`GET /collections`, `POST /collections/:id/review`) | Yes (OWNER only) | Cached in Room / Live review | Yes (EN+HI) | **Yes (Vivo 1935 device-verified)** | Complete. Authorized settlement and audit reversal update balance exactly once. |
| **Return Authorization, Inspection & Credit Notes** | Yes (`OwnerReturnsScreen`) | Yes | Yes (`GET /returns`, `POST /returns/:id/:step`) | Yes (OWNER only) | Cached / Server-confirmed | Yes (EN+HI) | **Yes (Vivo 1935 device-verified)** | Complete. Enforces return limits, saleable/damaged split, and issues credit note. |

---

### C. Salesperson Role Workspace

| Feature | Screen Exists? | Navigation Works? | API / DB Connected? | Permissions Enforced? | Offline Behavior? | EN/HI Wired? | Verified in App? | Remaining Work |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **5-Tab Navigation** (Today, Shops, Orders, Collections, Profile) | Yes (`RouteFlowApp`) | Yes | Yes | Yes (SALESPERSON) | Full offline | Yes | Yes | Complete. |
| **Start / End Shift & Durable Tracking** | Yes (`SalesTodayScreen`) | Yes | Yes (`POST /shifts/start`, `/end`, `/locations`) | Yes (SALESPERSON) | Room `shift_locations_outbox` with stable IDs; offline end queued to `sync_outbox` | Yes (EN+HI) | **Yes (Vivo 1935 device-verified)** | Complete. Offline shift end terminates tracking service locally immediately; queues to `sync_outbox`; WorkManager syncs upon reconnect without duplicates. |
| **Today's Assigned Shops** | Yes (`SalesTodayScreen`, `SalesHomeScreen`) | Yes | Yes (`GET /retailers`, `/beats`) | Yes (Filtered by assigned beat) | Full Room cache | Yes | Yes | Complete with visit status indicators. |
| **Shop Visit Check-In / Check-Out** | Yes (`ShopVisitScreen`, `SalesTodayScreen`) | Yes | Yes (`POST /visits`, `/checkout`) | Yes (Assigned beat only, single active visit rule) | Room entity + outbox sync | Yes | Yes | Complete. |
| **In-Store Stock Audit** | Yes (`ShopVisitScreen`) | Yes | Yes (`POST /stock-checks`) | Yes (Assigned beat only) | Room entity + outbox sync | Yes | Yes | Complete. |
| **Order Booking & Schemes** | Yes (`OrderBookingScreen`) | Yes | Yes (`POST /orders`) | Yes (Assigned beat only) | Room entity + WorkManager durable sync | Yes | Yes | Complete. |
| **Payment Collections** | Yes (`SalesCollectionsScreen`) | Yes | Yes (`POST /collections`) | Yes (SALESPERSON) | Room outbox + `sync_outbox` for offline | Yes (EN+HI) | **Yes (Vivo 1935 device-verified)** | Complete. Supports CASH (instant ledger/balance update) and UPI/CHEQUE (ENTERED status; unapplied until Owner review/clearance). Tested on Vivo 1935. |

---

### D. Warehouse Manager Role Workspace

| Feature | Screen Exists? | Navigation Works? | API / DB Connected? | Permissions Enforced? | Offline Behavior? | EN/HI Wired? | Verified in App? | Remaining Work |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **5-Tab Navigation** (Queue, Stock, Dispatch, Returns, More) | Yes (`RouteFlowApp`) | Yes | Yes | Yes (WAREHOUSE) | Read cache | Yes | Yes | Complete. |
| **Picking & Packing Queue** | Yes (`PickingScreen`) | Yes | Yes (`POST /orders/:id/start-picking`, `/pick-item`, `/pack`) | Yes (WAREHOUSE) | Queue cached locally | Yes | Yes | Complete. |
| **Driver Assignment & Dispatch** | Yes (`WarehouseHomeScreen`) | Yes | Yes (`POST /orders/:id/dispatch`) | Yes (Active drivers in company only) | Requires online check | Yes | Yes | Complete. |
| **Stock Receipts & Batch Intake** | Yes (`WarehouseStockScreen`) | Yes | Yes (`POST /inventory/adjust`) | Yes | Queued | Yes | Yes | Complete. |
| **Return Inspection & Disposition** | Yes (`WarehouseReturnsScreen`, `OwnerReturnsScreen`) | Yes | Yes (`GET /returns/pending`, `POST /returns/:id/inspect`, `POST /returns/:id/approve`) | Yes (WAREHOUSE / OWNER) | Server-confirmed; no local queue | Yes (EN+HI) | **Yes (Vivo 1935 device-verified)** | Complete. Enforces return limits, saleable restock vs damaged write-off, rejects excess returns, and issues credit notes. |

---

### E. Delivery Executive Role Workspace

| Feature | Screen Exists? | Navigation Works? | API / DB Connected? | Permissions Enforced? | Offline Behavior? | EN/HI Wired? | Verified in App? | Remaining Work |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **5-Tab Navigation** (Today, Deliveries, Collections, Handover, Profile) | Yes (`RouteFlowApp`) | Yes | Yes | Yes (DELIVERY) | Cached trips | Yes | Yes | Complete. |
| **Assigned Deliveries & Trip Navigation** | Yes (`DeliveryListScreen`) | Yes | Yes (`GET /orders`) | Yes (Assigned orders only) | Full Room cache | Yes | Yes | Complete. |
| **Delivery Confirmation & Mandatory OTP** | Yes (`DeliveryDetailScreen`) | Yes | Yes (`POST /orders/:id/deliver`) | Yes (Strict OTP + recipient name) | Must be online to verify OTP | Yes | Yes | Complete. |
| **Payment Collection** (CASH / CREDIT) | Yes (`DeliveryDetailScreen`) | Yes | Yes (`POST /orders/:id/deliver`) | Yes | Ledger created in atomic batch | Yes | Yes | Complete. |
| **Cash Handover & Shift Settlement** | Yes (`DeliveryHandoverScreen`) | Yes | Yes (`GET /handovers/summary`, `POST /handovers/request`) | Yes (DELIVERY) | Local summary cache, server-confirmed | Yes (EN+HI) | **Yes (Vivo 1935 device-verified)** | Complete. Submitted from Delivery, acknowledged on Owner with discrepancy. |

---

## 3. Specific Security & Integrity Verifications

1. **Production OTP Redaction**:
   - `c.req.header('X-Test-Runner') === 'true'` is now strictly gated by `isFailureInjectionAllowed(c)` (`ENVIRONMENT === 'development' && ENABLE_TEST_FAILURE_INJECTION === 'true'`). In production environments, client headers can never reveal OTPs.
2. **Simulated SMS Notice**:
   - In development/testing, the app must display a clear warning banner: `"Notice: SMS delivery is simulated. Live delivery blocked until SMS gateway integration is configured."`
3. **Stock Adjustment Idempotency & Atomic Commit**:
   - `POST /inventory/adjust` accepts an `idempotencyKey`. If retried with the same key, it returns the existing adjustment without duplicate stock mutation.
   - Products update, `stock_adjustments` entry, and `audit_logs` entry commit atomically in a single D1 batch.
4. **Visit Exclusivity Constraint**:
   - The salesperson app must strictly enforce that only one shop visit can be active at a time. The Salesperson cannot check into another retailer until the open visit has checked out with a valid outcome or reason.
5. **Delivered Quantity vs. Remaining Return Limits (Request-Level)**:
   - Distinct from inspection-disposition validation (which validates saleable + damaged split), the database trigger `return_quantity_guard` enforces that cumulative requested returns (`requested_quantity` + `free_quantity`) cannot exceed delivered order items.
   - Verified via `backend/tools/verify_return_remaining_limits.mjs`:
     * Order delivered: 10 paid units, 1 free unit.
     * First return: 4 paid units accepted.
     * Second return exceeding remaining (7 requested, 6 remaining): rejected with HTTP 409 without mutating stock, retailer balance, or creating credit notes.
     * Excess free units (2 requested, 1 remaining): rejected.
     * Valid remainder (6 paid, 1 free): accepted.
     * Further returns when balance is 0: rejected.

---

## 4. Database Migration, Backup & Field Evidence

### A. Consistent SQLite Backup Verification
- **Backup Mechanism**: Implemented in `backend/tools/backup_sqlite.py` utilizing the SQLite Online Backup API (`sqlite3.Connection.backup`) combined with `PRAGMA wal_checkpoint(TRUNCATE)`. Point-in-time snapshot created at `backend/db_backups/d1_consistent_backup_20260927_094333.sqlite` (1,179,648 bytes).
- **Integrity Validation**: Re-opened backup independently and executed:
  * `PRAGMA integrity_check`: `[('ok',)]`
  * `PRAGMA foreign_key_check`: `0` violations
  * Record counts verified intact: 29 users, 2 companies, 33 products, 346 orders, 13 collections, 163 ledger entries, 11 handovers, 1 shift.

### B. Fresh Seed-Free Wrangler Migration & Schema Parity
- **Wrangler Execution**: Executed `npx wrangler d1 migrations apply routeflow-db --local` against a clean, seed-free database directory.
- **Genuine Dependency Diagnosed & Fixed**: Migration `0007_beats_and_shifts.sql` previously contained an unconditional insert of initial pilot beats with `company_id = 'comp_1'`. On a fresh seed-free database where `companies` is empty, this triggered a foreign key constraint failure. Updated statement to conditionally insert beats `WHERE EXISTS (SELECT 1 FROM companies WHERE id = 'comp_1')`.
- **Deep Schema Parity**: Verified via `backend/tools/deep_compare_schemas.py` comparing the fresh Wrangler database against the live development database:
  * Tables: 33 vs 33 (100% column type, nullable, default value match)
  * Foreign Keys: Identical across all tables
  * Indexes: 31 vs 31 (full SQL definitions identical)
  * Triggers: 17 vs 17 (full SQL definitions identical)
- **Upgrade Path**: Verified via `backend/tools/verify_migration_lifecycle.py` preserving representative business data across versions.

### C. Physical Device Offline Shift Lifecycle & Recovery (Vivo 1935 / `4bc99b28`)
- **Shift Initiation**: Started shift via app Compose UI (`ShiftControlCard`). Foreground service `ShiftTrackingService` active (`isForeground=true`, ID 9110). Backend D1 recorded `ON_SHIFT` (`0dcfcde8-e192-4ea0-96de-0b24e7613122`).
- **True Offline State**: Explicitly executed `adb reverse --remove tcp:8787` (verified 0 active tunnels via `adb reverse --list`) and disabled Wi-Fi and mobile data.
- **Offline End Shift**: Tapped "End Duty / Shift" in app UI.
  * Local tracking terminated immediately: `dumpsys activity services` confirmed 0 active services.
  * Room DB marked `local_shifts` `OFF_SHIFT` (`endTime: 1790483075787`).
  * Room `sync_outbox` queued `SHIFT_END` event (`SAVED_OFFLINE`).
  * Backend D1 remained `ON_SHIFT` on server while offline.
- **Connection Restoration & Recovery**:
  * Connection restored via `adb reverse tcp:8787 tcp:8787` and Wi-Fi enabled.
  * **Automatic Recovery**: Without any user tap or forced ADB command, WorkManager's `OrderSyncWorker` automatically detected connection restoration, posted `POST /shifts/end` within 20s, updated backend D1 shift to `OFF_SHIFT` (`1790483075787`), and cleared `sync_outbox` (`[]`).
  * **User-Triggered Recovery**: Verified available via "Sync Now" button on `SalesProfileScreen` and `SalesHomeScreen` (`salesViewModel.syncNow()`), and on app foreground resume (`MainActivity.onResume()` -> `syncManager.scheduleSync()`).
