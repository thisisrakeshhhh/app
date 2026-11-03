# RouteFlow Phase O1.1 — Order Confirmation Integration Architecture & Implementation Plan (Final Clarifications)

**Document Version:** 1.3.0  
**Status:** Architectural Plan (Planning Only — Zero Implementation)  
**Execution Boundary:** Zero code modifications, zero test changes, zero migrations, zero database writes, zero Git commits or pushes.  
**Prerequisite:** Phase O1 (Durable Local Outbox) — CLOSED  
**Target Platform:** Flutter Pilot (`flutter_distributor`), Drift SQLite (`AppDatabase`, `OutboxDao`)  

---

## 1. Executive Summary & Objective

Phase O1.1 bridges the verified Phase O1 `OutboxDao` with the FMCG sales workflow. It ensures that an explicit order confirmation in the sales UI writes a durable, provisional `CREATE_ORDER` outbox record on SQLite disk, while keeping cart exploration volatile in RAM and leaving authoritative physical stock and retailer credit untouched.

### Core Invariants Enforced:
1. **Durable Order Intent:** Explicit confirmation writes an immutable `CREATE_ORDER` mutation to `outbox_mutations`.
2. **Cold Boot & Restart Reconstruction:** On application restart or process revival, pending `CREATE_ORDER` outbox records are reconstructed into in-memory `DistributorOrder` objects (stage: `booking`), visibly populating the sales stream and restoring virtual stock reservations.
3. **Atomic Sequence Integrity & Concurrency:** Sequence allocation and mutation insertion execute inside the same SQLite write transaction, backed by a composite unique index `(organization_id, sequence_order)` and deterministic tie-breaker query ordering (`sequence_order ASC, created_at_epoch_ms ASC, id ASC`).
4. **Idempotency Payload Mismatch Guard:** A retry with an existing idempotency key verifies that the stored payload matches the attempted payload; any mismatch fails closed with `IdempotencyPayloadMismatchException`.
5. **Reservation Lifecycle:** Virtual reservations are active during local booking, released on cancellation or permanent rejection, and handed over upon server acknowledgment without double-counting.
6. **Financial Snapshot Completeness:** Preserves integer-paise calculations, selected unit basis, packaging ratios, and line-item tax allocations for exact post-catalogue reconstruction.
7. **Provisional Identifiers:** Local orders are prefixed with `LOCAL-ORD-`, distinguishing them from authoritative server-issued order numbers.
8. **No Cart-Content False Deduplication:** `idempotencyKey` is a cryptographically random UUIDv4 bound to the checkout review session; successive identical orders commit cleanly without collision.
9. **Role as Non-Authoritative Metadata:** `userRole` in the payload is historical audit metadata only; authorization is enforced strictly by server-side JWT claims upon future sync.
10. **Strict Financial & Inventory Protection:** Authoritative physical stock in `InventorySnapshots` and retailer debt in `Retailers.outstandingPaise` are **never touched** by provisional bookings; reservations remain strictly virtual in RAM.
11. **B1 Compatibility & Offline Boundary:** Preserves synchronous `ApiService.placeOrder()` for existing unit tests; initiates zero network requests.

---

## 2. Sequence Integrity & Concurrency Architecture

### 2.1 Concurrency Model in SQLite
SQLite enforces a **single-writer serialization model** via WAL locking. When `db.transaction(() async { ... })` begins an immediate write transaction, SQLite acquires a RESERVED/EXCLUSIVE lock. Concurrent writes from background isolates or UI threads are serialized automatically by the SQLite engine.

### 2.2 In-Transaction Sequence Allocation
To prevent sequence race conditions, sequence calculation and row insertion are executed inside the exact same atomic transaction block:

