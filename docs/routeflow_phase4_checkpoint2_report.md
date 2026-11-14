# RouteFlow Phase 4 — Checkpoint 2 Implementation Report
## Products & Inventory Foundation (Reservation, Adjustment & FEFO)

**Status:** Completed & Verified  
**Branch:** `feature/sales-inventory-shop`  
**Baseline commit:** `a4eea73`  
**Test Suite Status:** 78/78 tests passing (100%), `dart analyze` 0 issues  

---

### 1. Architectural Summary & Scope Protection

Checkpoint 2 extends RouteFlow's distributor inventory architecture to support:
1. Safe Drift SQLite Schema Migration ($V6 \rightarrow V7$) adding reserved stock tracking to `inventory_snapshots` and introducing the authoritative `product_batches` table with its FEFO index.
2. Mathematically rigorous Physical Stock, Reserved Stock, and Available Stock calculations with zero floating-point arithmetic.
3. Fully auditable, immutable double-entry ledger rows in `inventory_movements` for every stock operation (`STOCK_RESERVE`, `STOCK_RELEASE`, `DISPATCH`, `ADJUSTMENT`).
4. Concurrency protection ensuring that concurrent reservation requests on the last available unit of stock never cause overselling or negative available inventory.
5. First-Expired-First-Out (FEFO) batch tracking and greedy allocation picking plans aligned with backend Cloudflare Workers D1 schema (`0014_product_batches_and_expiry.sql`).
6. Zero regression or modification to frozen Phase 3 road routing, deviation detection, or external navigation.

---

### 2. Database Migration Plan & Schema Evolution ($V6 \rightarrow V7$)

#### Existing Tables Modified:
- `inventory_snapshots`:
  - Added `reserved_cartons INTEGER NOT NULL DEFAULT 0`
  - Added `reserved_loose_pieces INTEGER NOT NULL DEFAULT 0`
  - Safe additive migration: existing rows retain physical carton and loose-piece counts unchanged.

#### New Tables Created:
- `product_batches`:
  - `id TEXT PRIMARY KEY`
  - `product_id TEXT NOT NULL REFERENCES products(id)`
  - `batch_no TEXT NOT NULL`
  - `mfg_date INTEGER` (DateTime)
  - `expiry_date INTEGER` (DateTime)
  - `rack_bin TEXT`
  - `received_quantity INTEGER NOT NULL DEFAULT 0`
  - `remaining_quantity INTEGER NOT NULL DEFAULT 0`
  - `committed_quantity INTEGER NOT NULL DEFAULT 0`
  - `status TEXT NOT NULL DEFAULT 'ACTIVE'` (`ACTIVE`, `DEPLETED`, `EXPIRED`, `RECALLED`)
  - `created_at INTEGER NOT NULL`
  - `updated_at INTEGER NOT NULL`
  - Index: `idx_batches_fefo` on `(product_id, expiry_date, remaining_quantity)`

#### Migration Mechanics:
`schemaVersion` incremented from 6 to 7 in `AppDatabase`. `onUpgrade` handles:
```dart
if (from < 7 && to >= 7) {
  await m.addColumn(inventorySnapshots, inventorySnapshots.reservedCartons);
  await m.addColumn(inventorySnapshots, inventorySnapshots.reservedLoosePieces);
  await m.createTable(productBatches);
  await customStatement(
    'CREATE INDEX IF NOT EXISTS idx_batches_fefo ON product_batches (product_id, expiry_date, remaining_quantity);'
  );
}
```

---

### 3. Mathematical Calculations & Invariants

All stock calculations use pure integer arithmetic parameterized by `boxQty` (pieces per carton):

$$\text{Physical Pieces} = (\text{godownCartons} \times \text{boxQty}) + \text{godownLoosePieces}$$
$$\text{Reserved Pieces} = (\text{reservedCartons} \times \text{boxQty}) + \text{reservedLoosePieces}$$
$$\text{Available Pieces} = \max(0, \text{Physical Pieces} - \text{Reserved Pieces})$$
$$\text{Available Boxes} = \text{Available Pieces} \mathbin{/\mkern-6mu/} \text{boxQty}$$
$$\text{Available Loose} = \text{Available Pieces} \pmod{\text{boxQty}}$$

