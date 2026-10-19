# RouteFlow Phase 3.4.1 — Deep Static Integrity & Risk Resolution Audit

> **Execution Guardrail Notice:** All findings, trace evaluations, and source remediations in this document were performed strictly via **static code analysis, schema review, and deterministic transaction tracing**. No dev servers, emulators, automated test suites, compilers, migrations, or live database commands were executed. All changes carry the explicit classification:
> 
> **`Source corrected — not runtime-verified`**

---

## 1. Migration Upgrade Path & Schema Lineage

### 1.1 Identification of Historical Migration Modifications
During Phase 3.4, modifications were directly introduced into [`backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql):
1. **Van Stock Status Guard**: `trg_van_stock_allocation_status_guard` on `van_stock_allocations`.
2. **Retailer Credit Balance Guard**: `trg_retailer_credit_balance_guard` on `retailers`.

**Risk Analysis**:
Editing an existing numbered migration (0019) causes schema divergence in CI/CD and deployment environments. A database that already executed migration 0019 (via `d1_migrations` table tracking) would never execute retroactive changes. Conversely, a fresh database executing the modified 0019 would create triggers that staging/production databases lack.

### 1.2 Remediations Applied
1. **Restored Migration 0019 Baseline**:
   - Removed `trg_van_stock_allocation_status_guard` from [`0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql#L115-L130).
   - Removed flawed `trg_retailer_credit_balance_guard` from [`0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql#L168-L186).
   - Migration 0019 now cleanly defines core organizations, memberships, global catalog, van stock allocations table, retailer double-entry ledgers, and credit policy structures.
2. **Preserved Migration 0020**:
   - Maintained [`backend/migrations/0020_van_sales_state_machine.sql`](file:///d:/app/backend/migrations/0020_van_sales_state_machine.sql) as the forward migration updating `trg_order_status_transition_guard` to permit `SUBMITTED -> DELIVERED` transitions for provisional van sales (`is_van_sale = 1`).
3. **Created Forward Migration 0021**:
   - Authored [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql) to house `trg_van_stock_allocation_status_guard` and composite index `idx_van_stock_company_trip_status`.

### 1.3 Fresh vs. Already-Migrated Database Behavior

| Scenario | Migration Chain | Outcome |
| :--- | :--- | :--- |
| **Fresh Database** | `0001` → ... → `0018` → `0019` → `0020` → `0021` | Deterministically constructs the entire multi-tenant schema, updates status triggers, and activates van stock allocation status guards. |
| **Already-Migrated Database** (Ran 0001–0020) | Applies `0021_van_stock_lifecycle_guards.sql` | Safely creates `trg_van_stock_allocation_status_guard` and index `idx_van_stock_company_trip_status` without table modifications or column redefinitions. |

---

## 2. Credit Override Integrity & Concurrency Analysis

### 2.1 Inspection of `credit_overrides` Table Schema
In [`0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql#L150-L166):
```sql
CREATE TABLE IF NOT EXISTS credit_overrides (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    order_id TEXT,
    override_amount_paise INTEGER NOT NULL,
    exposure_at_time_paise INTEGER NOT NULL,
    credit_limit_paise INTEGER NOT NULL,
    authorized_by TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (authorized_by) REFERENCES users(id)
);
```

**Critical Architectural Audit Findings**:
1. **Lack of Lifecycle Columns**: `credit_overrides` has no `status` (`PENDING`, `ACTIVE`, `CONSUMED`, `EXPIRED`), no `consumed_at` timestamp, and no `expires_at` timestamp. It functions strictly as an append-only audit trail.
2. **Defect in `trg_retailer_credit_balance_guard`**:
   The trigger previously added in Phase 3.4 evaluated:
   `WHERE co.retailer_id = NEW.id AND co.company_id = NEW.company_id AND (NEW.outstanding_amount_paise <= NEW.credit_limit_paise + co.override_amount_paise)`
   Because the table lacks consumption and expiry tracking, any historical override recorded for a retailer permanently expanded that retailer's credit limit for every subsequent order indefinitely.
3. **Severe Regression in Regular Deliveries**:
   Normal order fulfillment (`POST /orders/:id/deliver` in [`backend/src/index.ts`](file:///d:/app/backend/src/index.ts#L1489)) updates `retailers.outstanding_amount_paise` for orders that had credit overrides authorized at order submission time (`orders.credit_override_paise`). Because `POST /orders/:id/deliver` does not insert into `credit_overrides`, `trg_retailer_credit_balance_guard` aborted legitimate order deliveries.

### 2.2 Canonical Credit Enforcement via Migration 0009 / 0012
The RouteFlow core architecture already provides atomic credit reservation through:
- Columns in `orders`: `credit_override_paise`, `credit_override_reason`, `credit_override_by`.
- Trigger `reserve_order_credit` (`0009_daily_cycle_integrity.sql`): Fires on `INSERT ON orders WHEN NEW.status = 'SUBMITTED'`. Checks `outstanding + reservations + NEW.total <= credit_limit + credit_override_paise`.
- Trigger `credit_reservation_limit` (`0012_security_and_concurrency.sql`): Validates reservations before insert.
- Trigger `release_order_credit` (`0009`): Drops reservation when status transitions to `DELIVERED`, matching the increase in `retailers.outstanding_amount_paise`.

In [`backend/src/index.ts`](file:///d:/app/backend/src/index.ts#L2846-L2853), `POST /van-sales/orders` correctly populates `credit_override_paise`, `credit_override_reason`, and `credit_override_by` on the order record, ensuring that provisional van sales leverage the canonical triggers without regression.

### 2.3 Unresolved Architectural Decision: Direct Spot-Billing Credit Concurrency
- **The Challenge**: Direct van sales (spot-billing with `isProvisional = false` and `status = 'DELIVERED'`) bypass `SUBMITTED` state, meaning `reserve_order_credit` does not fire. Instead, `evaluateCreditPolicy` checks exposure in JavaScript, followed by an immediate `UPDATE retailers SET outstanding_amount_paise = ...` in the D1 batch.
- **Concurrency Gap**: If two spot-bills for the same retailer race concurrently without an override, both may pass JavaScript validation before either D1 batch commits, leading to a balance overdraw.
- **Why It Is Unresolved**: Enforcing this via an SQLite trigger on `retailers` requires the trigger to distinguish between authorized overrides and unauthorized overdraws. Because SQLite triggers cannot access JavaScript execution context, and `credit_overrides` lacks a consumable single-use token lifecycle, a database-level trigger cannot be introduced without inventing new schema semantics.
- **Architectural Recommendation**: When credit limit strictness is paramount, configure the organization policy to mandate that all van sales originate as provisional orders (`isProvisional = true`), leveraging the 100% atomic 2-phase reservation triggers, followed by immediate confirmation.

---

## 3. Concurrent Confirmation and Replay Verification

### 3.1 SQL Statement Execution Trace

When two concurrent requests attempt to confirm the same provisional van sale (`orderId = 'ord_123'`):

#### Case A: Identical Idempotency Key (`key_abc`)
```
Request 1                                          Request 2
-------------------------------------------------  -------------------------------------------------
1. SELECT idempotency_records WHERE key='key_abc'  1. SELECT idempotency_records WHERE key='key_abc'
   -> Not found                                       -> Not found
2. SELECT orders WHERE id='ord_123'                2. SELECT orders WHERE id='ord_123'
   -> status = 'SUBMITTED'                            -> status = 'SUBMITTED'
3. c.env.DB.batch(statements) begins               3. Pauses / Waits for D1 lock
   - UPDATE orders SET status='DELIVERED'...
   - UPDATE van_stock_allocations...
   - UPDATE order_items...
   - INSERT INTO invoices (id, order_id, ...)...
   - UPDATE retailers...
   - INSERT INTO idempotency_records ('key_abc')...
4. Batch commits successfully.
                                                   5. c.env.DB.batch(statements) begins
                                                      - UPDATE orders SET status='DELIVERED'...
                                                        Trigger trg_order_status_transition_guard evaluates:
                                                        OLD.status = 'DELIVERED', NEW.status = 'DELIVERED'.
                                                        Condition OLD.status != 'OUT_FOR_DELIVERY' AND
                                                        NOT (NEW.status='DELIVERED' AND OLD.is_van_sale=1
                                                             AND OLD.status='SUBMITTED') is TRUE!
                                                        -> SELECT RAISE(ABORT, 'Order is not in valid precursor state')!
                                                   6. D1 transaction immediately aborts and rolls back.
                                                   7. Catch block catches error; queries idempotency_records;
                                                      finds 'key_abc' written by Request 1;
                                                      returns 200 OK with cached response.
```

#### Case B: Different Idempotency Keys (`key_1` vs. `key_2`)
```
Request 1 (key_1)                                  Request 2 (key_2)
-------------------------------------------------  -------------------------------------------------
1. Executes batch and commits:                     1. Executes batch:
   - orders.status -> 'DELIVERED'                     - UPDATE orders SET status='DELIVERED'...
   - Invoice created for order_id                       Trigger fires: OLD.status='DELIVERED'.
   - Allocation deducted                                Raises RAISE(ABORT)!
   - idempotency_records writes key_1                 - Batch aborts immediately at statement 1.
                                                   2. Catch block detects order is already DELIVERED;
                                                      returns idempotent acknowledgement:
                                                      { success: true, idempotent: true, status: 'DELIVERED' }.
```

### 3.2 Uniqueness Constraints and Invariants
- **Invoices Uniqueness**: `invoices.order_id` is defined as `UNIQUE` in migration `0005`. Even if triggers were bypassed, duplicate invoice creation is physically impossible at the database engine level.
- **Stock Floor Guard**: `van_stock_allocations` table specifies `CHECK(delivered_qty <= allocated_qty)` in schema line 90 and `trg_van_stock_allocation_guard` raises `ABORT` on negative or exceeding quantities. Duplicate stock deduction is impossible.
- **Zero-Row Non-Execution**: By targeting `WHERE id = ? AND company_id = ?` (without status filter), concurrent updates update the existing row, ensuring that `trg_order_status_transition_guard` always evaluates and aborts invalid transitions.

---

## 4. Android Outbox Recovery & Call Site Audit

### 4.1 Outbox Traceability & Enqueue Call Sites
A complete audit of `com.routeflow.app` reveals the exact distribution of `SyncOutboxEntity` enqueue operations:

| Enqueue Site | Event Type | Idempotency Key Scheme | Room DB Entity Synchronization |
| :--- | :--- | :--- | :--- |
| [`NetworkOrderRepository.kt:62`](file:///d:/app/app/src/main/java/com/routeflow/app/data/repository/NetworkOrderRepository.kt#L62) | `ORDER_SUBMISSION` | `UUID.randomUUID()` | Inserts `OrderEntity` and `OrderItemEntity` in Room before outbox enqueue. |
| [`DurableFieldRepository.kt:31`](file:///d:/app/app/src/main/java/com/routeflow/app/data/repository/DurableFieldRepository.kt#L31) | `VISIT_START` | `"visit_" + id` | Inserts `VisitEntity` with status `ACTIVE`. |
| [`DurableFieldRepository.kt:40`](file:///d:/app/app/src/main/java/com/routeflow/app/data/repository/DurableFieldRepository.kt#L40) | `VISIT_END` | `"checkout_" + id` | Updates `VisitEntity` to `COMPLETED`. |
| [`DurableFieldRepository.kt:65`](file:///d:/app/app/src/main/java/com/routeflow/app/data/repository/DurableFieldRepository.kt#L65) | `STOCK_CHECK` | `"stock_" + id` | Inserts `StockCheckEntity`. |
| [`OrderSyncWorker.kt:90`](file:///d:/app/app/src/main/java/com/routeflow/app/data/sync/OrderSyncWorker.kt#L90) | `VAN_SALE_ORDER` | Handled by worker | *Worker handles network and updates Room; repository enqueue pending Phase 4.* |
| [`OrderSyncWorker.kt:100`](file:///d:/app/app/src/main/java/com/routeflow/app/data/sync/OrderSyncWorker.kt#L100) | `VAN_SALE_CONFIRM` | Handled by worker | *Worker handles network and updates Room; repository enqueue pending Phase 4.* |

### 4.2 Explicit Finding: Missing Repository / UI Enqueue Sites
> [!IMPORTANT]
> While [`OrderSyncWorker.kt`](file:///d:/app/app/src/main/java/com/routeflow/app/data/sync/OrderSyncWorker.kt) has been fully wired to deserialize, dispatch, parse HTTP responses, and execute `database.orderDao().updateOrderStatus()` for `VAN_SALE_ORDER` and `VAN_SALE_CONFIRM`, **there are currently no repository or UI call sites in Android that enqueue these two event types into `sync_outbox`**.
>
> Constructing the salesperson's mobile van sales cart, stock picker, and `VanSaleRepository.queueVanSale()` is designated for **Phase 4 (Mobile Van-Sales UI)**.

### 4.3 Crash Recovery Invariant
If the Android client crashes after server success but prior to executing `localCommit()` and deleting the outbox item:
1. WorkManager restarts `OrderSyncWorker` on the next interval or network reconnection.
2. The worker re-reads the pending `SyncOutboxEntity` and dispatches the identical `event.idempotencyKey` to the server.
3. The server matches the cached record in `idempotency_records` and returns the HTTP 200 payload without creating duplicate orders, invoices, or ledger entries.
4. The worker executes `localCommit()`: updates `database.orderDao().updateOrderStatus(orderId, status, timestamp)` and deletes the outbox entry from Room.
5. Recovery is fully deterministic and safe against financial duplication.

---

## 5. Summary of Files Changed in Phase 3.4.1

1. [`backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql):
   - Restored historical baseline; removed `trg_van_stock_allocation_status_guard` and `trg_retailer_credit_balance_guard`.
2. [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql) *(New File)*:
   - Isolated `trg_van_stock_allocation_status_guard` and `idx_van_stock_company_trip_status` into clean forward migration.
3. [`docs/PHASE_3_4_1_AUDIT.md`](file:///d:/app/docs/PHASE_3_4_1_AUDIT.md) *(New File)*:
   - Canonical audit report with exact SQL traces, failure-mode proofs, and architectural boundary analysis.
4. [`docs/REQUIREMENTS_GAP_MATRIX.md`](file:///d:/app/docs/REQUIREMENTS_GAP_MATRIX.md):
   - Updated entries `CRD-01`, `VAN-01`, `VAN-02`, and `MOB-01`.
5. [`docs/IMPLEMENTATION_PROGRESS.md`](file:///d:/app/docs/IMPLEMENTATION_PROGRESS.md):
   - Updated progress tracker with Phase 3.4.1 static resolution details.