```dart
Future<OutboxMutationEntry> insertOrderMutationAtomic({
  required String organizationId,
  required String userId,
  required String idempotencyKey,
  required String mutationType,
  required String payloadJson,
  required String provisionalBusinessId,
  required int createdAtEpochMs,
}) async {
  return db.transaction(() async {
    // 1. Transactionally locked sequence allocation
    final maxExp = db.outboxMutations.sequenceOrder.max();
    final query = selectOnly(db.outboxMutations)
      ..addColumns([maxExp])
      ..where(db.outboxMutations.organizationId.equals(organizationId));
    final result = await query.getSingle();
    final nextSeq = (result.read(maxExp) ?? 0) + 1;

    // 2. Insert mutation record
    final companion = OutboxMutationsCompanion.insert(
      id: 'out_' || uuid.v4(),
      organizationId: organizationId,
      userId: userId,
      idempotencyKey: idempotencyKey,
      mutationType: mutationType,
      payloadJson: payloadJson,
      sequenceOrder: nextSeq,
      provisionalBusinessId: drift.Value(provisionalBusinessId),
      createdAtEpochMs: createdAtEpochMs,
    );

    await into(db.outboxMutations).insert(companion);
    return companion;
  });
}
```

### 2.3 Database-Enforced Sequence Uniqueness
To enforce uniqueness at the database level without requiring an unreviewed schema version bump to v4, the application executes an additive custom index in `AppDatabase.beforeOpen`:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_outbox_org_seq 
ON outbox_mutations (organization_id, sequence_order);
```
- **Safety Proof:** Because table `outbox_mutations` was freshly introduced in Schema v3 (Phase O1), applying this unique index creates zero risk of constraint violation against legacy B1 data.
- **Concurrency Behavior:** If two concurrent transactions ever attempted to commit the same sequence number for an organization, SQLite's unique constraint immediately rolls back the second transaction, eliminating ambiguous ordering.

### 2.4 Stable Tie-Breaker Queue Ordering
To eliminate reliance on mutable SQLite internal rowids, all outbox queue queries enforce **Deterministic Multi-Column Ordering** using the stable mutation UUID string `id`:
```sql
SELECT * FROM outbox_mutations 
WHERE organization_id = :org_id AND user_id = :user_id 
  AND sync_status IN ('PENDING', 'RETRYABLE_FAILURE')
