# RouteFlow Phase 3.8 — Final Backend Integrity Review

**Audit Timestamp:** 2026-10-19T19:13:00+05:30  
**Repository Working Directory:** `d:\app`  
**Baseline Git Commit:** `31706b1`  
**Execution Constraints:** Pure static source inspection and targeted schema/code edits. Zero runtime executions, builds, tests, migrations, dev servers, deployments, or database writes.

---

## 1. Executive Summary & Verification Classification

Phase 3.8 represents the final backend integrity review prior to Phase 4 (Mobile Van-Sales UI construction). This phase rigorously audited the newly introduced `van_stock_deductions` schema, purged unsafe compatibility fallbacks, verified all 7 tables involved in credit and payment lifecycles, and closed tenant-scoping gaps.

### Summary of Discovered Defects & Fixes:
1. **`van_stock_deductions` Schema & Trigger Incompleteness**:
   - *Defect*: Migration 0021 did not store `product_id` on deduction records and did not verify whether the allocation belonged to the referenced trip or product. It also did not verify that the referenced `order_id` matched the company or trip, nor did it prevent duplicate deduction rows for the same order and allocation.
   - *Fix*: Added `product_id` column, foreign key, index, and `CONSTRAINT uq_van_stock_deduction_order_alloc UNIQUE (order_id, allocation_id)`. Hardened `trg_van_stock_deduction_guard` with 4 explicit checks: (1) Allocation exists with matching `company_id`, `trip_id`, and `product_id`; (2) Allocation is active (`ALLOCATED` or `IN_TRANSIT`); (3) Allocation has remaining stock $\ge \text{quantity}$; (4) Order exists with matching `company_id` and `trip_id`.
2. **Unsafe Silent Compatibility Fallback Removed**:
   - *Defect*: `POST /van-sales/orders` and `POST /van-sales/orders/:id/confirm` in `backend/src/index.ts` fell back to raw `UPDATE van_stock_allocations` if the `van_stock_deductions` table was missing. This silent fallback re-opened the zero-row D1 batch commit hazard on unmigrated databases.
   - *Fix*: Replaced fallback with strict fail-closed operational check. If either `van_stock_deductions` table or trigger `trg_van_stock_deduction_guard` is missing from `sqlite_master`, the request immediately halts with HTTP 503 (`SCHEMA_MIGRATION_REQUIRED`).
3. **Missing Tenant Qualification in Retailer Subqueries**:
   - *Defect*: `backend/src/daily-cycle.ts` executed subqueries `SELECT ... FROM retailers WHERE id = ?` in collection reversals (line 143) and return credit notes (lines 333, 342) without `AND company_id = ?`.
   - *Fix*: Added `AND company_id = ?` and bound `u.company_id` across all three queries.

---

## 2. Deep Audit of `van_stock_deductions` Schema & Call Sites

We inspected the complete migration 0021 schema in [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql) and every application call site in `backend/src/index.ts`.

### 2.1 Verification Checklist:

