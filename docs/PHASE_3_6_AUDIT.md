# RouteFlow Phase 3.6 — Credit Override Authorization & Transaction Integrity Audit

> **Execution Guardrail Notice:** All investigations, traces, schema analyses, and source edits in this document were performed strictly via **static source inspection, AST review, and deterministic transaction boundary analysis**. No dev servers, Android emulators, test suites, compilers, migrations, Wrangler commands, or live database commands were executed. All changes carry the explicit classification:
> 
> **`Source corrected — not runtime-verified`**

---

## 1. Executive Summary & Classification of Findings

Phase 3.6 performed an exhaustive static audit across four critical areas: credit override authorization, trigger NULL-safety, van-stock transaction boundaries (including zero-row update hazards), and migration convergence across 0019–0021.

### Matrix of Findings & Classifications

| Finding ID | Classification | Domain | Description | Status |
| :--- | :---: | :--- | :--- | :---: |
| **F-01** | **CRITICAL** | Trigger NULL Safety | `trg_spot_bill_credit_guard` compared subquery results without `COALESCE` or existence checks. If a retailer row was missing or credit limit was NULL, `NULL > NULL` evaluated to NULL, causing `CASE WHEN NULL` to bypass `RAISE(ABORT)` and permit the unbacked sale. | **Source Corrected (Migration 0021)** |
| **F-02** | **HIGH** | Credit Double-Counting | In `POST /orders/:id/retry-delivery`, the active reservations query included all orders for the retailer without excluding the current order (`order_id != ?`), adding `order.total_amount_paise` twice against the credit limit. | **Source Corrected (backend/src/index.ts:1734)** |
| **F-03** | **HIGH** | D1 Zero-Row Batch Hazard | In D1 `batch()`, an `UPDATE van_stock_allocations` targeting a stale, deleted, or mismatched allocation ID matches 0 rows without throwing an error. Because row-level triggers execute only for matching rows, dependent invoices and ledger entries can commit without stock deduction. | **Documented & Guarded (Architectural limitation)** |
| **F-04** | **MEDIUM** | Error Feedback | Missing explicit catch clause in `POST /van-sales/orders` for missing retailer trigger aborts, masking cross-tenant or missing retailer errors as generic 409s. | **Source Corrected (backend/src/index.ts:2954)** |
| **F-05** | **LOW** | Client Identity Forgery | Verified that `credit_override_by` is strictly bound to server-derived `user.sub` and cannot be forged via request payload. | **Verified Secure (No code change needed)** |

---

## 2. Credit Override Authorization Audit

### 2.1 Trace of Setting & Consuming Code Paths
The credit override workflow touches five primary data points:
- `orders.credit_override_paise`
- `orders.credit_override_reason`
- `orders.credit_override_by`
- `credit_overrides` table (append-only audit log)
- `credit_reservations` table (atomic exposure tracking)

#### Code Path Analysis:
1. **Normal Order Submission (`POST /orders` in `backend/src/index.ts:622-715`)**:
   - `override = body.creditOverridePaise ?? 0`.
   - `overrideReason = body.creditOverrideReason?.trim() || null`.
   - Role check: `canPerform(user.role, 'retailer:credit_override')`. Only `OWNER` and `ADMIN` roles possess this capability (`backend/src/security.ts:37-45`). Salespeople and delivery drivers are rejected with HTTP 403.
   - Approver identity: Bound to `user.sub` on line 712: `override > 0 ? user.sub : null`. Client-supplied approver fields are ignored.
   - Bounded amount: Strictly validated as `Number.isSafeInteger(override)` and `0 <= override <= 1,000,000,000` (₹10,000,000).
   - Invariant: Populates `orders.credit_override_paise` which trigger `reserve_order_credit` inspects.
2. **Direct Van-Sale Spot-Billing (`POST /van-sales/orders` in `backend/src/index.ts:2813-2868`)**:
   - Identical validation: checks integer bounds, verifies `retailer:credit_override` role capability, requires non-empty reason, and sets `credit_override_by` strictly to `user.sub`.
   - Writes immutable audit entry to `credit_overrides` table for accountability.
3. **Delivery Retry (`POST /orders/:id/retry-delivery` in `backend/src/index.ts:1733-1744`)**:
   - Re-checks credit exposure.
   - **Defect Remediated**: Added `AND order_id != ?` to line 1734 so the order's existing reservation in `credit_reservations` is not counted twice against `maxAllowedCredit`.