ORDER BY sequence_order ASC, created_at_epoch_ms ASC, id ASC;
```

---

## 3. Complete Financial & Unit Snapshot Specification

The outbox mutation's `payload_json` contains an immutable financial and packaging snapshot. All monetary values are represented strictly in integer Paise (`INR`, 1 Rupee = 100 Paise) to eliminate floating-point precision loss.

```json
{
  "provisionalOrderId": "ord_1700000000123_3f2a",
  "orderNumber": "LOCAL-ORD-849201-3F2A",
  "idempotencyKey": "b3e2b4d1-8b29-4d8e-9f01-2a3b4c5d6e7f",
  "organizationId": "org_jaipur_fmcg",
  "userId": "usr_sales_ramesh",
  "userRole": "SALES",
  "retailer": {
    "id": "ret_ganesh_01",
    "name": "Shree Ganesh Kirana",
    "ownerName": "Ramprasad Sharma",
    "phone": "+91 98290 12345",
    "address": "Shop 12, Johari Bazar",
    "area": "Johari Bazar"
  },
  "items": [
    {
      "productId": "prod_kurkure_01",
      "productName": "Kurkure Masala Munch",
      "orderedUnit": "box",
      "orderedQuantity": 2,
      "stripQty": 10,
      "boxQty": 50,
      "totalPieces": 100,
      "unitPricePaiseAtTime": 80000,
      "piecePricePaiseAtTime": 1600,
      "mrpRupeesAtTime": 20.0,
      "gstRateAtTime": 18.0,
      "discountPaise": 0,
      "taxableAmountPaise": 135593,
      "gstAmountPaise": 24407,
      "lineTotalPaise": 160000,
      "freeQuantity": 0
    }
  ],
  "totals": {
    "totalAmountPaise": 160000,
    "taxableAmountPaise": 135593,
    "gstAmountPaise": 24407,
    "discountAmountPaise": 0
  },
  "paymentMode": "Credit",
  "assignedCarNumber": "RJ-19-GB-4021",
  "clientCreatedAtEpochMs": 1700000000123
}
```

### 3.1 Financial Rounding & Tax Calculation Basis
- **Base Rounding Rule:** Integer division with standard half-up rounding to the nearest Paisa:
  $$\text{netTaxablePaise} = \left\lfloor \frac{(\text{lineTotalPaise} - \text{discountPaise}) \times 10000 + \frac{10000 + \text{gstRate} \times 100}{2}}{10000 + \text{gstRate} \times 100} \right\rfloor$$
  $$\text{gstAmountPaise} = (\text{lineTotalPaise} - \text{discountPaise}) - \text{netTaxablePaise}$$
- **Post-Catalogue Invariant:** If central warehouse master data alters Kurkure packaging from 50 to 48 pieces/box or raises prices, local reconstruction re-reads `orderedUnit` (`box`), `orderedQuantity` (`2`), `stripQty` (`10`), and `boxQty` (`50`) directly from the immutable payload, guaranteeing exact piece and tax reconstruction.

---

## 4. Idempotency Payload Mismatch & Recovery Flow

```
Review Sheet Opens -> Generates checkoutIdempotencyKey (UUIDv4)
 │
 ├── Salesperson taps "Confirm Booking"
 │    │
 │    ├── UI Mutex: If _isSubmitting == true -> Drop tap
 │    ├── Set _isSubmitting = true
 │    │
 │    └── Step 1: Pre-Check Existing Key in SQLite
 │         │
 │         ├── Lookup outboxDao.getMutationByIdempotencyKey(checkoutIdempotencyKey)
 │         │
 │         ├── CASE A: Key Exists in SQLite
 │         │   │
 │         │   ├── Sub-case A1: Payload Matches (SHA-256 / Canonical JSON Match)
 │         │   │   ├── Safe Idempotent Replay
 │         │   │   ├── Reconstruct DistributorOrder from stored payload_json
 │         │   │   ├── Ensure order present in in-memory _orders
 │         │   │   ├── Clear in-memory _cart
 │         │   │   ├── Set _isSubmitting = false
 │         │   │   └── Return success toast: "[RECOVERED] Order LOCAL-ORD-... booked"
 │         │   │
 │         │   └── Sub-case A2: Payload Differs (Payload Tampering / Key Collision)
 │         │       ├── FAIL CLOSED IMMEDIATELY
 │         │       ├── Throw IdempotencyPayloadMismatchException
 │         │       ├── Cart preserved; no order created or modified
 │         │       ├── Set _isSubmitting = false
 │         │       └── Show Error Alert: "Idempotency conflict: key reused with modified payload."
 │         │
 │         └── CASE B: Key Does NOT Exist
 │             │
 │             ├── Execute db.transaction(...) -> Writes Outbox Row
 │             │
 │             ├── Failure Point 1: Process dies during SQLite write
 │             │   └── SQLite transaction rolls back. Cart intact. Zero outbox rows.
 │             │
 │             ├── Failure Point 2: Process dies AFTER SQLite commit, BEFORE UI callback
 │             │   ├── Outbox row is DURABLE ON DISK.
 │             │   └── App relaunch triggers Startup Reconstruction (Section 5).
 │             │
 │             └── Normal Path: Write succeeds
 │                 ├── Construct in-memory DistributorOrder
 │                 ├── Prepend to _orders (stage: booking)
 │                 ├── Clear _cart
 │                 ├── Set _isSubmitting = false
 │                 └── Show Success Toast & Dismiss Sheet
