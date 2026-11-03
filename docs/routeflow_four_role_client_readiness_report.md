# RouteFlow — Four-Role Client Readiness & Ruthless Integration Test Report

**Evaluation Date:** November 1, 2026  
**Target Repository:** `D:\app`  
**Flutter Pilot:** `D:\app\flutter_distributor`  
**Target Physical Device:** Vivo 1935 (`4bc99b28`, Android 10, API 29, sw360dp)  
**Deliverable File:** `D:\app\docs\routeflow_four_role_client_readiness_report.md`  

---

## 1. Executive Summary & Verdict

### Final Verdict: `CONDITIONALLY READY` (Scripted Client Demo Only)
> **Summary Assessment:**  
> The four primary distributor operational roles (**SALES**, **WAREHOUSE**, **DELIVERY**, **ADMIN**) are visually polished, role-separated, and client-presentable on actual Android hardware (Vivo 1935) without visual overflows, broken layouts, or false claims.  
> However, because backend overselling protection (Migration 0024 trigger) has not yet been applied to production Cloudflare D1, and end-of-shift cash handover and GSTR-1 export remain intentionally disabled preview mocks, the system is **NOT READY** for autonomous field deployment. It is **CONDITIONALLY READY** strictly for guided, scripted client demonstrations.

### High-Level Evaluation Matrix

| Domain / Component | Status | Empirical Verdict | Key Justification |
| :--- | :--- | :--- | :--- |
| **Sales Representative Dashboard** | Supported | **PASS** | Responsive beat banner, active visit check-in, order preview modal with explicit `[LOCAL PREVIEW]` labeling, 0 screen overflows. |
| **Warehouse / Godown Dashboard** | Supported | **PASS** | Godown inventory balance, low-stock warnings, inward receipt form (sample pre-fills), pick & pack queue, van loading. |
| **Delivery / Van Logistics Dashboard** | Supported | **PASS** | Vehicle RJ-19-GB-4021 assignment, delivery stops list, OTP dialog with `[DEMO ONLY]` OTP, cash custody tracker, handover truthfully disabled. |
| **Distributor Admin Dashboard** | Supported | **PASS** | Executive turnover card with responsive GST breakdown, staff directory marked `SAMPLE DATA ONLY`, GSTR-1 export disabled. |
| **Unsupported Roles (OWNER, SALES_MGR, ACCOUNTANT, RETAILER)** | Supported Fence | **PASS** | Server-authenticated claim validation fails closed to `RoleBlockedView`. No silent mapping to Admin. |
| **Physical Hardware Compatibility (Vivo 1935)** | Tested on Device | **PASS** | Debug package `com.routidrow.distributor.debug` tested over ADB; 4 real screenshots captured; all 360dp width overflows resolved. |
| **Flutter Test Suite & Static Analysis** | Tested | **PASS** | `flutter analyze` reports 0 issues. `flutter test` reports **106/106 tests passed (100%)**. |
| **Backend Workers API Suite** | Tested | **PASS** | `npm test` reports **64/64 tests passed (100%)**. TypeScript typecheck reports 0 errors. |
| **Database Stock Allocation Integrity (Zero-Row)** | Tested Empirically | **FAIL / BLOCKED** | Current backend batch update allows order approval even when product update affects 0 rows. Proposed Migration 0024 trigger fixes this, but migration deployment is currently forbidden. |
| **Tenant Role CHECK Constraints (D1)** | Inspected | **BLOCKED** | Migration 0019 CHECK constraint restricts roles to 7 items and omits `SALES_MANAGER` and `ACCOUNTANT`. |

---

## 2. Section 1 — Four-Role Client Experience Audit

All four supported role dashboards were inspected in source code, verified with widget tests, and smoke-tested on physical hardware.