| Invariant Requirement | Verification Proof | Database Enforcement Mechanism | Static Verification Status |
| :--- | :--- | :--- | :---: |
| **1. Company, Trip, Order, Product, and Allocation References** | Deduction row contains `id`, `company_id`, `trip_id`, `allocation_id`, `order_id`, `product_id`, `quantity`, `created_at`. Foreign keys reference `companies`, `delivery_trips`, `van_stock_allocations`, `orders`, and `products`. | Schema definition in migration 0021. | **Source fix made — not runtime-verified** |
| **2. Allocation Belongs to Referenced Trip and Product** | Trigger `trg_van_stock_deduction_guard` Check 1 queries: `WHERE a.id = NEW.allocation_id AND a.company_id = NEW.company_id AND a.trip_id = NEW.trip_id AND a.product_id = NEW.product_id`. | Trigger raises `RAISE(ABORT, 'Van stock allocation not found or trip/product mismatch for tenant')`. | **Source fix made — not runtime-verified** |
| **3. Permitted Allocation States Only** | Trigger Check 2 queries: `WHERE a.id = NEW.allocation_id AND a.company_id = NEW.company_id AND a.status IN ('ALLOCATED', 'IN_TRANSIT')`. | Trigger raises `RAISE(ABORT, 'Van stock allocation is not active for delivery')`. | **Source fix made — not runtime-verified** |
| **4. Positive Quantity & Stock Remaining Guard** | Table constraint `CHECK(quantity > 0)`. Trigger Check 3 verifies `(a.allocated_qty - a.delivered_qty) >= NEW.quantity`. | Trigger raises `RAISE(ABORT, 'Insufficient van stock on allocation row')`. Second-line defense: `van_stock_allocations` table constraint `CHECK(delivered_qty <= allocated_qty)`. | **Source fix made — not runtime-verified** |
| **5. Duplicate Deductions Prevention** | Table constraint `CONSTRAINT uq_van_stock_deduction_order_alloc UNIQUE (order_id, allocation_id)`. Trigger Check 4 ensures order exists and matches trip. | SQLite unique index aborts batch if an order attempts to deduct the same allocation row twice. | **Source fix made — not runtime-verified** |
| **6. Deduction Row & `delivered_qty` Update Consistency** | Trigger `trg_van_stock_deduction_apply` fires `AFTER INSERT ON van_stock_deductions` and updates `van_stock_allocations SET delivered_qty = delivered_qty + NEW.quantity`. | Atomic trigger execution in the same SQLite transaction. | **Source fix made — not runtime-verified** |
| **7. Idempotency Key Replay Safety** | `idempotency_records` table check runs before batch execution; returns cached payload on duplicate request hash. If batch fails, catch block checks for existing key. | `idempotencyKey` unique index prevents dual execution. | **Confirmed by static inspection** |
| **8. Differing Keys Quantity Guard** | `orders.id` primary key collision on direct spot-bill, `trg_order_status_transition_guard` on confirmation (aborts `DELIVERED -> DELIVERED`), and `van_stock_deductions` unique constraint prevent quantity bypass. | Multiple database triggers abort racing batches. | **Confirmed by static inspection** |
| **9. Atomic Batch Writes** | Order, items, deductions, invoice, retailer balance, Khata ledger, and idempotency records all executed inside `c.env.DB.batch(statements)`. | Cloudflare D1 batch serialization commits all or rolls back all on `RAISE(ABORT)`. | **Confirmed by static inspection** |

---

## 3. Removal of Unsafe Compatibility Behavior

### The Problem:
In Phase 3.7, handlers contained a dynamic check:
```typescript
if (hasDeductionsTable) {
  // insert into van_stock_deductions
} else {
  // raw conditional update on van_stock_allocations
}
```
If migration 0021 was not yet executed, the system silently degraded to the vulnerable direct `UPDATE` mode, where a zero-row match would commit financial entries without deducting vehicle stock.