```

### 4.1 Protection Against Cart-Content False Deduplication:
- The `idempotencyKey` is **never a hash of cart items**.
- It is generated as a cryptographically random UUIDv4 when the review bottom sheet is initialized.
- If a salesperson legitimately places two identical back-to-back orders for 2 boxes of Kurkure for the same shop, the second checkout generates a fresh UUIDv4. Both orders commit as distinct outbox mutations and distinct bookings without collision.

---

## 5. Reservation Lifecycle & De-Duplication Invariant

```
┌────────────────────────────────────────────────────────────────────────┐
│                      RESERVATION STATE MACHINE                         │
├─────────────────────────┬──────────────────────────────────────────────┤
│ State                   │ Virtual Reservation Impact                   │
├─────────────────────────┼──────────────────────────────────────────────┤
│ 1. Local Booking        │ Order in _orders with stage == booking.      │
│    (Pending Outbox)     │ Contributes to pendingBookingPieces(p).      │
│                         │ Physical InventorySnapshots UNCHANGED.       │
│                         │ Retailers.outstandingPaise UNCHANGED.        │
├─────────────────────────┼──────────────────────────────────────────────┤
│ 2. Local Cancellation   │ User cancels before sync. Order stage marked │
│                         │ cancelled. pendingBookingPieces(p) released. │
│                         │ Outbox mutation marked FAILED_PERMANENT.     │
├─────────────────────────┼──────────────────────────────────────────────┤
│ 3. Server Rejection     │ Server rejects booking during sync.          │
│                         │ Stage marked rejected. Reservation released. │
│                         │ Outbox mutation marked FAILED_PERMANENT.     │
├─────────────────────────┼──────────────────────────────────────────────┤
│ 4. Server Acknowledged  │ Server commits order and decrements remote   │
│    (COMMITTED / SYNCED) │ inventory. Order stage transitions to        │
│                         │ approved / confirmed.                        │
│                         │ Order is REMOVED from bookingOrders filter.  │
│                         │ Zero double-counting between local & remote! │
└─────────────────────────┴──────────────────────────────────────────────┘
```

---

## 6. Testing & Verification Matrix (Phase O1.1 Test Suite)

Dedicated test file: `flutter_distributor/test/order_confirmation_durability_test.dart`

| Test Scenario | Verification Focus | Observable Assertion |
| :--- | :--- | :--- |
| **TEST-01: Commit-before-UI-Success** | Process dies immediately after SQLite write | Outbox row exists; next launch reconstructs `DistributorOrder` and virtual reservation. |
| **TEST-02: App Restart Reconstruction** | Cold boot hydrates outbox records | Close DB $\to$ reopen $\to$ run `_syncFromDatabase()` $\to$ `_orders` has recovered orders. |
| **TEST-03: Retry with Same Key & Payload** | Safe replay on retry | Second call returns existing order (`idempotentReplay=true`); outbox row count remains 1. |
| **TEST-04: Mismatched Payload with Same Key** | Payload mismatch security guard | Submitting key with altered quantity throws `IdempotencyPayloadMismatchException`. |
| **TEST-05: Genuinely New Identical Orders** | Two identical back-to-back orders | Two checkout sessions produce two distinct UUIDs and two distinct outbox rows. |
| **TEST-06: Concurrent Confirmations** | Two racing async confirmations | Transactions serialize; receive monotonic sequence numbers (`seq=1`, `seq=2`); tie-breaker ordering preserves deterministic order. |
| **TEST-07: Financial & Stock Isolation** | Non-destructive invariant | `InventorySnapshots.godownCartons` and `Retailers.outstandingPaise` in SQLite are strictly unchanged. |
| **TEST-08: Packaging Ratio Preservation** | Catalogue change after booking | Reconstructed order retains original entered unit, entered quantity, and piece count. |
| **TEST-09: Reservation Lifecycle Transition** | Cancelled order releases pieces | Cancelling a booking immediately restores `availableGodownPieces`. |
| **TEST-10: Session Identity Enforcement** | Unauthenticated user attempts confirm | Throws `UnauthenticatedException`; zero SQLite rows written. |
| **TEST-11: Zero Network Activity** | Strict offline execution | `ZeroNetworkHttpOverrides` asserts zero HTTP client requests. |
| **TEST-12: Existing B1 Compatibility** | Synchronous `placeOrder()` regression | All 133 existing Flutter tests continue passing 100%. |

---

## 7. Unresolved Implementation Dependencies

Before Phase O1.1 implementation begins:
1. **`ApiService` Session Provider Injection:** `ApiService` will accept an optional `UserSession? Function()? sessionProvider` in its constructor (defaulting to `AuthService.currentSession` in production, with mock fixtures for unit tests).
2. **Review Bottom Sheet Context Wiring:** `sales_view.dart` and `sales_subviews.dart` bottom sheets must hold `checkoutIdempotencyKey` in their local widget `State` to support retry debouncing.
3. **No Database Migration Required:** Schema remains at version 3; composite unique index `idx_outbox_org_seq` is executed safely via custom statement in `beforeOpen`.

---

## 8. Implementation Boundary Confirmation

> [!IMPORTANT]
> **Implementation Has NOT Started:**
> This task was executed strictly as a planning refinement.
> - Zero application source files have been modified.
> - Zero test files have been created or modified.
> - Zero migrations or database operations have been executed.
> - Git working tree state is 100% preserved.
>
> Implementation will begin only upon receiving explicit user authorization.
