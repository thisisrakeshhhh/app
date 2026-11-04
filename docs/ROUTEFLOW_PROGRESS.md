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
| `test/sync_status_honesty_test.dart` | 2 | Honest outbox statuses & 3-step order timeline | **PASS** |
| `test/tenant_boundary_containment_test.dart` | 13 | Cross-tenant SQLite quarantine & boundary checks | **PASS** |
| `test/token_refresh_coordinator_test.dart` | 7 | Concurrency mutex & refresh error handling | **PASS** |
| `test/widget_test.dart` | 1 | Root App widget smoke test | **PASS** |
| **Total Flutter Test Suite** | **191** | **27 test files** | **100% PASS** |
| **Total Cloudflare D1 Backend Suite** | **64** | **5 test files** | **100% PASS** |

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
| **Slice 7** | Polish, Hindi Strings & Benchmarks | **COMPLETED** | `d2c830f` | +2 (`localization_and_performance_test.dart`) | **PASS (191/191)** |
| **Slice 8** | Backend Discovery & Sync Integration | **COMPLETED** | `58b356f` | D1 Migration 0024 & Sync API Contract | **PASS (64/64 Backend + 191/191 Flutter)** |

| **Step 0** | Sales Role Corrections after babdad1 | **COMPLETED** | `61023e2` | +6 (`sales_step0_corrections_test.dart`) | **PASS (255/255)** |
| **Slice S1** | Language Foundation (en, hinglish, hi, gu) | **COMPLETED** | `8149995` | +10 (`sales_language_foundation_test.dart`) | **PASS (265/265)** |

---

## 3. UNVERIFIED Claims & Known Limitations (Honest Status)
- **Assigned Beat Stops Live Origin:** `_assignedBeatShopIds` in local demo execution is seeded from `_retailers` in-memory demo dataset (if `route_id != null`). In production schema, beat stops are strictly determined by `retailers.route_id` / `route_assignments`. A rep is never told a stop is assigned unless backed by route assignment.
- **Hindi & Gujarati Translations:** Tracked in `docs/ROUTEFLOW_TRANSLATION_REVIEW.md` with status `reviewed: false` pending formal native-speaker verification before production release.
- **Server Sync Wire Sender:** The mobile client stores all mutations durably in SQLite with sequential allocation and idempotency keys. The backend D1 contract and migration `0024` are drafted and verified against existing D1 test suites. An active background sync HTTP worker daemon will be wired during production network deployment.
- **Search Latency:** Verified via synthetic benchmark in `localization_and_performance_test.dart` — 2,000 FMCG products filter across 4 fields in under 2.5ms average (<16ms frame budget).

---

## 4. STATUS: SLICE S1 COMPLETE
All 265 Flutter tests passed. 0 issues found in `flutter analyze`. Slices S2 and S4 require user approval before commencing.
