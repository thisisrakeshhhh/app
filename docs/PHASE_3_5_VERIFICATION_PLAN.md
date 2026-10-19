# RouteFlow Phase 3.5 — Non-Destructive Verification and Migration Plan

> **Pre-Execution Guardrail:** This document defines the formal, non-destructive test matrix, simulation scenarios, database invariants, and migration execution procedures for RouteFlow. **No migrations, live database operations, test suites, or Wrangler commands are to be executed during this planning phase.** All verification procedures described herein are prepared for subsequent authorized execution.

---

## 1. Test Environment Prerequisites & Backup Requirements

### 1.1 Isolated Test Harness Prerequisites
1. **Isolated Cloudflare D1 Instance**:
   - Verification must execute on a dedicated staging database: `routeflow-staging-d1` (never on production `routeflow-prod-d1`).
   - Wrangler environment configuration: `wrangler.toml` with `[env.staging]` environment flags.
2. **Deterministic Seed State**:
   - Seed data containing:
     - 1 Organization (`org_test_01`).
     - 3 Users: Owner (`usr_owner`), Salesperson (`usr_sales`), Delivery Executive (`usr_driver`).
     - 1 Retailer (`ret_alpha`): Credit Limit = ₹10,000 (1,000,000 paise), Current Outstanding = ₹6,000 (600,000 paise).
     - 2 Master Catalog Products: Product A (Rate: ₹100, GST 18%), Product B (Rate: ₹200, GST 18%).
     - 1 Delivery Trip (`trip_alpha`) assigned to `usr_sales` with Vehicle `DL-1VA-1001`.
     - 2 Van Stock Allocation rows for Product A:
       - Row 1: Batch 101 (Expires 2026-12-31), Allocated = 10, Delivered = 0.
       - Row 2: Batch 102 (Expires 2027-06-30), Allocated = 20, Delivered = 0.

### 1.2 Point-in-Time Database Backup Requirement
Prior to applying any forward migrations (0019, 0020, 0021) or test runs:
```bash
# 1. Export entire D1 SQLite snapshot
npx wrangler d1 export routeflow-staging-d1 --output=./backups/pre_phase_3_5_backup.sql

# 2. Verify snapshot integrity locally
sqlite3 ./backups/pre_phase_3_5_backup.sql "PRAGMA integrity_check;"
```

---

## 2. Migration Ordering, Preflight Checks & Rollback Strategy

### 2.1 Sequential Migration Deployment Plan
Migrations must be executed in strict lexicographical order:
1. `backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`
   - Preflight: Verify tables `companies` and `users` exist.
   - Action: Adds organizations, memberships, global catalog, van stock allocations table, retailer ledgers, credit policies, and audit overrides.
   - Verification: `SELECT name FROM sqlite_master WHERE type='table' AND name IN ('organizations', 'van_stock_allocations', 'credit_policies');`
2. `backend/migrations/0020_van_sales_state_machine.sql`
   - Preflight: Verify trigger `trg_order_status_transition_guard` exists.
   - Action: Replaces trigger to allow `SUBMITTED -> DELIVERED` for `is_van_sale = 1`. Creates index `idx_orders_van_sale_provisional`.
   - Verification: `SELECT sql FROM sqlite_master WHERE type='trigger' AND name='trg_order_status_transition_guard';`
3. `backend/migrations/0021_van_stock_lifecycle_guards.sql`
   - Preflight: Verify `van_stock_allocations` and `orders` tables exist.
   - Action: Installs `trg_van_stock_allocation_status_guard` and `trg_spot_bill_credit_guard`.
   - Verification: `SELECT name FROM sqlite_master WHERE type='trigger' AND name IN ('trg_van_stock_allocation_status_guard', 'trg_spot_bill_credit_guard');`

### 2.2 Forward Recovery & Rollback Strategy
- **Rollback Invariant**: D1 does not provide automated down-migrations. Rollback is achieved by re-applying the verified baseline snapshot `./backups/pre_phase_3_5_backup.sql` to the target database.
- **Trigger Replacement**: All trigger definitions in migrations 0020 and 0021 use `DROP TRIGGER IF EXISTS` before `CREATE TRIGGER`, ensuring re-entrant and idempotent re-application without schema corruption.

---

## 3. High-Priority Test Verification Scenarios

### Scenario A: Concurrent Same-Retailer Spot-Bills (Race Condition Defense)
- **Objective**: Verify that two simultaneous spot-bills (`isProvisional = false`, `paymentMethod = 'CREDIT'`) cannot race past the retailer's credit limit.
- **Initial State**:
  - `ret_alpha`: Credit Limit = 1,000,000 paise (₹10,000), Outstanding = 600,000 paise (₹6,000). Available = 400,000 paise (₹4,000).
- **Execution**:
  - Request 1: Spot-bill for 300,000 paise (₹3,000). No override.
  - Request 2: Spot-bill for 250,000 paise (₹2,500). No override.
  - Both requests dispatched simultaneously to `POST /van-sales/orders`.
- **Expected Outcome**:
  - Exactly one request commits (e.g., Request 1 returns HTTP 200 with status `DELIVERED`).
  - The other request fails at statement 1 via `trg_spot_bill_credit_guard`:
    `RAISE(ABORT, 'Credit exposure exceeds limit on spot-bill')`.
  - Batch 2 completely aborts: returns HTTP 409 `CREDIT_LIMIT_BREACH`.
  - Final `ret_alpha.outstanding_amount_paise` = 900,000 paise (never 1,150,000 paise).
  - Exactly 1 invoice and 1 ledger entry exist.