**Domain Invariants Enforced:**
1. Available stock can never be reserved beyond $\text{Available Pieces}$. Any attempt to reserve more throws `StateError('INSUFFICIENT_STOCK: requested X pieces, but only Y available')`.
2. Stock adjustments (damages, audit reconciliation) can never reduce physical stock below currently reserved stock ($\text{Physical Pieces} \ge \text{Reserved Pieces}$).
3. When an order is fulfilled/dispatched, `commitAndDeductStock` decrements physical stock and clears the reservation simultaneously in an atomic transaction.

---

### 4. Concurrency & Race Condition Verification

In high-concurrency distributor operations, two salespeople may simultaneously submit orders for the last available carton of stock.

**Verification Mechanism (`test/inventory_foundation_phase4_test.dart`):**
- Godown stock was set to exactly 1 carton (24 pieces).
- Two concurrent asynchronous reservation tasks were launched simultaneously using `Future.wait`:
  - `attemptReservation('ORD_CONCURRENT_A')`
  - `attemptReservation('ORD_CONCURRENT_B')`
- **Result:**
  - `successCount`: Exactly 1
  - `failureCount`: Exactly 1
  - Final `availableGodownPieces`: Exactly 0 (never negative)
  - Final `godownReservedBoxes`: Exactly 1

---

### 5. FEFO (First-Expired-First-Out) Batch Management

Aligned with backend migration `0014_product_batches_and_expiry.sql`:
1. `getBatchesForProduct(productId, activeOnly: true)` sorts batches by:
   - `expiryDate ASC` (earliest expiry first; batches with null expiry sorted last)
   - `remainingQuantity DESC` (larger batch picked first to reduce fragmented inventory)
   - `createdAt ASC` (FIFO tie-breaker)
2. `planFefoPicking(productId, requiredPieces)`:
   - Greedily allocates required units across active batches starting from the earliest expiring lot.
   - Depleted batches (0 remaining) and expired batches are excluded.

---

### 6. Verification & Test Evidence

#### Automated Test Suite Execution:
- **`inventory_foundation_phase4_test.dart`**: 14/14 passed
  - Domain math (physical, reserved, available)
  - Reservation, release, and fulfillment commit
  - Negative stock prevention and overselling block
  - Concurrent race condition on last stock unit
  - FEFO sorting and greedy allocation plan
  - Expired and depleted batch exclusion
  - Drift schema v7 table and column verification
- **`database_migration_test.dart`**: 16/16 passed
  - $V1 \rightarrow V2$, $V4 \rightarrow V5$, and $V6 \rightarrow V7$ real SQLite migrations
- **Full Regression Suite**: 78/78 tests passed
  - `route_engine_phase3_test.dart` (11 tests)
  - `sales_step0_corrections_test.dart` (6 tests)
  - `role_routing_test.dart` (12 tests)
  - `sales_route_map_crud_test.dart` (8 tests)
  - `routes_and_add_shop_entry_points_test.dart` (8 tests)
  - `inventory_math_test.dart` (8 tests)
  - `outbox_persistence_test.dart` (1 test)
- **Dart Analysis**: `dart analyze` — **0 issues found**

---

### 7. Files Modified & Added

| File | Change Summary |
| --- | --- |
| `flutter/lib/domain/models/inventory_math.dart` | Added `reservedCartons`, `reservedLoosePieces`, `reservePieces`, `releaseReservation`, `commitAndDeductReserved`, and `adjustStock` |
| `flutter/lib/models/models.dart` | Added `ProductBatch`, `BatchStatus`, `BatchPickAllocation`, `godownReservedBoxes`, `godownReservedPieces`, and available stock getters on `ProductItem` |
| `flutter/lib/data/local/app_database.dart` | Incremented schema version to 7, added `reservedCartons` and `reservedLoosePieces` to `inventory_snapshots`, added `ProductBatches` table and `idx_batches_fefo` index |
| `flutter/lib/data/local/app_database.g.dart` | Regenerated Drift schema code |
| `flutter/lib/data/local/local_repository.dart` | Implemented `reserveStock`, `releaseStockReservation`, `commitAndDeductStock`, `adjustStock`, `upsertBatch`, `getBatchesForProduct`, and `planFefoPicking` |
| `flutter/lib/services/api_service.dart` | Exposed reservation, release, adjustment, and FEFO picking methods with reactive ChangeNotifier notifications |
| `flutter/test/database_migration_test.dart` | Added real $V6 \rightarrow V7$ migration test and updated schemaVersion assertions |
| `flutter/test/outbox_persistence_test.dart` | Updated `InventorySnapshotEntry` instantiation to include default reserved columns |
| `flutter/test/inventory_foundation_phase4_test.dart` | New comprehensive 14-test verification suite for Checkpoint 2 |