### The Remediation:
In [`backend/src/index.ts:2730-2745`](file:///d:/app/backend/src/index.ts#L2730-L2745) and [`backend/src/index.ts:3120-3135`](file:///d:/app/backend/src/index.ts#L3120-L3135), the fallback logic was eliminated entirely:

```typescript
if (!isProvisional) {
  const hasDeductionsTable = await c.env.DB.prepare(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name='van_stock_deductions'"
  ).first().catch(() => null);
  const hasDeductionsGuard = await c.env.DB.prepare(
    "SELECT 1 FROM sqlite_master WHERE type='trigger' AND name='trg_van_stock_deduction_guard'"
  ).first().catch(() => null);

  if (!hasDeductionsTable || !hasDeductionsGuard) {
    return c.json({
      error: 'Operational failure: required zero-row deduction guard schema (van_stock_deductions / trg_van_stock_deduction_guard) is missing from database. Van sales rejected to prevent silent stock corruption.',
      code: 'SCHEMA_MIGRATION_REQUIRED'
    }, 503);
  }
}
```
Now, if either the table or its guard trigger is absent, the backend fails closed immediately with HTTP 503.

---

## 4. Comprehensive Audit of Credit & Payment Lifecycle

We audited every `INSERT`, `UPDATE`, and `DELETE` across the 7 core tables:
1. `orders`
2. `credit_reservations`
3. `retailers.outstanding_amount_paise`
4. `invoices`
5. `payments` / `collections`
6. `payment_ledger` / `retailer_ledgers`
7. `van_stock_deductions`

### 4.1 Lifecycle Operations Trace:

| Lifecycle Path | Balance & Ledger Effect | Reservation Effect | Invariant Integrity & Tenant Isolation |
| :--- | :--- | :--- | :--- |
| **Normal Delivery** (`PUT /orders/:id/deliver`) | Credit sale: `retailers.outstanding_amount_paise += deliveredAmountPaise`. Cash sale: outstanding unchanged. Invoices created (`ISSUED` or `PAID`). `payment_ledger` and `retailer_ledgers` receive atomic rows. | Trigger `release_order_credit` deletes reservation row upon status change to `DELIVERED`. Net exposure change is $\le 0$. | Tenant checked (`WHERE id = ? AND company_id = ?`). Transition guarded by `trg_order_status_transition_guard`. |
| **Failed Delivery & Retry** (`POST /orders/:id/retry-delivery`) | Balance unchanged. Invoices not created. | Delivery failure preserves reservation. On retry, `evaluateCreditPolicy()` excludes current order (`WHERE order_id != ?`), preventing double-counting. | Re-validates total exposure against limit before re-dispatching. |
| **Provisional Van Sale** (`POST /van-sales/orders`, `isProvisional = true`) | Balance unchanged. No invoices. Status `SUBMITTED`. | Trigger `reserve_order_credit` creates reservation. | Validates vehicle custody and tenant membership. |
| **Provisional Confirmation** (`POST /van-sales/orders/:id/confirm`) | Balance debited for credit sales. Invoice created. Deductions inserted into `van_stock_deductions`. | Trigger `release_order_credit` deletes reservation on transition to `DELIVERED`. Net exposure change is 0. | Status transition `SUBMITTED -> DELIVERED` permitted only for `is_van_sale = 1`. Guarded by triggers. |
| **Immediate Van Spot-Bill** (`POST /van-sales/orders`, `isProvisional = false`) | Balance debited directly on credit sales. Invoices created. Deductions inserted into `van_stock_deductions`. | Direct spot-bills skip `SUBMITTED`. No reservation created. | Trigger `trg_spot_bill_credit_guard` verifies credit limit on statement 1 before balance or deduction writes. |
| **Cash / UPI Sales** | Outstanding balance untouched. Invoices created as `PAID`. | No credit reservations created. | Invariant: Exposure change is 0. |
| **Collection & Settlement** (`POST /collections`, `/collections/:id/review`) | Cash: settled immediately, balance credited (`outstanding_amount_paise -= amount`). Non-cash: entered pending clearance; balance credited only upon `VERIFIED` or `CLEARED`. | N/A (Orders already delivered). | Allocation guard ensures allocated amount does not exceed invoice unpaid balance. |
| **Collection Reversal** (`POST /collections/:id/review` `action = 'REVERSE'`) | Reverses settled collection: `outstanding_amount_paise += amount`. Invoices re-opened to `ISSUED`. | N/A. | **Phase 3.8 Fix Applied**: Added `AND company_id = ?` to `FROM retailers` query. Custody check ensures cash was not already handed over. |
| **Customer Returns & Credit Notes** (`POST /return-requests/:id/step`) | Balance credited: `outstanding_amount_paise -= totalCreditNotePaise`. Credit note created. | N/A. | **Phase 3.8 Fix Applied**: Added `AND company_id = ?` to `FROM retailers` query. Validates original invoice and order. |
| **Authorized Credit Overrides** | Does not alter retailer permanent limit. Order-specific override stored in `orders.credit_override_paise` and logged to `credit_overrides`. | Evaluated in triggers and `evaluateCreditPolicy()`. | Strictly restricted to `OWNER` / `ADMIN` roles; client-supplied approver ID ignored in favor of authenticated `user.sub`. |

---

## 5. Explicit Status Classifications

| Component / Finding | Classification | References |
| :--- | :---: | :--- |
| `van_stock_deductions` schema hardening (`product_id`, unique constraint, trip/product/order triggers) | **Source fix made — not runtime-verified** | [`backend/migrations/0021_van_stock_lifecycle_guards.sql:81-145`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql#L81-L145) |
| Fail-closed operational check (elimination of unsafe fallback) in `POST /van-sales/orders` | **Source fix made — not runtime-verified** | [`backend/src/index.ts:2730-2745`](file:///d:/app/backend/src/index.ts#L2730-L2745) |
| Fail-closed operational check (elimination of unsafe fallback) in `POST /van-sales/orders/:id/confirm` | **Source fix made — not runtime-verified** | [`backend/src/index.ts:3120-3135`](file:///d:/app/backend/src/index.ts#L3120-L3135) |
| Tenant qualification in payment reversals and return notes | **Source fix made — not runtime-verified** | [`backend/src/daily-cycle.ts:143, 333, 342`](file:///d:/app/backend/src/daily-cycle.ts#L143) |
| Spot-bill fail-closed credit guard trigger | **Confirmed by static inspection** | [`backend/migrations/0021_van_stock_lifecycle_guards.sql:36-76`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql#L36-L76) |
| Delivery retry credit reservation double-count fix | **Confirmed by static inspection** | [`backend/src/index.ts:1734`](file:///d:/app/backend/src/index.ts#L1734) |
| Zero-Row D1 batch abort mechanics via `INSERT` triggers | **Confirmed by static inspection** | Detailed in Section 2 of this document |
| Lifecycle credit exposure invariants across all 8 paths | **Confirmed by static inspection** | Detailed in Section 4 of this document |
| Mobile offline UI screens & Repository enqueue call sites | **Documented but unresolved** | Deferred to Phase 4 |
| Cloudflare D1 local transaction rollback verification | **Requires isolated runtime verification** | Requires Miniflare/Vitest execution when tests unlocked |

---

## 6. Migration Prerequisites & Upgrade Plan

1. **Historical Migrations (0001 - 0019)**: Must remain completely untouched. Migration 0019 is restored to baseline.
2. **Forward Migration 0020 (`0020_van_sales_state_machine.sql`)**: Must be executed first to update `trg_order_status_transition_guard` so provisional van sales can transition from `SUBMITTED` to `DELIVERED`.
3. **Forward Migration 0021 (`0021_van_stock_lifecycle_guards.sql`)**: Must be executed next to create `van_stock_deductions`, attach deduction triggers, attach allocation status triggers, and attach `trg_spot_bill_credit_guard`.
4. **Zero Downtime / Rollback Safety**: If migration 0021 has not yet run, the backend will reject van-sales write endpoints with HTTP 503 (`SCHEMA_MIGRATION_REQUIRED`), preventing database corruption.

---

## 7. Recommended Isolated Runtime-Verification Sequence

When runtime execution is permitted:
1. **Migration Execution Test**:
   - Apply migrations 0020 and 0021 against an empty SQLite test database and an existing migrated database. Confirm zero DDL errors.
2. **Missing Schema Rejection Test**:
   - In an environment without migration 0021, call `POST /van-sales/orders`.
   - Confirm HTTP 503 response with code `SCHEMA_MIGRATION_REQUIRED`.
3. **Trip/Product Allocation Mismatch Test**:
   - Insert an allocation for Trip 1, Product A.
   - Attempt to insert a deduction referencing Trip 2 or Product B.
   - Confirm batch aborts with `Van stock allocation not found or trip/product mismatch for tenant`.
4. **Duplicate Deduction Test**:
   - Attempt to insert two deduction rows with identical `(order_id, allocation_id)`.
   - Confirm batch aborts due to unique constraint.
5. **Over-allocation Deduction Test**:
   - Allocation has 5 units remaining. Attempt deduction of 6 units.
   - Confirm batch aborts with `Insufficient van stock on allocation row`.
6. **Concurrent Spot-Bill Credit Limit Test**:
   - Concurrently submit two spot-bills that collectively breach credit limit.
   - Confirm trigger `trg_spot_bill_credit_guard` aborts second request with `CREDIT_LIMIT_BREACH`.
