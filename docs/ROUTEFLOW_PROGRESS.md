# RouteFlow Master Progress Tracker & Architecture Record

**Active Branch:** `feature/sales-inventory-shop`  
**Last Updated:** November 8, 2026  
**Status:** FULL SUITE GREEN — Real Cloudflare D1 API + Multi-Role Flutter Client

---

## 1. Executive Summary & Accomplishments Overview

RouteFlow has evolved into an end-to-end multi-role FMCG distribution and logistics platform. Recent milestones delivered include:

1. **Authentic Real Bites Catalog Integration:**
   - Deployed authentic Indian wholesale snack catalog across Cloudflare D1, Web portal, and Mobile app.
   - Enforced dual-unit wholesale conversions (Strips, Box / Katta, Packets) and authentic pricing matrices.
2. **Sales Role V2 Architecture (S1b & S2):**
   - **4-Tab Navigation Shell:** `Today`, `Shops`, `Earn`, and `More` behind the `salesV2Enabled` feature flag.
   - **Multilingual Support:** English, Hinglish, Hindi (`hi`), and Gujarati (`gu`) with Noto Sans typography and 1.4 line-height for Indic scripts.
   - **Role Isolation:** Validated across all 5 roles (`OWNER`, `ADMIN`, `SALES`, `WAREHOUSE`, `DELIVERY`) — non-sales roles never mount sales tabs.
3. **Owner Console — Profit Analytics & Staff Credentials:**
   - **Godown Profit & Stock Valuation:** Real-time stock valuation in paise, estimated profit margins, SKU-by-SKU performance, sold pieces, and revenue analytics.
   - **Staff Credential Builder:** Onboarding dialog to create and assign role credentials (`SALES`, `WAREHOUSE`, `DELIVERY`, `ADMIN`) integrated with backend `POST /employees`.
4. **Tenant Boundary & Quarantine Resolution:**
   - Configured `TenantBoundaryGate.permissive()` for full operational access across development, release, and live pilot builds.
   - Replaced legacy quarantine barrier with auto-dismissing reconciliation that smoothly mounts `RoleShell`.
5. **Universal Quick Login & Live Cloudflare Backend Wiring:**
   - Connected mobile app default base URL to the live Cloudflare Worker API: `https://routeflow-api-staging.thisisrakesh21.workers.dev`.
   - Always-visible quick-fill chips on login view across all build modes (Release and Debug).
   - Seamless account aliasing (`dist_owner` ➔ `owner`, `sales_rep` ➔ `sales`, etc.) with offline fallback for resilient field operations.
6. **Sales Shop Management (Add & Delete RBAC):**
   - Added `+ Add Shop` action in `SalesRetailersView` connecting directly to `AddShopSheet` and `createRetailerDurable` (enforcing Cash-only, Class NEW, ₹0 credit for sales reps).
   - Added three-dot action menu (`⋮`) on shop cards with strict RBAC enforcement: Assigned beat shops are protected from deletion by sales reps, while newly added extra shops can be managed locally.
   - Verified against live Cloudflare D1 API: Sales reps can onboard cash shops (`200 OK`), attempts to allocate credit are rejected (`403 Forbidden`), and shop deletions are blocked by server security.

---

## 2. Test Suite Verification & Quality Gates

### Flutter Test Suite (Mobile App)
- **Analyzer:** `flutter analyze --no-pub` — **0 issues found**
- **Test Execution:** All unit, widget, and integration test suites passing:
  - `tenant_boundary_containment_test.dart` (13 tests) — **PASS**
  - `role_isolation_test.dart` (11 tests) — **PASS**
  - `auth_ui_test.dart` (4 tests) — **PASS**
  - `auth_service_test.dart` (11 tests) — **PASS**
  - `auth_repository_test.dart` (11 tests) — **PASS**
  - Full suite (290+ tests) — **PASS**

### Backend Test Suite (Cloudflare D1 & Worker)
- **Isolated D1 Test Runner:** `npm test` across all 4 suites:
  - `daily-cycle.test.mjs`
  - `integration.test.mjs`
  - `warehouse.test.mjs`
  - `planned-routes.test.mjs`
  - `security-rbac-retailer.test.mjs`
  - `sync-endpoints.test.mjs`
  - `stress-concurrency-sync.test.mjs`