### 2.1 SALES Role (`SalesDashboard` & `SalesSubviews`)
- **Beat Overview Banner:** Displays today's assigned beat (`Sardarpura & Nai Sadak Route [Sample Beat]`) with sample location pill (`Jodhpur Central [Sample]`). Fitted with responsive text wrapping to prevent edge clipping on 360dp screens.
- **KPI Metrics:** Live count of today's booked orders (3 orders, ₹53,445 value) and beat shop coverage (1 / 4 visited).
- **Active Visit Check-In:** Prominently highlights the current shop visit (`Shree Ganesh Kirana Store`) with active status pill and `Check In` action.
- **Order Booking Flow & Preview Modal:**
  - Order booking subview allows selecting retailer, categories (Snacks, Namkeen, Spices, Ghee, Biscuits), SKU items, units (Box / Piece), and quantities.
  - Tapping "Review Booking Order" opens a safety bottom sheet displaying subtotal, CGST, SGST, grand total payable, and retailer name.
  - Clear labels: "Review Booking Order (Local Preview)" and "Retailer: ... • In-Memory Preview Only".
  - Order buttons: `Book on Khata (Credit Preview)` and `Book COD (Preview)`.
  - Confirmation snackbar explicitly states: `[LOCAL PREVIEW] Order booked for ... (In-memory preview)`. No false claims of backend persistence.
- **Recent Orders List:** Displays retailer name, item count, order number, rupees, and stage badge. Wrapped in `Expanded` to prevent horizontal overflow.
- **Navigation:** 5 dedicated sales tabs: `Home`, `New Order`, `Retailers`, `Products`, `My Visits`.

### 2.2 WAREHOUSE Role (`WarehouseDashboard` & `WarehouseSubviews`)
- **Godown Location Banner:** `Basni Industrial Area Phase II [Sample Facility]`, vehicle loading bay `RJ-19-GB-4021`, live stock sync indicator.
- **Stock Balance Cards:** Central Godown stock balance (1,055 Boxes across 8 active SKUs), Loaded in Van stock (132 Boxes).
- **Stock Threshold Warnings:** "All SKUs Healthy & Above Threshold" banner when stock >= 40 boxes; dynamic warning banner when any SKU drops below threshold.
- **Godown Operations:**
  1. *Godown Stock:* Searchable SKU list with category chips, showing current godown petis and quick "Adjust +" modal to update local testing balances.
  2. *Inward Intake Form:* Record factory shipments with supplier depot, challan number, truck number, SKU selector, box count, and batch number. Labeled: `Stock received here updates local test inventory. Default values below are sample form pre-fills.`
  3. *Pick & Pack Queue:* Displays pending booking orders ready for picking and packing with order line item summaries.
  4. *Van Loading:* Vehicle transfer interface allowing stock boxes to be moved from Godown balance to Van inventory.
- **Navigation:** 5 dedicated warehouse tabs: `Home`, `Godown Stock`, `Inward`, `Pick & Pack`, `Load Van`.

### 2.3 DELIVERY Role (`DeliveryDashboard` & `DeliverySubviews`)
- **Assigned Vehicle Banner:** Assigned truck `RJ-19-GB-4021 [Sample Vehicle]`, route `Sardarpura & Paota FMCG Drops`, active shift status.
- **Driver Cash Custody Card:** Live tracker of collected Cash on Delivery (`₹0 Held by driver`).
- **Stops Progress Card:** Progress counter showing completed vs total drops (`0 / 0`).
- **Van Stock on Board:** Displays remaining petis loaded on vehicle (`132 Petis, 0 Drops Pending`).
- **Delivery Stops Flow & OTP Modal:**
  - Displays customer stops list with COD amount, address, and status.
  - Delivery verification dialog requires customer OTP. Explicitly indicates `[DEMO ONLY]` OTP code (`1234`) with a disclaimer: `Production builds require verified SMS gateway delivery`.
- **Shift Handover (Safeguarded & Disabled):**
  - Shift Handover button is explicitly disabled (`onPressed: null`).
  - Warning banner: `UNAVAILABLE / DEMO ONLY: Persistent cash reconciliation is not implemented in this pilot. Driver cash custody remains active on device and cannot be cleared without a verified server ledger.`
- **Navigation:** 5 dedicated delivery tabs: `Home`, `My Trips`, `Stops`, `Collections`, `Handover`.

