# RouteFlow Phase 4 — Checkpoint 2 Verification Audit Report
## Products & Inventory Foundation (Reservation, Adjustment & FEFO)

**Audit Status:** AUDIT COMPLETED  
**Branch:** `feature/sales-inventory-shop`  
**Audited Commit:** `89f255f` (incorporating `eaa35be` plus invalid state hardening)  
**Remote Sync:** Pushed to `origin/feature/sales-inventory-shop`  
**Working Tree:** Clean  
**Frozen Phase 3 Integrity:** VERIFIED UNTOUCHED (0 changes to Phase 3 routing engine)  

---

### Executive Classification Matrix

| Category / Requirement | Classification | Scope / Environment | Verification Evidence |
| --- | --- | --- | --- |
| **Backend Reservation Authority (Client-to-Server)** | **NOT IMPLEMENTED** | Flutter $\rightarrow$ Cloudflare D1 | Flutter Checkpoint 2 methods are local-only SQLite calls; not yet wired to Outbox or direct API (scheduled for Checkpoints 5 & 6). |
| **Backend Server-Side Concurrency & Overselling** | **VERIFIED** | Cloudflare Workers / D1 (Isolated) | Ran `stress-concurrency-sync.test.mjs` (6/6 passed) under Miniflare D1; 10 simultaneous orders competing for 5 pieces resulted in exactly 5 approved, 5 rejected with 400 `INSUFFICIENT_STOCK`. |
| **Local SQLite Inventory Ledger** | **VERIFIED** | Flutter SQLite (Drift) | `STOCK_RESERVE`, `STOCK_RELEASE`, `DISPATCH`, `ADJUSTMENT` write durable double-entry rows with unique idempotency keys. |
| **Server Ledger Persistence (Checkpoint 2 methods)** | **NOT IMPLEMENTED** | Flutter $\rightarrow$ D1 | Checkpoint 2 methods do not enqueue outbox mutations or push to D1 in this phase. |
| **FEFO Sorting Policy (Expiry ASC, Qty DESC)** | **VERIFIED** | Flutter Local | Earliest expiry prioritized; batches with null expiry sorted last; ties broken by quantity and FIFO. |
| **Expired & Depleted Batch Exclusion** | **VERIFIED** | Flutter Local | Batches with `status != ACTIVE` or `remaining_quantity <= 0` are excluded from active allocation. |
| **Batch-Level Stock Reservation** | **NOT IMPLEMENTED** | Flutter Local & Server | `planFefoPicking` provides greedy allocation advice, but does NOT mutate `committed_quantity` on batch rows. |
| **Batch Network Synchronization** | **NOT IMPLEMENTED** | Flutter $\rightarrow$ Server | Batch synchronization across network is scheduled for Checkpoint 6. |
| **Stock Calculation Consistency** | **VERIFIED** | Flutter Local Domain | Pure integer carton and piece calculations; zero floating-point math. |
| **Silent Masking Prevention (`max(0, physical - reserved)`)** | **VERIFIED** | Flutter Local Domain | Hardened in `89f255f`. Constructor asserts `reserved <= physical`; getters throw `StateError` if over-reserved; `isOverReserved` exposed. |
| **Drift Schema Migration ($V6 \rightarrow V7$)** | **VERIFIED** | Flutter SQLite (Drift) | Pre-existing products, snapshots, and movements preserved 100%; `reserved_cartons`/`loose_pieces` defaulted to 0; `product_batches` table & index created. |
| **Automated Regression Suite (79/79)** | **VERIFIED** | Flutter Automated Runner | Exact execution output: `00:09 +79: All tests passed!`. |
| **Static Code Analysis** | **VERIFIED** | Dart Analyzer | `dart analyze` reports **0 issues found**. |
| **Physical Device Verification** | **NOT VERIFIED** | Vivo 1935 (Android 10) | Headless code verification only; physical device UI run deferred to Checkpoint 5 end-to-end booking. |

---

### 1. Backend Reservation Authority Audit

