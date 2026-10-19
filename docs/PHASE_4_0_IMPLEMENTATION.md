# RouteFlow Phase 4.0 — Android Van-Sales UI Foundation Implementation Report

**Status:** `Source corrected — not runtime-verified`  
**Date:** October 19, 2026  
**Scope:** Mobile Android Van-Sales UI Foundation (Jetpack Compose, Room, Retrofit, WorkManager)

---

## 1. Executive Summary

Phase 4.0 establishes the first complete Android mobile user interface and state machine foundation for van sales operations within RouteFlow. The implementation builds directly on the hardened backend contracts (`POST /van-sales/orders` and `POST /van-sales/orders/:id/confirm`) established in Phases 3.0 through 3.10 and adheres strictly to the existing Android architecture: **Kotlin + Jetpack Compose + Room + Retrofit + WorkManager (Hilt)**.

### Strict Execution Constraints Observed:
- Static source code and documentation inspection and implementation only.
- **Zero** builds, tests, emulators, server processes, migrations, or database writes were executed.
- Unrelated working tree changes were preserved without modification.
- All implementations are labeled `Source corrected — not runtime-verified`.

---

## 2. Key Architecture & Components Implemented

### 2.1 Authenticated Entry Points & Role Permission Guarding
- **Allowed Roles:** `OWNER`, `ADMIN`, `SALESPERSON`, `DELIVERY_EXECUTIVE` (matches server-side RBAC in `backend/src/security.ts:canPerform(role, 'van_sales:create')`).
- **Permission Guard:** Evaluated reactively in `VanSalesViewModel` from `sessionRepository.activeEmployee`. Unauthorized roles receive an explicit, non-bypassable warning card indicating that their role cannot conduct van sales.
- **Navigation Touchpoints:**
  1. `SalesHomeScreen`: Added a prominent primary CTA button **"Van Spot Sale (Vehicle Stock)"** directly within the duty and route action panel.
  2. `ShopVisitScreen`: Added a dedicated **"Van Spot Sale"** action card to the in-visit action grid when attending an assigned retailer.
  3. `RouteFlowApp`: Configured navigation route `sales/van-sale/{retailerId}` with localized TopAppBar title resolution (`"Van Spot Sale"` / `"वैन स्पॉट सेल"`).

### 2.2 Vehicle & Trip Context Requirement (Blocking Guard)
- **Problem:** The backend van-sales contract strictly requires `order.tripId` to locate allocations and execute atomic deductions from `van_stock_allocations`. Recording spot sales without an active delivery trip leads to unallocatable sales and stock desynchronization.
- **Implementation:**
  - `VanSalesViewModel` queries `orderRepository.getActiveTrip(employeeId)` and validates trip status against `('PLANNED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY')`.
  - If no active trip exists, `isTripMissing` is set to `true`.
  - The UI presents a high-visibility blocking card (`TripContextCard`) informing the salesperson that an active vehicle trip is required.
  - Adding items to the cart and the final submission button are strictly disabled while trip context is missing.

### 2.3 Retailer Selection & Real-Time Credit Health Display
- **Dropdown & Direct Linking:** Supports opening directly for a visited shop or choosing from assigned beat retailers via `ExposedDropdownMenu`.
- **Credit Summary Display:**
  - **Outstanding Balance:** Color-coded badges distinguishing Pending Udhaar (`Color(0xFFDC2626)`), Advance Balance (`Color(0xFF16A34A)`), and No Due (`Color(0xFF64748B)`).
  - **Credit Limit & Remaining Credit:** Formatted via `CurrencyFormatter.formatPaise(...)`.
  - **Credit Limit Exceeded Warning:** When payment method is set to `CREDIT` and `outstanding + estimatedOrderTotal > creditLimitPaise`, a red alert banner notifies the user that server rules require spot Cash/UPI payment or an authorized credit override reason.
  - **Near-Limit Warning:** Alerts when the transaction will consume more than 80% of remaining credit.

### 2.4 Vehicle Stock Catalog & Integer Stepper
- **Vehicle Stock Badging:** Products display real-time available van stock (`Van Stock: X units` or `Van: Out of stock`).
- **Quantity Bounds:** Integer quantity steppers (`[-]` qty `[+]`) enforce `0 <= qty <= availableVanStock`. The increment button is disabled once the vehicle stock limit is reached.
- **Integer Math Only:** All client calculations operate exclusively on integer paise (`Long`), completely eliminating floating-point rounding issues.

### 2.5 Provisional Estimates & Server-Authoritative Disclaimer
- **Client Pricing as Provisional:** The mobile app calculates an estimated subtotal, estimated GST (18%), and estimated grand total in integer paise.
- **Non-Authoritative Disclaimer:** Every view surfaces an explicit disclaimer:
  > *"Provisional Estimate — Final line item pricing, taxes, schemes & inventory deductions are calculated authoritatively by the server."*
- **Mode Toggle:** Seamlessly supports **Spot Billing (Instant Delivery & Stock Deduction)** (`isProvisional = false`) and **Provisional Quote Booking** (`isProvisional = true`).

### 2.6 Room Outbox & WorkManager Integration
- **Stable Idempotency Key:** Each sale generates a permanent UUID key (`van_idemp_${UUID.randomUUID()}`) persisted with the order.
- **Local Transaction:** `database.withTransaction` atomically writes:
  1. `OrderEntity` (status `SUBMITTED` or `DELIVERED`).
  2. `OrderItemEntity` items.
  3. `SyncOutboxEntity` with `type = "VAN_SALE_ORDER"`, `syncState = "SAVED_OFFLINE"`, and the serialized `VanSaleSubmitRequest`.