### 2.4 ADMIN Role (`AdminDashboard` & `AdminSubviews`)
- **Distributor Executive Banner:** `Jodhpur FMCG Depot [Sample Org]`, Operational Overview, `Audit Grade` pill.
- **Financial Turnover & GST Card:**
  - Displays Delivered Sales Turnover (`₹0.00`). Labeled `Delivered Sales Turnover (Delivered Orders) [ESTIMATE ONLY]`.
  - Responsive 3-column breakdown: `CGST (Est.)`, `SGST (Est.)`, and `Total GST`.
  - Disclaimer: `* Note: Illustrative estimate assuming standard rate. Product-level HSN tax brackets and interstate IGST are not computed in this client preview.`
- **Working Capital & Inventory Snapshot:**
  - Driver Cash Custody (`₹0 Held by delivery driver`) vs Retailer Udhaar (`₹79,300 across 4 Khata Accounts`).
  - Central Godown Stock (`1,055 Petis`) vs Active Van Stock (`132 Petis`).
- **Admin Management Sections:**
  1. *Orders:* Master order list with stage badges, payment modes, van assignments, and order values.
  2. *Products:* Master catalog with MRP, piece price, GST rate, and godown stock.
  3. *Retailers:* Retailer directory with proprietor contacts, addresses, and Khata balances.
  4. *Staff (Safeguarded Mock):* Employee roster banner: `SAMPLE DATA ONLY: The employee roster below contains demo mock entries for UI evaluation. No server-side staff directory is connected.`
  5. *Inventory Allocation:* Side-by-side comparison of Godown vs Van petis per SKU.
  6. *Reports (Safeguarded & Disabled):* Turnover and tax summary. Export button `Export GSTR-1 Filing (Unavailable — Demo Only)` is disabled (`onPressed: null`).
- **Navigation:** 6 dedicated admin tabs: `Overview`, `Orders`, `Products`, `Retailers`, `Staff`, `Inventory`.

---

## 3. Section 2 — Authorization & Role Routing Matrix

### 3.1 Eight Canonical Roles Specification Review

| Canonical Role | Client Pilot Status | Mapping Behavior | Privilege / Safety Rule |
| :--- | :--- | :--- | :--- |
| `SALES` | **Supported** | `SalesDashboard` (5 tabs) | Field order booking, visits, retailer catalog. |
| `WAREHOUSE` | **Supported** | `WarehouseDashboard` (5 tabs) | Stock balance, receiving, picking, loading. |
| `DELIVERY` | **Supported** | `DeliveryDashboard` (5 tabs) | Stops queue, delivery OTP, COD custody. |
| `ADMIN` | **Supported** | `AdminDashboard` (6 tabs) | Master orders, inventory allocation, Udhaar ledger. |
| `OWNER` | **Unsupported** | **Fails Closed** (`RoleBlockedView`) | **Strict Barrier:** Never mapped to Admin. Prevents unauthorized escalation. |
| `SALES_MANAGER` | **Unsupported** | **Fails Closed** (`RoleBlockedView`) | Lacks mobile dashboard spec; access denied. |
| `ACCOUNTANT` | **Unsupported** | **Fails Closed** (`RoleBlockedView`) | Lacks mobile dashboard spec; access denied. |
| `RETAILER` | **Unsupported** | **Fails Closed** (`RoleBlockedView`) | Separate B2B portal persona; blocked in pilot. |
| `UNKNOWN` | **Invalid** | **Fails Closed** (`RoleBlockedView`) | Unrecognized role claim rejected immediately. |

### 3.2 Server Session Authority & Alias Normalization
- The active role is extracted strictly from `authService.session.activeRole`, which is parsed from verified JWT payload claims (`active_role` / `role`).
- Quick-fill debug chips on the login screen merely populate text field credentials; they never bypass authentication or set client role state directly.
- Legacy role aliases normalize deterministically:
  - `sales_representative`, `sales_rep`, `sales` → `CanonicalRole.sales`
  - `warehouse_manager`, `inventory_manager`, `inventory` → `CanonicalRole.warehouse`
  - `delivery_driver`, `logistics`, `driver` → `CanonicalRole.delivery`
  - `distributor_admin`, `admin` → `CanonicalRole.admin`