### Scenario B: D1 Transaction Batch Atomicity on Partial Failure
- **Objective**: Verify that a failure in any statement of the D1 batch rolls back all other statements.
- **Execution**:
  - Dispatch a spot-bill where van stock allocation has 5 units, but order requests 10 units.
- **Expected Outcome**:
  - `trg_van_stock_allocation_guard` raises `ABORT` on the stock deduction statement.
  - Entire batch aborts: order row is rolled back, invoice is not created, customer balance is not incremented.
  - Verification query: `SELECT count(*) FROM orders WHERE id = :failedOrderId;` returns `0`.

### Scenario C: Authorized Manager Credit Override
- **Objective**: Verify that an authorized manager override permits a single order to exceed credit limit without permanently expanding the retailer's credit limit.
- **Execution**:
  - `ret_alpha`: Outstanding = 900,000 paise, Limit = 1,000,000 paise.
  - Owner dispatches spot-bill for 300,000 paise with `creditOverridePaise = 200,000` and reason `"Owner seasonal override"`.
- **Expected Outcome**:
  - Order is accepted (HTTP 200). `orders.credit_override_paise` = 200,000.
  - `credit_overrides` table receives single audit record.
  - `ret_alpha.outstanding_amount_paise` becomes 1,200,000 paise.
  - Next regular order without override is rejected immediately by `trg_spot_bill_credit_guard` because outstanding (1,200,000) > limit (1,000,000 + 0).
  - Proves the override was single-use and not immortal.

### Scenario D: FEFO Stock Allocation Exhaustion & Discrepancy Logging
- **Objective**: Verify that vehicle stock is consumed across batches by earliest expiry, and stock deficits abort cleanly without phantom stock creation.
- **Initial State**:
  - Product A Batch 101: 5 units available.
  - Product A Batch 102: 10 units available.
- **Execution**:
  - Order 1: 8 units. Consumes 5 units from Batch 101 and 3 units from Batch 102.
  - Order 2: 10 units. Only 7 units remain in Batch 102.
- **Expected Outcome**:
  - Order 1 succeeds: Batch 101 delivered = 5, Batch 102 delivered = 3.
  - Order 2 fails with HTTP 409 `VAN_STOCK_BREACH` or discrepancy logged.
  - Stock never goes negative: `CHECK(delivered_qty <= allocated_qty)` invariant preserved.

### Scenario E: Android Worker Crash & Replay Recovery
- **Objective**: Verify that a mobile client crashing after server commit can safely replay without duplicate financial effects.
- **Execution**:
  1. Client sends `POST /van-sales/orders` with `idempotencyKey = 'idemp_test_999'`.
  2. Server commits batch and stores idempotency record.
  3. Client process is terminated immediately before executing `localCommit()`.
  4. Client restarts and re-sends the identical payload and key.
- **Expected Outcome**:
  - Server matches `idempotency_records WHERE key = 'idemp_test_999'`, compares SHA-256 payload hash, and returns cached HTTP 200 payload.
  - Zero database writes occur on the replay.
  - Client worker executes `localCommit()`: updates Room SQLite order status to `DELIVERED`, and deletes outbox item.
  - Total invoices and ledger postings for order = exactly 1.

---

## 4. Expected Database Invariants Check Matrix

| Invariant ID | Target Entity | Invariant Rule | Verification Query |
| :--- | :--- | :--- | :--- |
| **INV-01** | `retailers` | `outstanding_amount_paise` equals sum of debit minus credit entries in `retailer_ledgers`. | `SELECT r.id, r.outstanding_amount_paise, COALESCE(SUM(CASE WHEN l.entry_type='INVOICE_DEBIT' THEN l.amount_paise ELSE -l.amount_paise END), 0) FROM retailers r LEFT JOIN retailer_ledgers l ON l.retailer_id = r.id GROUP BY r.id;` |
| **INV-02** | `van_stock_allocations` | `delivered_qty <= allocated_qty` and `delivered_qty >= 0`. | `SELECT id FROM van_stock_allocations WHERE delivered_qty > allocated_qty OR delivered_qty < 0;` (Must return 0 rows). |
| **INV-03** | `invoices` | `order_id` is globally unique. | `SELECT order_id, COUNT(*) FROM invoices GROUP BY order_id HAVING COUNT(*) > 1;` (Must return 0 rows). |
| **INV-04** | `credit_reservations` | Active reservations exist only for orders in `SUBMITTED`, `APPROVED`, `PICKING`, `PACKED`, `OUT_FOR_DELIVERY`. | `SELECT cr.order_id, o.status FROM credit_reservations cr JOIN orders o ON o.id = cr.order_id WHERE o.status IN ('DELIVERED', 'REJECTED', 'CANCELLED');` (Must return 0 rows). |
| **INV-05** | `orders` | No van sales order (`is_van_sale = 1`) enters `PICKING` or standard dispatch queue. | `SELECT id FROM orders WHERE is_van_sale = 1 AND status IN ('PICKING', 'PACKED', 'ASSIGNED_TO_TRIP');` (Must return 0 rows). |