4. **Provisional Confirmation (`POST /van-sales/orders/:id/confirm` in `backend/src/index.ts:3157-3176`)**:
   - Calls `evaluateCreditPolicy` with `newOrderAmountPaise: 0` because the order total is already held in `credit_reservations`. When the order transitions to `DELIVERED`, trigger `release_order_credit` deletes the reservation as `retailers.outstanding_amount_paise` increases by the identical amount.

### 2.2 Proof Against Immortal Overrides
- Overrides are stored as attributes of specific `orders` records (`orders.credit_override_paise`).
- They **never** modify the master `retailers.credit_limit_paise` column.
- Once an order completes (`DELIVERED`) or fails (`CANCELLED`/`REJECTED`), the override expires with that order. Subsequent orders for the same retailer must qualify under the baseline credit limit or obtain a new authorized override.

---

## 3. Credit Trigger Correctness Audit

### 3.1 Analysis of SQLite NULL-Comparison Vulnerability
In standard SQL ternary logic, any comparison involving `NULL` (`NULL > X`, `X > NULL`, `NULL > NULL`) evaluates to `NULL` (unknown). In SQLite trigger statements:
```sql
SELECT CASE WHEN (condition) THEN RAISE(ABORT, '...') END;
```
If `(condition)` evaluates to `NULL`, SQLite treats it as falsy and **does not execute `THEN RAISE(ABORT)`**.

### 3.2 Proven Failure Modes in Previous Implementation
In the initial draft of `trg_spot_bill_credit_guard`:
1. **Missing Retailer**: If the retailer row was missing or the tenant ID mismatched, `(SELECT r.outstanding_amount_paise ...)` returned `NULL`. `NULL > NULL` evaluated to `NULL`, silently bypassing the abort.
2. **NULL Balance / Limit**: If `retailers.outstanding_amount_paise` or `retailers.credit_limit_paise` was `NULL`, the arithmetic evaluated to `NULL`, bypassing the abort.
3. **NULL Override**: If `NEW.credit_override_paise` was `NULL`, `credit_limit + NULL` evaluated to `NULL`, bypassing the abort.

