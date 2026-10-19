# RouteFlow Phase 3.5 — Spot-Bill Credit Integrity & Verification Audit

> **Execution Guardrail Notice:** All investigations, traces, schema reviews, and code remediations in this document were performed strictly via **static code analysis and deterministic AST / schema review**. No dev servers, emulators, automated test runners, compilers, migrations, or live database commands were executed. All changes carry the explicit classification:
> 
> **`Source corrected — not runtime-verified`**

---

## 1. Executive Summary & Finding Classification

Phase 3.5 addressed the remaining credit-exposure race condition for direct van spot-billing (`isProvisional = false`, `status = 'DELIVERED'`), completed the van-stock transaction integrity audit, verified migration convergence across 0019–0021, and authored a formal non-destructive verification plan.

### Summary of Findings & Classifications

| Finding ID | Classification | Domain | Description | Status |
| :--- | :---: | :--- | :--- | :---: |
| **F-01** | **CRITICAL** | Credit Concurrency | Concurrent credit spot-bills relied solely on JavaScript application checks (`evaluateCreditPolicy`), allowing racing sales to exceed credit limits without database aborts. | **Source Corrected (Migration 0021 + index.ts)** |
| **F-02** | **HIGH** | Migration Lineage | Migration 0021 lacked the database credit guard required to abort over-limit spot-bills at statement 1 of the D1 batch. | **Source Corrected (Migration 0021 updated)** |
| **F-03** | **MEDIUM** | Error Feedback | Catch block in `POST /van-sales/orders` returned generic 409 messages on credit limit or van stock trigger aborts. | **Source Corrected (Structured codes in index.ts)** |
| **F-04** | **LOW** | Android Call Sites | Absence of UI / repository enqueue call sites in Android for `VAN_SALE_ORDER` (scheduled for Phase 4). | **Documented (Phase 4 dependency)** |

---

## 2. Task 1: Direct Spot-Bill Credit Concurrency Resolution

### 2.1 The Spot-Bill Concurrency Defect
In immediate van spot-sales (`isProvisional = false`):
1. `orders.status` is directly inserted as `'DELIVERED'`.
2. Existing triggers `reserve_order_credit` (`0009_daily_cycle_integrity.sql`) and `credit_reservation_limit` (`0012_security_and_concurrency.sql`) only fire `WHEN NEW.status = 'SUBMITTED'`.
3. Consequently, immediate spot-bills bypassed all database-level credit reservation triggers.
4. Two concurrent spot-bills for the same retailer could both pass the JavaScript check (`evaluateCreditPolicy`) and execute their D1 batches, causing the customer's balance to exceed their credit limit.

### 2.2 The Current Credit-Exposure Formula
The authoritative total credit exposure in RouteFlow is defined as:
$$\text{Total Exposure} = \text{Retailer Outstanding Balance} + \sum(\text{Active Order Reservations}) + \text{New Order Amount}$$

In SQL:
```sql
SELECT r.outstanding_amount_paise 
     + COALESCE((SELECT SUM(cr.amount_paise) FROM credit_reservations cr 
                 WHERE cr.retailer_id = NEW.retailer_id AND cr.company_id = NEW.company_id), 0)
     + NEW.total_amount_paise
FROM retailers r
WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id;
```

### 2.3 The Database-Enforced Solution: `trg_spot_bill_credit_guard`
In [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql), added:
```sql
DROP TRIGGER IF EXISTS trg_spot_bill_credit_guard;

CREATE TRIGGER trg_spot_bill_credit_guard
BEFORE INSERT ON orders
FOR EACH ROW
WHEN NEW.status = 'DELIVERED' AND NEW.payment_method = 'CREDIT'
BEGIN
    SELECT CASE
        WHEN (
            SELECT r.outstanding_amount_paise 
                 + COALESCE((SELECT SUM(cr.amount_paise) FROM credit_reservations cr 
                             WHERE cr.retailer_id = NEW.retailer_id AND cr.company_id = NEW.company_id), 0)
                 + NEW.total_amount_paise
            FROM retailers r
            WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id
        ) > (
            SELECT r.credit_limit_paise + NEW.credit_override_paise
            FROM retailers r
            WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id
        )
        THEN RAISE(ABORT, 'Credit exposure exceeds limit on spot-bill')
    END;
END;
```

