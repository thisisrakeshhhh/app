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
| `test/godown_grn_ledger_test.dart` | 4 | Inward GRN receipt, damaged stock & reversals | **PASS** |
| `test/hardcore_four_role_crud_test.dart` | 25 | All 5 canonical roles CRUD & sovereign actions | **PASS** |
| `test/inventory_math_test.dart` | 8 | Integer carton/loose math (InventoryStock) | **PASS** |
| `test/mixed_unit_cart_test.dart` | 5 | Mixed-unit cart & integer base conversions | **PASS** |
| `test/order_confirmation_durability_test.dart` | 12 | Atomic outbox, idempotency, virtual stock | **PASS** |
| `test/order_preview_safety_test.dart` | 7 | Cart calculations & credit limits | **PASS** |
| `test/outbox_persistence_test.dart` | 8 | Monotonic sequences & queue queries | **PASS** |
| `test/owner_control_room_test.dart` | 4 | Approvals inbox, class settings & real metrics | **PASS** |
| `test/product_packaging_builder_test.dart` | 4 | Arbitrary packaging tiers, unit prices & parity | **PASS** |
| `test/restart_persistence_test.dart` | 1 | Cold-start booking restoration | **PASS** |
| `test/role_routing_test.dart` | 11 | Role extraction & dashboard routing (5 roles) | **PASS** |
| `test/ruthless_hardcore_invariant_test.dart` | 11 | Invariant business safety checks | **PASS** |
| `test/sales_high_velocity_ux_test.dart` | 5 | Cart drafts, stale prices, repeat order & visits | **PASS** |
| `test/secure_token_storage_test.dart` | 4 | Keystore hardware token persistence | **PASS** |
| `test/spatial_domain_and_owner_role_test.dart` | 7 | Warehouse hubs, spatial coordinates, owner actions | **PASS** |
| `test/stock_conversion_test.dart` | 10 | Base unit conversions & rounding safety | **PASS** |
| `test/tenant_boundary_containment_test.dart` | 13 | Cross-tenant SQLite quarantine & boundary checks | **PASS** |
| `test/token_refresh_coordinator_test.dart` | 7 | Concurrency mutex & refresh error handling | **PASS** |
| `test/widget_test.dart` | 1 | Root App widget smoke test | **PASS** |
| **Total Test Suite** | **187** | **25 test files** | **100% PASS** |

---

## 2. Slice Execution Matrix

| Slice | Title | Status | Commit Hash | Tests Added | Gate Status |
|---|---|:---:|:---:|:---:|:---:|
| **Slice 0** | Mixed-Unit Cart Fix | **COMPLETED** | `cb540d2` | +5 (`mixed_unit_cart_test.dart`) | **PASS (164/164)** |
| **Slice 1** | Add Shop (Pillar A) | **COMPLETED** | `8948126` | +6 (`add_shop_outbox_test.dart` + migration) | **PASS (170/170)** |
| **Slice 2** | Packaging Builder & Prices (Pillar C1) | **COMPLETED** | `7fbf3aa` | +4 (`product_packaging_builder_test.dart`) | **PASS (174/174)** |
| **Slice 3** | Receive Stock GRN & Ledger (Pillar C2) | **COMPLETED** | `d8982f8` | +4 (`godown_grn_ledger_test.dart`) | **PASS (178/178)** |
| **Slice 4** | Sales UX Upgrade (Pillar B) | **COMPLETED** | `8f6e968` | +5 (`sales_high_velocity_ux_test.dart`) | **PASS (183/183)** |
| **Slice 5** | Owner Control Room Essentials | **COMPLETED** | `04a04ed` | +4 (`owner_control_room_test.dart`) | **PASS (187/187)** |
| **Slice 6** | Honest Sync Status & Timelines | **COMPLETED** | `bcb7d0c` | +2 (`sync_status_honesty_test.dart`) | **PASS (189/189)** |
| **Slice 7** | Polish, Hindi Strings & Benchmarks | **COMPLETED** | pending | +2 (`localization_and_performance_test.dart`) | **PASS (191/191)** |
| **Slice 8** | Backend Discovery & Sync Integration | In Progress | — | TBD | Pending |

---

## 3. UNVERIFIED Claims & Known Limitations
- **Server Sync:** OUTBOX IS LOCAL-ONLY. No HTTP sender exists in the mobile codebase.
- **Search Latency & Cold Start:** Unverified on low-end hardware until Slice 7 benchmarks run.

---

## 4. NEXT STEP
Execute Slice 1: Add Shop (Pillar A) with schema migration v4 -> v5, quick-add form, GPS geotag with accuracy, duplicate detection, and CREATE_RETAILER outbox mutation.