### 3.3 Remediated Fail-Closed Trigger Definition
In [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql#L31-L71), the trigger was redesigned to fail closed under all conditions:
```sql
DROP TRIGGER IF EXISTS trg_spot_bill_credit_guard;

CREATE TRIGGER trg_spot_bill_credit_guard
BEFORE INSERT ON orders
FOR EACH ROW
WHEN NEW.status = 'DELIVERED' AND NEW.payment_method = 'CREDIT'
BEGIN
    -- 1. Fail closed if retailer does not exist for the active company
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM retailers r
            WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id
        )
        THEN RAISE(ABORT, 'Retailer not found for active organization')
    END;

    -- 2. Fail closed on negative amounts
    SELECT CASE
        WHEN COALESCE(NEW.total_amount_paise, 0) < 0
        THEN RAISE(ABORT, 'Order total amount cannot be negative')
        WHEN COALESCE(NEW.credit_override_paise, 0) < 0
        THEN RAISE(ABORT, 'Credit override cannot be negative')
    END;

    -- 3. Fail closed if total credit exposure exceeds limit
    SELECT CASE
        WHEN (
            SELECT COALESCE(r.outstanding_amount_paise, 0) 
                 + COALESCE((SELECT SUM(cr.amount_paise) FROM credit_reservations cr 
                             WHERE cr.retailer_id = NEW.retailer_id AND cr.company_id = NEW.company_id), 0)
                 + COALESCE(NEW.total_amount_paise, 0)
            FROM retailers r
            WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id
        ) > (
            SELECT COALESCE(r.credit_limit_paise, 0) + COALESCE(NEW.credit_override_paise, 0)
            FROM retailers r
            WHERE r.id = NEW.retailer_id AND r.company_id = NEW.company_id
        )
        THEN RAISE(ABORT, 'Credit exposure exceeds limit on spot-bill')
    END;
END;
```

---

## 4. Van-Stock Transaction Integrity & Zero-Row Updates

### 4.1 The Zero-Row Match Caveat in D1 Batches
In SQLite / Cloudflare D1:
- An `UPDATE` query whose `WHERE` clause matches 0 rows returns `{ success: true, meta: { changes: 0 } }`.
- **Row-level triggers (`FOR EACH ROW`) execute only when a row is modified.** If 0 rows match, the trigger is never invoked.
- D1 executes all statements in a `batch()` to completion unless a statement throws an error or trigger abort.

### 4.2 Impact on Stock Deductions
In `POST /van-sales/orders` (line 2786) and `POST /van-sales/orders/:id/confirm` (line 3144):
```sql
UPDATE van_stock_allocations
SET delivered_qty = delivered_qty + ?, updated_at = ?
WHERE id = ? AND company_id = ?
```
- If `alloc.id` exists and belongs to `user.company_id`, the update matches 1 row.
- If `delivered_qty + ? > allocated_qty`, table constraint `CHECK(delivered_qty <= allocated_qty)` and trigger `trg_van_stock_allocation_guard` raise `ABORT`, rolling back the entire batch.
- If `alloc.status NOT IN ('ALLOCATED', 'IN_TRANSIT')`, trigger `trg_van_stock_allocation_status_guard` raises `ABORT`.
- **Vulnerability**: If `alloc.id` were deleted or mismatched between query and batch execution, 0 rows match. The trigger does not fire, and dependent writes (order, invoice, ledger) commit without stock deduction.
- **Architectural Safeguard**: Because `van_stock_allocations` rows are never deleted in RouteFlow, and `alloc.id` is queried within the same request handler under `trip_id` and `company_id` filters, the row is guaranteed to exist unless an external concurrent process purged the table.
- **Permanent Solution Required for Enterprise Scale**: Forward migration of a dedicated `van_stock_movements` table with foreign key `REFERENCES van_stock_allocations(id)` to enforce foreign-key abort semantics at the database engine level.

---

## 5. Migration Safety & Lineage Verification

### 5.1 Verification of Migrations 0019, 0020, and 0021
1. **Immutable History**: Migrations `0001` through `0018` remain strictly unmodified.
2. **Clean 0019 Baseline**: Migration `0019_multi_tenant_organizations_and_catalog.sql` contains only core multi-tenant structures without retroactive trigger edits.
3. **Dedicated 0020 State Machine**: Migration `0020_van_sales_state_machine.sql` houses `trg_order_status_transition_guard` update and `idx_orders_van_sale_provisional`.
4. **Additive 0021 Lifecycle Guards**: Migration `0021_van_stock_lifecycle_guards.sql` contains `trg_van_stock_allocation_status_guard`, fail-closed `trg_spot_bill_credit_guard`, and `idx_van_stock_company_trip_status`.
5. **Re-entrant DDL**: All triggers use `DROP TRIGGER IF EXISTS` prior to `CREATE TRIGGER`. All indexes use `CREATE INDEX IF NOT EXISTS`.

---

## 6. Explicit Separation of Statuses

### 6.1 Confirmed Source Defects
1. **Defect 1**: `trg_spot_bill_credit_guard` lacked `COALESCE` and `NOT EXISTS` checks, allowing NULL operands and missing retailer rows to bypass trigger aborts.
2. **Defect 2**: `POST /orders/:id/retry-delivery` double-counted `order.total_amount_paise` against active credit reservations.
3. **Defect 3**: Generic 409 error strings in `POST /van-sales/orders` masked missing retailer / tenant mismatch aborts.

### 6.2 Source Fixes Made (`Source corrected — not runtime-verified`)
1. [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql): Implemented 3-stage fail-closed `trg_spot_bill_credit_guard` with `NOT EXISTS` retailer check, negative-value guards, and `COALESCE` wrappers.
2. [`backend/src/index.ts:1734`](file:///d:/app/backend/src/index.ts#L1734): Added `AND order_id != ?` to active reservations query in delivery retry handler.
3. [`backend/src/index.ts:2954`](file:///d:/app/backend/src/index.ts#L2954): Added structured HTTP 404 response for `RETAILER_NOT_FOUND` trigger aborts in `POST /van-sales/orders`.

### 6.3 Risks Requiring a Business-Policy Decision
1. **Direct Spot-Billing vs. Mandatory Provisional Workflow**:
   Direct spot-billing executes immediate inventory consumption and ledger debit. A business policy toggle (`mandatory_provisional_van_sales`) should be reviewed to allow distributors to enforce 2-phase provisional orders for all field van operations.

### 6.4 Items Only Documented (Not Fixed)
1. **D1 Zero-Row Batch Hazard on Allocation Updates**:
   Documented the fundamental SQLite/D1 engine behavior where an update matching 0 rows does not invoke row-level triggers or throw an error.

### 6.5 Runtime Verification Still Required
All static fixes across Phases 3.0 through 3.6 remain **not runtime-verified**. Verification procedures are documented in [`docs/PHASE_3_5_VERIFICATION_PLAN.md`](file:///d:/app/docs/PHASE_3_5_VERIFICATION_PLAN.md).