### 2.4 Satisfaction of Core Architectural Invariants
1. **Database-Enforced**: Protection is embedded directly in SQLite; JavaScript checks are no longer the sole defense.
2. **Atomic Rollback**: Statement 1 of the batch is `INSERT INTO orders`. The trigger fires `BEFORE INSERT`, aborting the D1 batch before any van stock allocations, invoices, ledgers, or customer balances can be touched.
3. **No Double-Counting**: The spot-bill was never in `credit_reservations`. Existing reservations from other pending orders are counted once, and the spot-bill total is added once.
4. **Authorized Overrides Preserved**: `NEW.credit_override_paise` on the order record is respected by the trigger.
5. **No Immortal Override**: The override amount is scoped strictly to `NEW` (this order record) and never touches `retailers.credit_limit_paise`.
6. **Strict Tenant Isolation**: Scoped by `company_id = NEW.company_id`.

---

## 3. Task 2: Van-Stock Transaction Integrity Audit

### 3.1 Allocation and Stock Deductions
- **Primary Key Targeting**: Stock deductions in both `POST /van-sales/orders` and `POST /van-sales/orders/:id/confirm` target specific allocation rows via `WHERE id = alloc.id AND company_id = ?`.
- **Constraint Guards**: Table constraint `CHECK(delivered_qty <= allocated_qty)` on `van_stock_allocations` (migration 0019) and trigger `trg_van_stock_allocation_guard` guarantee that any concurrent over-deduction triggers `RAISE(ABORT)`.
- **Status Guards**: `trg_van_stock_allocation_status_guard` in migration 0021 guarantees that deliveries from reconciled or inactive allocation rows are rejected by the database.
- **Invoice Uniqueness**: `invoices.order_id` is defined as `UNIQUE` in migration `0005`. Duplicate invoices cannot commit under any concurrent execution path.

---

## 4. Task 3: Migration Sequence & Convergence Audit

### 4.1 Historical Migration Preservation
- `0001` through `0018`: Untouched historical baseline.
- `0019_multi_tenant_organizations_and_catalog.sql`: Clean baseline defining multi-tenant organizations, memberships, catalog, van stock allocations table, retailer ledgers, and credit policies.
- `0020_van_sales_state_machine.sql`: Dedicated forward migration for `trg_order_status_transition_guard` update and `idx_orders_van_sale_provisional`.
- `0021_van_stock_lifecycle_guards.sql`: Clean forward migration housing `trg_van_stock_allocation_status_guard`, `trg_spot_bill_credit_guard`, and composite index `idx_van_stock_company_trip_status`.

### 4.2 Deterministic Convergence
Both fresh databases and already-migrated environments converge upon the identical database schema and trigger definitions:
- Fresh: Runs `0001` → ... → `0021`.
- Already-migrated (ran 0001–0020): Applies `0021_van_stock_lifecycle_guards.sql` without schema collisions.

---

## 5. Explicit Separation of Statuses

### 5.1 Source Fixes Completed (`Source corrected — not runtime-verified`)
1. [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql): Added `trg_spot_bill_credit_guard` to enforce atomic spot-bill credit limits at statement 1 of the D1 batch.
2. [`backend/src/index.ts`](file:///d:/app/backend/src/index.ts#L2953-L2966): Refined catch block in `POST /van-sales/orders` to detect trigger abort messages (`'Credit exposure exceeds limit'`, `'Van stock delivered quantity cannot exceed'`) and return structured HTTP 409 error payloads with `CREDIT_LIMIT_BREACH` and `VAN_STOCK_BREACH` error codes.

### 5.2 Items Merely Documented
1. Complete execution traces for concurrent spot-bills and confirmations.
2. Formal verification plan authored in [`docs/PHASE_3_5_VERIFICATION_PLAN.md`](file:///d:/app/docs/PHASE_3_5_VERIFICATION_PLAN.md).
3. Android outbox recovery mechanics during worker crashes.

### 5.3 Unresolved Business Decisions
1. **Direct Spot-Billing vs. Mandatory Provisional Workflow**:
   While `trg_spot_bill_credit_guard` now guarantees that total credit exposure cannot exceed credit limits during direct spot-billing, direct spot-bills consume stock immediately upon submission.
   *Decision for Product Owner*: Should distributors have an organization-level toggle to mandate that all vehicle sales operate exclusively through the 2-phase provisional cycle (`isProvisional = true` mandatory), ensuring vehicle stock and credit are re-verified prior to invoice generation?

### 5.4 Runtime Verification Still Required
All static remediations in Phases 3.0 through 3.5 remain **not runtime-verified**. Runtime verification on the dedicated staging database (`routeflow-staging-d1`) is documented in [`docs/PHASE_3_5_VERIFICATION_PLAN.md`](file:///d:/app/docs/PHASE_3_5_VERIFICATION_PLAN.md).