- All other values return `null`, causing `RoleShell` to route to `RoleBlockedView`.

### 3.3 Test Verification
- All 10 tests in `test/role_routing_test.dart` passed in 1.4s:
  - Role alias normalization verified.
  - Unknown and unauthorized roles fail-closed verified.
  - Permission matrix boundaries verified (`assertRolePermission`).
  - 4 supported dashboards mount with correct tab counts verified.
  - Fail-closed barrier for `OWNER`, `SALES_MANAGER`, `ACCOUNTANT`, `RETAILER` verified.
  - Logout session termination verified.

---

## 4. Section 3 — Backend & Database Integration Audit

### 4.1 Backend Test Suite & Static Analysis
- **Execution Command:** `cd backend && npm test`
- **Results:** **64 / 64 passing (100%)** across 2 suites (`daily-cycle.test.ts`, `warehouse.test.ts`, `planned-routes.test.ts`, `security-rbac-retailer.test.ts`).
- **Typecheck Command:** `npm run typecheck` (`tsc --noEmit`)
- **Results:** **0 TypeScript errors**.

### 4.2 Empirical Zero-Row Defect Reproduction (Stock Overselling Vulnerability)
- **Defect Location:** `backend/src/index.ts:1013-1035` (`POST /api/orders/:id/approve`).
- **Mechanism:**  
  The backend executes an atomic D1 batch containing two statements:
  ```sql
  UPDATE orders SET status = 'APPROVED' WHERE id = :order_id AND tenant_id = :tenant_id AND status = 'SUBMITTED';
  UPDATE products SET reserved_quantity = reserved_quantity + :qty 
  WHERE id = :prod_id AND tenant_id = :tenant_id AND (stock_quantity - reserved_quantity) >= :qty;
  ```
- **The Failure Mode:**  
  In SQLite and Cloudflare D1, an `UPDATE` statement whose `WHERE` condition matches 0 rows returns `changes = 0`. It does **NOT** throw an error or abort the transaction.  
  As a result:
  1. Statement 1 executes: Order status changes from `SUBMITTED` to `APPROVED` (`changes = 1`).
  2. Statement 2 executes: Insufficient stock causes the `WHERE` condition to fail (`changes = 0`).
  3. The batch commits successfully.
  4. **Consequence:** The order is marked `APPROVED`, but 0 stock is reserved. Physical stock is oversold, corrupting inventory balances.
- **Empirical Verification (`scratch/test_zero_row.py`):**
  - Without Trigger: Product stock was 5, order required 10. The batch committed without error; order became `APPROVED` with 0 stock reserved.
  - With Proposed Trigger (`trg_validate_order_approval_atomic` from Migration 0024): The trigger evaluates Available-To-Promise (`stock_quantity - reserved_quantity`) before update. When ATP < requested quantity, it raises `RAISE(ABORT, 'ERR_INSUFFICIENT_ATP...')`. The transaction immediately terminates with an error, rolling back the entire batch. The order remains `SUBMITTED` and 0 stock leaks.
- **Status:** **BLOCKED**. Migration 0024 is written but must NOT be applied until explicit deployment authorization is granted.

### 4.3 Database D1 Schema & CHECK Constraint Gap
- Inspected Migrations `0001` through `0023`.
- **Finding:** Migration `0019_rbac_phase_b2_1.sql` defines the `organization_memberships` table with:
  ```sql
  CHECK (role IN ('OWNER', 'ADMIN', 'MANAGER', 'WAREHOUSE', 'DELIVERY', 'SALES', 'RETAILER'))
  ```
- **Constraint Gap:** The CHECK constraint does not permit canonical roles `SALES_MANAGER` or `ACCOUNTANT`. Inserting a user with either canonical role will fail with `CHECK constraint failed: organization_memberships`. Proposed Migration 0024 expands this constraint to all 8 canonical roles.