- **Offline / Transient Tolerance:** If network call is unavailable or fails due to network timeout/500, the order remains safely queued in outbox and `syncManager.scheduleSync(...)` enqueues `OrderSyncWorker`. The user receives a confirmation that the order is saved offline and will sync automatically.
- **Quarantine on Permanent Rejection:** If the server returns a 4xx error (e.g. 400, 403, 404, 409, 422), `NetworkOrderRepository` immediately marks the outbox item as `NEEDS_ATTENTION` with `lastError = "VALIDATION_REVIEW"`, halting queue poisoning and informing the user.

---

## 3. Files Created & Modified

| File | Change Type | Description |
|---|---|---|
| `app/src/main/java/com/routeflow/app/feature/vansales/VanSalesUiState.kt` | **Created** | UI state models, vehicle stock items, integer financial calculations, and credit warnings. |
| `app/src/main/java/com/routeflow/app/feature/vansales/VanSalesViewModel.kt` | **Created** | Hilt ViewModel managing permissions, trip validation, cart state, integer bounds, and submission. |
| `app/src/main/java/com/routeflow/app/feature/vansales/VanSalesScreen.kt` | **Created** | Full Jetpack Compose screen with trip banner, retailer credit card, stock catalog, cart summary, and dialogs. |
| `app/src/main/java/com/routeflow/app/domain/repository/OrderRepository.kt` | **Modified** | Added `submitVanSaleOrder` and `confirmVanSaleOrder` interface signatures. |
| `app/src/main/java/com/routeflow/app/data/repository/NetworkOrderRepository.kt` | **Modified** | Implemented `submitVanSaleOrder` with atomic Room outbox insert, immediate network attempt, and permanent error quarantine. |
| `app/src/main/java/com/routeflow/app/data/repository/OfflineOrderRepository.kt` | **Modified** | Implemented `submitVanSaleOrder` and `confirmVanSaleOrder` for demo and offline mock paths. |
| `app/src/main/java/com/routeflow/app/feature/sales/SalesHomeScreen.kt` | **Modified** | Added `onStartVanSale` callback and dedicated **"Van Spot Sale (Vehicle Stock)"** action button. |
| `app/src/main/java/com/routeflow/app/feature/sales/ShopVisitScreen.kt` | **Modified** | Added `onVanSale` callback and **"Van Spot Sale"** action tile in shop visit field actions grid. |
| `app/src/main/java/com/routeflow/app/navigation/RouteFlowApp.kt` | **Modified** | Added `SALES_VAN_SALE` destination route, TopAppBar titles, and composable screen wiring. |
| `app/src/main/res/values/strings.xml` | **Modified** | Added English string resources for van sales, trip requirements, credit alerts, and disclaimers. |
| `app/src/main/res/values-hi/strings.xml` | **Modified** | Added Hindi localized string resources for van sales. |

---

## 4. Manual Runtime Verification Checklist (For Future Execution)

When a runtime verification environment is prepared, execute the following non-destructive test suite:

- [ ] **TC-VS-01: Unauthorized Role Access**
  - Sign in as a `RETAILER` or unauthorized user.
  - Navigate to van sales.
  - Verify access is blocked with a permission error and the submit action is disabled.
- [ ] **TC-VS-02: Missing Trip Context Blocking**
  - Sign in as a `SALESPERSON` with no active delivery trip.
  - Open Van Spot Sale.
  - Verify red/amber warning appears: *"Active Vehicle Trip Required"*.
  - Verify product stepper increment and submit button are disabled.
- [ ] **TC-VS-03: Active Trip Loaded**
  - Sign in as a driver or salesperson with an active trip (`IN_TRANSIT`).
  - Open Van Spot Sale.
  - Verify green trip card appears displaying Trip number, Vehicle number, and status.
- [ ] **TC-VS-04: Van Stock Quantity Clamping**
  - Select a product with 10 units in vehicle stock.
  - Attempt to increment quantity to 11.
  - Verify stepper disables at 10 and prevents adding beyond vehicle stock.
- [ ] **TC-VS-05: Credit Limit Exceeded Warning**
  - Select a retailer with ₹10,000 credit limit and ₹9,500 pending balance.
  - Add ₹1,000 worth of goods to cart and select `CREDIT` payment.
  - Verify credit limit exceeded warning card appears and prompts for override reason.
  - Switch payment method to `CASH` or `UPI`; verify credit limit warning clears.
- [ ] **TC-VS-06: Offline Spot Sale Outbox Queuing**
  - Place mobile device in Airplane Mode.
  - Complete a van spot sale and tap "Confirm & Bill Van Sale".
  - Verify order is written to Room database and outbox with status `SAVED_OFFLINE`.
  - Turn off Airplane Mode; verify `OrderSyncWorker` processes the outbox item and transitions order to `DELIVERED` with backend stock deduction.
- [ ] **TC-VS-07: Idempotency Protection**
  - Inspect the submitted outbox payload.
  - Verify `idempotencyKey` remains identical across network retries and worker attempts.

---

## 5. Conclusion & Next Steps

Phase 4.0 completes the Android mobile UI foundation for van sales safely, conservatively, and in full alignment with RouteFlow's architecture.

**Recommended Next Step:**
- Proceed to **Phase 4.1: Van-Sales End-to-End Field Validation & Integration Testing** (preparing automated tests or runtime staging verification when authorized by the user).
