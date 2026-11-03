# RouteFlow Master Progress Tracker

**Active Branch:** `feature/sales-inventory-shop`  
**Checkpoint Backup Branch:** `backup/pre-slices-20261103` (Commit: `3aa6248`)  
**Last Updated:** November 3, 2026

---

## 1. Baseline Test Suite Verification (Real Measured Counts)

Exact per-file count measured via regex `^\s*(test|testWidgets)\(` across all 19 test files in `flutter_distributor/test/`:

| Test File | Tests | Focus Area | Status |
|---|:---:|---|:---:|
| `test/add_shop_outbox_test.dart` | 5 | Quick-add shop, duplicate detection & outbox | **PASS** |
| `test/auth_repository_test.dart` | 11 | HTTP Auth & Token Refresh | **PASS** |
| `test/auth_service_test.dart` | 10 | Session isolation & Token lifecycle | **PASS** |
| `test/auth_ui_test.dart` | 4 | Login View UI rendering & validation | **PASS** |
| `test/database_migration_test.dart` | 7 | Drift migrations v1 through v5 | **PASS** |
| `test/delivery_safety_test.dart` | 3 | Delivery OTP & Cash custody | **PASS** |
| `test/hardcore_four_role_crud_test.dart` | 25 | All 5 canonical roles CRUD & sovereign actions | **PASS** |
| `test/inventory_math_test.dart` | 8 | Integer carton/loose math (InventoryStock) | **PASS** |
| `test/mixed_unit_cart_test.dart` | 5 | Mixed-unit cart & integer base conversions | **PASS** |
| `test/order_confirmation_durability_test.dart` | 12 | Atomic outbox, idempotency, virtual stock | **PASS** |
| `test/order_preview_safety_test.dart` | 7 | Cart calculations & credit limits | **PASS** |
| `test/outbox_persistence_test.dart` | 8 | Monotonic sequences & queue queries | **PASS** |
| `test/restart_persistence_test.dart` | 1 | Cold-start booking restoration | **PASS** |
| `test/role_routing_test.dart` | 11 | Role extraction & dashboard routing (5 roles) | **PASS** |
| `test/ruthless_hardcore_invariant_test.dart` | 11 | Invariant business safety checks | **PASS** |
| `test/secure_token_storage_test.dart` | 4 | Keystore hardware token persistence | **PASS** |
| `test/spatial_domain_and_owner_role_test.dart` | 7 | Warehouse hubs, spatial coordinates, owner actions | **PASS** |
| `test/stock_conversion_test.dart` | 10 | Base unit conversions & rounding safety | **PASS** |
| `test/tenant_boundary_containment_test.dart` | 13 | Cross-tenant SQLite quarantine & boundary checks | **PASS** |
| `test/token_refresh_coordinator_test.dart` | 7 | Concurrency mutex & refresh error handling | **PASS** |
| `test/widget_test.dart` | 1 | Root App widget smoke test | **PASS** |
| **Total Test Suite** | **170** | **21 test files** | **100% PASS** |

---

## 2. Slice Execution Matrix

| Slice | Title | Status | Commit Hash | Tests Added | Gate Status |
|---|---|:---:|:---:|:---:|:---:|
| **Slice 0** | Mixed-Unit Cart Fix | **COMPLETED** | `cb540d2` | +5 (`mixed_unit_cart_test.dart`) | **PASS (164/164)** |
| **Slice 1** | Add Shop (Pillar A) | **COMPLETED** | Pending Commit | +6 (`add_shop_outbox_test.dart` + migration) | **PASS (170/170)** |
| **Slice 2** | Packaging Builder & Prices (Pillar C1) | Pending | — | +4 planned | Pending |
| **Slice 3** | Receive Stock GRN & Ledger (Pillar C2) | Pending | — | +4 planned | Pending |
| **Slice 4** | Sales UX Upgrade (Pillar B) | Pending | — | +5 planned | Pending |
| **Slice 5** | Owner Control Room Essentials | Pending | — | +4 planned | Pending |
| **Slice 6** | Honest Sync Status & Timelines | Pending | — | +2 planned | Pending |
| **Slice 7** | Polish, Hindi Strings & Benchmarks | Pending | — | +2 planned | Pending |
| **Slice 8** | Backend Discovery & Sync Integration | Pending | — | TBD | Pending |

---

## 3. UNVERIFIED Claims & Known Limitations
- **Server Sync:** OUTBOX IS LOCAL-ONLY. No HTTP sender exists in the mobile codebase.
- **Search Latency & Cold Start:** Unverified on low-end hardware until Slice 7 benchmarks run.

---

## 4. NEXT STEP
Execute Slice 1: Add Shop (Pillar A) with schema migration v4 -> v5, quick-add form, GPS geotag with accuracy, duplicate detection, and CREATE_RETAILER outbox mutation.