---

## 5. Section 4 — Physical Device Testing (Vivo 1935)

### 5.1 Device Specifications & Package Verification
- **Device Model:** Vivo 1935 (`model:vivo_1935`, Android 10, API 29, screen density 480dpi, viewport width 360dp).
- **Connected ADB Serial:** `4bc99b28`.
- **Application Identity Separation:**
  - Production package: `com.routidrow.distributor` (preserved untouched, B1 SQLite database intact).
  - Debug testing package: `com.routidrow.distributor.debug` (isolated test harness).
  - Both packages co-exist peacefully on the physical device without database collision.

### 5.2 Real Hardware UI Defects Discovered & Resolved
Testing on physical 360dp hardware uncovered 4 critical visual overflow defects that passed headless widget tests:
1. **AppBar Title Horizontal Overflow:**  
   - *Problem:* Packing Organization selector, Edge D1 badge, GST summary button, and Logout button into `AppBar.actions` left only ~130dp for `AppBar.title`. `ROUTIDROW` + `SALES` badge + username exceeded 130dp, causing a rotated red overflow banner.
   - *Resolution:* Wrapped title row and username in `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)` and set `toolbarHeight: 64`. On narrow screens, the title scales down gracefully without overflowing.
2. **Sales Beat Banner Right Overflow (33 Pixels):**  
   - *Problem:* `TODAY'S ASSIGNED BEAT` label and `Jodhpur Central [Sample]` pill in an unconstrained `Row` exceeded 296dp on 360dp screens.
   - *Resolution:* Wrapped left header row in `Expanded` and text in `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))`.
3. **Sales Recent Orders Right Overflow (50 Pixels):**  
   - *Problem:* Retailer shop names (e.g. "Jodhpur Wholesale Traders") in an unconstrained inner `Row` pushed the order value past the screen margin.
   - *Resolution:* Wrapped retailer details in `Expanded` and added `maxLines: 1, overflow: TextOverflow.ellipsis`.
4. **Admin Delivered Turnover Card Right Overflow (32 & 38 Pixels):**  
   - *Problem:* `Delivered Sales Turnover (Delivered Orders)` + `ESTIMATE ONLY` badge row overflowed by 32px. The 3-column GST row (`CGST (Estimated Central)` + `SGST (Estimated State)` + `Total GST (Est.)`) overflowed by 38px.
   - *Resolution:* Wrapped turnover title in `Expanded` and wrapped all 3 tax columns in `Expanded` with compact labels (`CGST (Est.)`, `SGST (Est.)`, `Total GST`).

### 5.3 Hardware Verification Screenshots
Live PNG captures taken directly from the Vivo 1935 via `adb exec-out screencap -p`:
- `device_role1_sales.png` (Sales Representative Dashboard)
- `device_role2_warehouse.png` (Warehouse Godown Dashboard)
- `device_role3_delivery.png` (Delivery & Logistics Dashboard)
- `device_role4_admin_fixed.png` (Distributor Executive Admin Dashboard)

All 4 screenshots confirm 0 visual overflows, 0 layout clipping, and clean client-grade visual hierarchy.

---

## 6. Section 5 — Detailed Component Classification