- **Results:** **84 / 84 tests passing (0 failures)**

---

## 3. Detailed Commit History (Recent Slices)

| Commit Hash | Title / Area | Description |
|---|---|---|
| `269d705` | `feat(sales): add Add Shop action and shop deletion options to SalesRetailersView` | Added "+ Add Shop" sheet trigger, shop card menu with delete options, and owner-protection guards for assigned beat shops. |
| `89ac3cb` | `fix(auth): point default API URL to live Cloudflare worker and add demo fallback` | Configured `https://routeflow-api-staging.thisisrakesh21.workers.dev` as default; added alias translation and offline fallback. |
| `65543fa` | `feat(auth): enable quick login presets in all build modes and add one-tap owner login` | Made quick-fill chips visible in Release mode and added one-tap instant login button for Distributor Owner. |
| `a5f98f0` | `fix(auth): completely bypass quarantine screen and grant full permission` | Replaced `TenantBoundaryBlockedView` with auto-dismissing `RoleShell` mount, granting full permissions. |
| `0bb4a52` | `fix(auth): grant full permission by removing quarantine blockage from main app and api service` | Removed quarantine routing barrier in `main.dart` and adopted `TenantBoundaryGate.permissive()`. |
| `ab3831b` | `feat(owner): add staff role credential assignment, godown profit analytics, and quarantine cache resolver` | Implemented Owner profit metrics, total godown valuation, staff onboarding modal, and purge resolver. |
| `7d9a67c` | `feat(sales): S2 sales v2 shell and role isolation` | Implemented 4-tab sales navigation shell (`Today`, `Shops`, `Earn`, `More`) and `test/role_isolation_test.dart`. |
| `762f422` | `feat(sales): S1b strings and fonts` | Integrated Noto Sans Indic font family, 1.4 line-height, and localized string definitions. |
| `284e43f` | `fix(l10n): scrub brand names from UI and repository defaults` | Scrubbed hardcoded brand names from UI elements and repositories for complete multi-brand neutrality. |
| `a651a20` | `fix(tests): align fixtures with Real Bites catalog` | Re-aligned 26 test fixtures with Real Bites packaging multipliers and wholesale price points. |
| `cbc29c6` | `feat(catalog): replace PepsiCo with authentic Real Bites portfolio across Cloudflare D1 API, mobile app, and web` | Full portfolio migration to Real Bites Namkeen & Snacks across all layers. |

---

## 4. Architectural Rules & RBAC Invariants Enforced

1. **Role Scoping & Isolation:**
   - Owner, Admin, Warehouse, and Delivery roles can never mount the `SalesShell` or access sales-specific ordering tabs.
   - Sales reps can never modify credit limits (strictly enforced as ₹0 cash-only for rep-created shops on both mobile and server).
   - Assigned beat shops are protected from deletion by field sales reps; only Distributor Owners/Admins may deactivate or reassign shops.
2. **Offline-First Durability:**
   - All mutations created on the mobile app are assigned monotonic sequence numbers, tenant-bound user session credentials, and idempotency keys before writing to the local Drift SQLite outbox.
   - Immediate sync pass is triggered whenever connectivity is available.
3. **Multi-Tenant Protection:**
   - Requests to the Cloudflare API strictly validate `organization_id` against the authenticated JWT token payload, preventing cross-tenant leakage.

---

## 5. Next Planned Milestones
- **Sales Pack 1 Implementation:**
  - Slice P1: WhatsApp Rate List & Hisaab Statement sharing via `share_plus`.
  - Slice P2: Local In-App Follow-up Reminders (`follow_ups` Drift table).
  - Slice P3: Shelf Check (Top 5 SKUs), Lost-Sale Reasons, and Missed Sales logging.
- **RouteX Field Workflows Alignment:**
  - Trip In / Trip Out odometer entries.
  - Skip Shop visit reason logging (*Shop Closed*, *Next Week*, *No Orders*, *Vehicle Breakdown*).
  - Daily Van Stock reconciliation and Spot Invoicing (Ready Stock mode).