#### Flutter-to-Backend Path Inspection
We inspected the implementation of `reserveStock()`, `releaseStockReservation()`, `commitAndDeductStock()`, and `adjustStock()` in `LocalRepository` ([local_repository.dart](file:///d:/app/flutter/lib/data/local/local_repository.dart)):
- **Operation Type**: **Local-only operations**.
- **Outbox Backing**: None. These methods do not insert into `outbox_mutations`.
- **Direct HTTP API**: None. No network requests are dispatched by these methods.
- **D1 Synchronization**: In Checkpoint 2, local SQLite snapshot updates and movement records remain on the device.
- **Architectural Alignment**: This conforms strictly to the modular phase plan established in Checkpoint 1: Checkpoint 2 implements the local product & inventory foundation; Checkpoint 5 wires unified order booking to cart atomicity; Checkpoint 6 extends the outbox synchronization engine to push inventory adjustments and orders to D1.

#### Backend Server-Side Authority Verification
To ensure backend concurrency authority is mathematically sound and ready for Checkpoint 5/6, we ran the backend test suite in an isolated Miniflare environment with SQLite/D1 triggers:
- **Test Command**: `node test/run-isolated.mjs test/stress-concurrency-sync.test.mjs`
- **Result**: `ok 1 - RouteFlow Hardcore Stress, Concurrency & Security Penetration Suite` (6/6 passed).
- **Subtest 1 Evidence**:
  - Initial state: Product stock = 5, reserved = 0.
  - 10 simultaneous orders were fired concurrently at the exact same millisecond via `Promise.all`.
  - **Outcome**: Exactly 5 succeeded (`200 COMMITTED`), exactly 5 failed (`400 INSUFFICIENT_STOCK`).
  - D1 database trigger `trg_products_prevent_overselling` and SQL constraints prevented reserved stock from exceeding physical stock. Available stock never became negative.

---

### 2. Inventory Ledger Integrity Audit

| Operation | Local Initial Write | Durable? | Idempotent? | Reaches D1? | Retries Duplicate? | Server Reconciled? |
| --- | --- | --- | --- | --- | --- | --- |
| `STOCK_RESERVE` | `inventory_movements` | Yes (SQLite) | Yes (`reserve_{orderId}_{prodId}`) | **No** (Local-only) | No (Idempotency checked) | **No** (Pending CP6) |
| `STOCK_RELEASE` | `inventory_movements` | Yes (SQLite) | Yes (`release_{orderId}_{prodId}`) | **No** (Local-only) | No (Idempotency checked) | **No** (Pending CP6) |
| `DISPATCH` | `inventory_movements` | Yes (SQLite) | Yes (`dispatch_{orderId}_{prodId}`) | **No** (Local-only) | No (Idempotency checked) | **No** (Pending CP6) |
| `ADJUSTMENT` | `inventory_movements` | Yes (SQLite) | Yes (optional `idempotencyKey`) | **No** (Local-only) | No (Idempotency checked) | **No** (Pending CP6) |
| `INWARD` (GRN) | `inventory_movements` | Yes (SQLite) | Yes (`idempotencyKey`) | **No** (Local-only) | No (Idempotency checked) | **No** (Pending CP6) |
| `TRANSFER_TO_CAR` | `inventory_movements` | Yes (SQLite) | Yes (`idempotencyKey`) | **No** (Local-only) | No (Idempotency checked) | **No** (Pending CP6) |
| `DAMAGED_INWARD` | `inventory_movements` | Yes (SQLite) | Yes (`{idemp}_dmg`) | **No** (Local-only) | No (Idempotency checked) | **No** (Pending CP6) |

---

### 3. FEFO and Batch Consistency Audit

- **Expired Batches**: Excluded from active picking allocation (`status = 'ACTIVE'` filter and `isExpired` check). Verified in test 13 of `inventory_foundation_phase4_test.dart`.
- **Recalled / Quarantined Batches**: Excluded from active allocation (`status` must equal `'ACTIVE'`).
- **Depleted Batches**: Excluded (`remaining_quantity > 0` filter).
- **Null Expiry Dates**: Handled strictly per policy: placed last in FEFO sorting, with quantity descending as secondary tie-breaker.
- **Batch-Level Reservation**: **NOT IMPLEMENTED**. `LocalRepository.planFefoPicking` calculates the recommended picking advice list (`List<BatchPickAllocation>`), but does not mutate `committed_quantity` on `product_batches` rows. Batch commitment logic belongs to warehouse pick-pack fulfillment (scheduled for Checkpoint 7).
- **Partial Picking Duplication**: Prevented in allocation loop by tracking remaining required pieces and greedy allocation bounds.

---

### 4. Stock Calculation & Silent Masking Hardening

#### The `max(0, physical - reserved)` Defect & Resolution
- **Defect Identified**: Previously, `availablePieces` used `final net = physicalPieces - reservedPieces; return net > 0 ? net : 0;`. If an invalid state occurred where `reservedPieces > physicalPieces` (e.g. 50 reserved vs 40 physical), `availablePieces` silently returned `0`, hiding a 10-piece over-reservation from distributor monitoring.
- **Hardening Applied (Commit `89f255f`)**:
  1. `InventoryStock` constructor assertion:
     ```dart
     assert(
       (reservedCartons * piecesPerCarton) + reservedLoosePieces <= (cartons * piecesPerCarton) + loosePieces,
       'Reserved stock cannot exceed physical stock',
     );
     ```
  2. Invariant Violation Rejection in `availablePieces`:
     ```dart
     if (reservedPieces > physicalPieces) {
       throw StateError(
         'INVALID_INVENTORY_STATE: Reserved stock ($reservedPieces pieces) exceeds physical stock ($physicalPieces pieces). '
         'Over-reservation must not be silently masked by max(0, physical - reserved).',
       );
     }
     ```
  3. Diagnostic Inspection Getters: `isOverReserved` and `overReservedPieces` exposed on both `InventoryStock` and `ProductItem`.
  4. Regression Test: Added test 6 in `inventory_foundation_phase4_test.dart` verifying that over-reserved states throw errors and cannot be silently concealed.

#### Migration Safety ($V6 \rightarrow V7$)
- Tested in `database_migration_test.dart` test 8.
- Real SQLite database with V6 schema populated with products and snapshots migrated to V7:
  - `prod_v6_biscuit` had 25 cartons in V6.
  - After migration to V7: physical cartons remained 25, `reserved_cartons` became 0, `availableGodownBoxes` remained 25. Zero data was wiped or reset.

---

### 5. Test Reconciliation & Exact Runner Output

#### Explanation of Previous Test Count Discrepancy
In the initial Checkpoint 2 implementation report, the full regression suite reported `00:20 +78: All tests passed!`, while the narrative prose gave an approximate breakdown totaling 84 tests. We individually ran every test file and captured the exact test count per suite:

| Test Suite | File Path | Actual Test Count | Status |
| --- | --- | :---: | :---: |
| Inventory Foundation Phase 4 | `test/inventory_foundation_phase4_test.dart` | **15** | PASSED |
| Database Migration ($V1 \rightarrow V7$) | `test/database_migration_test.dart` | **8** | PASSED |
| Inventory Math Integer Precision | `test/inventory_math_test.dart` | **8** | PASSED |
| Real Road Route Engine (Phase 3) | `test/route_engine_phase3_test.dart` | **12** | PASSED |
| Sales Step 0 & Domain Invariants | `test/sales_step0_corrections_test.dart` | **8** | PASSED |
| Role Routing & Permission Matrix | `test/role_routing_test.dart` | **11** | PASSED |
| Sales Route Map & CRUD | `test/sales_route_map_crud_test.dart` | **4** | PASSED |
| Routes & Add Shop Entry Points | `test/routes_and_add_shop_entry_points_test.dart` | **5** | PASSED |
| Outbox Local Persistence | `test/outbox_persistence_test.dart` | **8** | PASSED |
| **Combined Regression Suite Total** | | **79** | **ALL PASSED** |

*(Note: Prior to adding the invalid state detection test, the count was 14 in the first file, totaling exactly 78 tests. With the new test added, the total is exactly 79).*

#### Exact Command & Final Output
```powershell
$env:TMP = "D:\tmp"; $env:TEMP = "D:\tmp"; cd flutter; flutter test test/inventory_foundation_phase4_test.dart test/route_engine_phase3_test.dart test/sales_step0_corrections_test.dart test/role_routing_test.dart test/sales_route_map_crud_test.dart test/routes_and_add_shop_entry_points_test.dart test/database_migration_test.dart test/inventory_math_test.dart test/outbox_persistence_test.dart
```
**Output:**
```text
00:09 +79: All tests passed!
```

**Static Analysis:**
```powershell
$env:TMP = "D:\tmp"; $env:TEMP = "D:\tmp"; cd flutter; dart analyze
```
**Output:**
```text
Analyzing flutter...
No issues found!
```

---

### 6. Git State Verification

- **Current HEAD Commit**: `89f255f` (`fix(inventory): prevent silent masking of over-reserved inventory and enforce state rejection`)
- **Baseline Commit for Checkpoint 2**: `eaa35be` (`feat(phase4): implement Checkpoint 2 products and inventory foundation with reserved stock and FEFO`)
- **Remote Tracking**: `origin/feature/sales-inventory-shop` is at `89f255f` (Up to date).
- **Working Tree**: Completely clean (0 uncommitted files, 0 untracked files).
- **Frozen Phase 3 Road Route Engine**: Untouched. Commit history and diff show zero modifications to `route_engine_service.dart`, `route_deviation_detector.dart`, `route_cache_repository.dart`, or `navigation_launcher.dart`.

---

### 7. Remaining Gaps & Checkpoint Boundary

1. **Gaps Acknowledged for Subsequent Checkpoints**:
   - Checkpoint 3: Retailer master data, phone normalization, classification alignment.
   - Checkpoint 4: Add Shop workflow synchronization with Outbox.
   - Checkpoint 5: Wire sales cart order creation to atomic inventory reservation (`LocalRepository.reserveStock`).
   - Checkpoint 6: Extend Outbox to push `STOCK_ADJUSTMENT`, `STOCK_RESERVE`, and `STOCK_RELEASE` mutations to Cloudflare Workers D1.
   - Checkpoint 7: Wire warehouse batch pick-pack fulfillment to mutate batch-level `committed_quantity`.
2. **Checkpoint 3 Status**: Not started. Awaiting audit review.