| Component / Requirement | Category | Verdict | Evidence / Status |
| :--- | :--- | :--- | :--- |
| **Sales Dashboard Beat View** | UI / Flow | `PASS` | Verified on Vivo 1935. Clean layout, sample badge, 0 overflow. |
| **Sales Order Booking Preview** | UI / Safety | `PASS` | Order preview sheet shows subtotal, GST, grand total; labeled `[LOCAL PREVIEW]`. |
| **Sales Offline/Catalog Navigation** | UI / Navigation | `PASS` | All 5 tabs responsive and operational. |
| **Warehouse Stock Metrics** | UI / Data | `PASS` | Displays Godown (1,055) vs Van (132) boxes truthfully. |
| **Warehouse Inward Intake** | UI / Flow | `PASS` | Factory shipment form updates local stock; labeled sample pre-fills. |
| **Warehouse Pick & Pack** | UI / Flow | `PASS` | Displays booking orders queue. |
| **Warehouse Van Loading** | UI / Flow | `PASS` | Stock transfer to vehicle RJ-19-GB-4021 functional in memory. |
| **Delivery Vehicle Assignment** | UI / Data | `PASS` | Shows active shift and van RJ-19-GB-4021. |
| **Delivery Stops Queue** | UI / Flow | `PASS` | Stops list with empty/active states. |
| **Delivery OTP Verification** | UI / Security | `PASS` | Dialog labeled `[DEMO ONLY]` OTP 1234; no false production claims. |
| **Delivery Cash Handover** | UI / Safety | `PASS` | Button explicitly disabled (`onPressed: null`) with warning banner. |
| **Admin Executive Overview** | UI / Data | `PASS` | Delivered turnover card, GST breakdown, working capital summary. |
| **Admin Staff Roster** | UI / Safety | `PASS` | Labeled `SAMPLE DATA ONLY`; no false backend claim. |
| **Admin GST / Tax Report** | UI / Compliance | `PASS` | Labeled `Illustrative Estimate Only`; export button disabled. |
| **Role Claim Enforcement** | Auth / RBAC | `PASS` | Canonical role parsed strictly from verified server JWT session. |
| **Unsupported Role Fail-Closed** | Auth / Security | `PASS` | OWNER, SALES_MGR, ACCOUNTANT, RETAILER route to `RoleBlockedView`. |
| **Flutter Test Suite** | Testing | `PASS` | 106/106 tests passed (100%). |
| **Flutter Static Analysis** | Code Quality | `PASS` | `flutter analyze` reports 0 issues. |
| **Backend Integration Suite** | Backend | `PASS` | 64/64 tests passed (100%). |
| **Backend Typecheck** | Backend | `PASS` | `npm run typecheck` reports 0 errors. |
| **Backend Overselling Protection** | Backend / DB | `FAIL / BLOCKED` | Zero-row bug allows approving orders without stock reservation. |
| **D1 Role CHECK Constraint** | Database | `BLOCKED` | Migration 0019 CHECK constraint lacks `SALES_MANAGER` and `ACCOUNTANT`. |
| **Persistent Shift Handover** | Feature | `NOT IMPLEMENTED` | Intentionally not implemented in pilot; properly disabled in UI. |
| **CBIC GSTR-1 Tax Filing Export** | Feature | `NOT IMPLEMENTED` | Intentionally not implemented in pilot; properly disabled in UI. |
| **Live SMS Gateway OTP** | Integration | `NOT TESTED` | Mock OTP 1234 used for offline pilot evaluation. |
| **Cross-Tenant Migration in Production**| Deployment | `NOT TESTED` | Migrations 0024–0027 quarantined until approved. |

---

## 7. Section 6 — Production Pre-requisites for Phase B2.2

Before RouteFlow can transition from `CONDITIONALLY READY` (Scripted Client Demo) to `CLIENT DEMO READY` (Unconstrained Production Deployment), the following sequence must be executed under separate authorization:

1. **Authorize & Apply D1 Migration 0024:**
   - Deploy `trg_validate_order_approval_atomic` trigger to ensure zero-row product updates fail and rollback order approvals.
   - Expand `organization_memberships` role CHECK constraint to include all 8 canonical roles.
2. **Authorize & Deploy Backend Route Handler Updates:**
   - Update `POST /api/orders/:id/approve` to inspect SQLite `changes` count or rely on the Migration 0024 trigger error.
   - Implement server-side verification for Delivery Shift Handover before resetting driver cash custody.
3. **Execute Drift Migration on Android Client:**
   - Add `tenant_id` ownership column to local Drift schema.
   - Safely migrate existing 28 B1 legacy records from quarantine to authenticated tenant ownership.
4. **Connect Production SMS / WhatsApp Provider:**
   - Replace hardcoded demo OTP (`1234`) with dynamic Cloudflare Worker OTP generation via Twilio/Gupshup.
