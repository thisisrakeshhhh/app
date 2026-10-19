# RouteFlow — Master Implementation Progress & Milestone Tracker
**Document Version:** 1.1.0  
**Audit Baseline:** Commit `31706b1`  
**Current Phase:** Phase 2 Complete / Phase 3 & 4 Backend Core Wired  
**Execution Guardrail:** Pure Static Code & Database Architecture (No Runtime Execution / No Build Invocations)  

---

## 1. Phase-by-Phase Progress & Realization Summary

| Phase Ref | Phase Name | Status | Realization Summary |
| :--- | :--- | :---: | :--- |
| **Phase 0** | Codebase Audit & System Invariants | **COMPLETED** | Audited all 18 existing D1 migrations, backend controllers (`index.ts`, `daily-cycle.ts`, `trips.ts`, `warehouse.ts`), Android Room entities, and Next.js frontend. |
| **Phase 1** | Canonical Specifications & Architecture Docs | **COMPLETED** | Authored 10 canonical documents in `docs/` covering requirements, security, state machines, RBAC, offline sync, and FMCG KPIs. |
| **Phase 2** | Security & Multi-Tenancy Hardening | **COMPLETED** | 1. RFC 6750 token hardening (removed query-string bearer token fallback in `authMiddleware`).<br>2. RBAC capability engine with role normalization in `security.ts`.<br>3. Multi-tenant organization memberships and `/auth/switch-organization` with legacy fallback.<br>4. Authored and verified `0019_multi_tenant_organizations_and_catalog.sql`. |
| **Phase 3** | Global FMCG Catalog & Indian GST Engine | **PARTIALLY COMPLETED** | 1. Designed `catalog_brands`, `catalog_products`, and `tenant_catalog_mappings` in `0019`.<br>2. Implemented CBIC-standard `calculateGstBreakdown` (CGST, SGST, IGST, Cess, HSN) in `fmcg-engine.ts`.<br>3. Wired tax calculations into order processing.<br>*Pending*: Web catalog subscription portal. |
| **Phase 4** | Double-Entry Inventory & Consignment | **PARTIALLY COMPLETED** | 1. Designed `van_stock_allocations` in `0019`.<br>2. Implemented `POST /van-sales/orders` with vehicle stock verification and deduction.<br>*Pending*: Van stock physical load/unload warehouse screen. |
| **Phase 5** | Logistics, Trips & Last-Mile Delivery | **IMPLEMENTED (Awaiting Verification)** | Built upon `trips.ts` and `0015 migration`, verified order packing guards and delivery OTP verification. |
| **Phase 6** | Retailer Khata & Organization Credit Policy | **COMPLETED** | 1. Implemented `evaluateCreditPolicy` supporting HARD_STOP, WARNING_ONLY, APPROVAL_REQUIRED, and recorded authorized exceptions in `fmcg-engine.ts`.<br>2. Hooked credit policy into `/orders`, `/orders/:id/approve`, and `/van-sales/orders`.<br>3. Implemented double-entry `retailer_ledgers` recording upon delivery.<br>4. Added `/retailers/:id/ledger`, `/credit-policy` GET/PUT endpoints. |
| **Phase 7** | Web Console Multi-Role Expansion | **PARTIALLY COMPLETED** | Basic Owner dashboard exists. Role-partitioned portals for Godown Manager, Dispatcher, and Accountant pending. |
| **Phase 8** | Mobile Offline Sync Alignment | **PENDING** | Alignment of Room DB entities with Migration 0019 schemas (`credit_policies`, `van_stock_allocations`, `retailer_ledgers`). |
| **Phase 9** | Production Verification & Handover | **PENDING** | End-to-end edge and device runtime validation once runtime testing is unlocked. |

---

## 2. Code Changes Delivered in this Iteration

1. [`backend/src/security.ts`](file:///d:/app/backend/src/security.ts):
   - Added `normalizeRole(role)` mapping `SALESPERSON` -> `SALES`, `WAREHOUSE_MANAGER` -> `WAREHOUSE`, `DELIVERY_EXECUTIVE` -> `DELIVERY`.
   - Added `canPerform(role, action)` supporting fine-grained FMCG permissions.
   - Fixed `requirePermission` to inspect authenticated context `user`.
   - Added `verifyTenantMembership(db, userId, orgId)` with backward-compatible fallback to `users.company_id`.
2. [`backend/src/fmcg-engine.ts`](file:///d:/app/backend/src/fmcg-engine.ts) *(New File)*:
   - `calculateGstBreakdown`: Computes taxable amount, CGST, SGST, IGST, Cess, and total lines.
   - `evaluateCreditPolicy`: Enforces organization credit policies (`HARD_STOP` by default, `WARNING_ONLY`, `APPROVAL_REQUIRED`), checks overdue invoices past payment terms, and requires recorded reasons for authorized overrides.
   - `buildRetailerLedgerStatements`: Generates atomic double-entry ledger entries for `retailer_ledgers` and synchronizes `retailers.outstanding_amount_paise`.
3. [`backend/src/index.ts`](file:///d:/app/backend/src/index.ts):
   - Removed query-string token fallback in `authMiddleware`.
   - Multi-tenant tenant verification checking `organization_memberships`.
   - Added `organizations` list to `POST /auth/login` response.
   - Added `POST /auth/switch-organization` for instant organization switching.
   - Integrated `canPerform` RBAC checks in order submission, approval, and rejection.
   - Enforced credit policy evaluation in `POST /orders` and `POST /orders/:id/approve`.
   - Appended double-entry Khata ledger entries in `POST /orders/:id/deliver`.
   - Added `POST /van-sales/orders` with allocated van stock checking, credit evaluation, and provisional sync support.
   - Added `GET /retailers/:id/ledger` exposing double-entry transaction history.
   - Added `GET /credit-policy` and `PUT /credit-policy` for organization credit control.
4. [`backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql):
   - Corrected foreign key from non-existent `shops` to `retailers(id)`.
   - Expanded role check constraints to allow both legacy (`SALESPERSON`, `WAREHOUSE_MANAGER`, `DELIVERY_EXECUTIVE`) and canonical role strings.
   - Added `credit_policies` and `credit_overrides` tables.
   - Added van sales columns (`is_van_sale`, `van_trip_id`, `is_provisional`) to `orders`.

---

## 3. Phase 3 Targeted Integrity Remediation Summary (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**.

1. **Fix 1: Van-Sales Integrity Hardening** ([`backend/src/index.ts`](file:///d:/app/backend/src/index.ts#L2623-L2835)):
   - Enforced vehicle custody check: validates trip belongs to active tenant and caller is driver (`trip.driver_user_id === user.sub`), assigned trip salesperson, beat assigned, or owner/admin.
   - Strict allocation presence: rejects van sale if product allocation record is missing or inactive (prevents bypass).
   - Atomic conditional stock updates: `UPDATE van_stock_allocations SET delivered_qty = delivered_qty + ? WHERE ... AND (allocated_qty - delivered_qty) >= ?` prevents racing concurrent orders from overselling vehicle stock.
   - Replay protection: verifies request against `idempotency_records` using actor, company, and SHA-256 request payload hash.
   - Server-side price & tax re-validation: recalculates GST and prices from database catalog rather than accepting raw client numbers.
   - Explicit provisional handling: when `isProvisional = true`, status is set to `SUBMITTED`, vehicle stock is not deducted, and no customer invoice is created until approved/delivered.

2. **Fix 2: Credit Policy Engine Correction** ([`backend/src/fmcg-engine.ts`](file:///d:/app/backend/src/fmcg-engine.ts#L161-L225)):
   - Overdue invoice query: replaced incorrect `orders` check (`total_amount_paise - delivered_amount_paise > 0`) with accurate `invoices` check (`total_amount_paise - paid_paise - credited_paise > 0 AND created_at <= ?`).
   - Unfulfilled order exposure: aggregated total value of pending unfulfilled orders (`SUBMITTED`, `PENDING_APPROVAL`, `APPROVED`, `PICKING`, `PACKED`, `OUT_FOR_DELIVERY`) into `currentExposurePaise` to prevent concurrent order credit bypass.
   - Retained safe fallback for legacy database schemas.

3. **Fix 3: Tenant Revocation Defense** ([`backend/src/security.ts`](file:///d:/app/backend/src/security.ts#L98-L115), [`backend/src/index.ts`](file:///d:/app/backend/src/index.ts#L88-L105)):
   - Updated `verifyTenantMembership`: an explicit membership with `is_active !== 1` immediately returns `{ isMember: false, role: null }` without falling back to `users.company_id`.
   - Integrated active tenant membership enforcement into `authMiddleware` for all requests operating on tenant resources.

4. **Fix 4: Comprehensive Role Normalization** ([`backend/src/warehouse.ts`](file:///d:/app/backend/src/warehouse.ts), [`backend/src/trips.ts`](file:///d:/app/backend/src/trips.ts), [`backend/src/daily-cycle.ts`](file:///d:/app/backend/src/daily-cycle.ts), [`backend/src/governance.ts`](file:///d:/app/backend/src/governance.ts)):
   - Normalized role comparisons using `normalizeRole()` across godown operations, driver lookups, dispatch batches, trips, cash handovers, collections, daily closings, returns, and payment verifications.
   - Ensured queries accepting legacy and canonical role strings (e.g. `IN ('SALESPERSON', 'SALES', 'DELIVERY_EXECUTIVE', 'DELIVERY')`) resolve seamlessly.

5. **Fix 5: Cross-Tenant Payment Isolation** ([`backend/src/governance.ts`](file:///d:/app/backend/src/governance.ts#L441-L490)):
   - Added explicit tenant qualification `WHERE id = ? AND company_id = ?` to `collections` table update queries in `POST /payments/:id/verify` and `POST /payments/:id/clear`.
   - Normalized role permission enforcement.

6. **Fix 6: Migration Schema Cleanup & Redundancy Assessment** ([`backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql)):
   - Assessed `orders.van_trip_id` redundancy against canonical `orders.trip_id` (established in `0015_delivery_trips_and_sequencing.sql`).
   - Documented backward-compatible coexistence: canonical `trip_id` serves as primary foreign key, `is_van_sale` identifies spot-billing, and `is_provisional` controls unconfirmed offline orders.

---

## 4. Phase 3.2 Critical Integrity Remediation Summary (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**.

1. **Priority 1 & 2: Van-Stock Overselling & Multi-Batch FEFO Allocations** ([`backend/src/index.ts`](file:///d:/app/backend/src/index.ts), [`backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql)):
   - Replaced single-row assumption with multi-allocation query ordered by FEFO batch expiration (`product_batches.expiry_date ASC, vsa.created_at ASC`).
   - Verified total vehicle stock across all active allocation rows before deducting.
   - Targeted updates by distinct allocation primary key (`WHERE id = alloc.id AND company_id = ? AND (allocated_qty - delivered_qty) >= ?`).
   - Enforced DB check constraint `CHECK(delivered_qty >= 0 AND delivered_qty <= allocated_qty)` and database trigger `trg_van_stock_allocation_guard` to abort invalid quantities.
   - Maintained atomic batch transaction: if any update fails, entire batch rolls back.

2. **Priority 3: Mandatory Idempotency in Van-Sales** ([`backend/src/index.ts`](file:///d:/app/backend/src/index.ts)):
   - Strictly required idempotency key (minimum 6 characters) via header, body, or order payload. Returns HTTP 400 if missing or invalid.
   - Replays cached response only on matching actor, company, operation, and SHA-256 payload hash; returns HTTP 409 on conflict.

3. **Priority 4: Provisional Van-Sale Lifecycle & Trigger Safety** ([`backend/src/index.ts`](file:///d:/app/backend/src/index.ts), [`backend/migrations/0020_van_sales_state_machine.sql`](file:///d:/app/backend/migrations/0020_van_sales_state_machine.sql)):
   - Guarded standard order approval endpoint (`POST /orders/:id/approve`) to reject van-sales orders (`is_van_sale === 1`) with descriptive HTTP 400.
   - Created orders with both `trip_id` and `van_trip_id`, `is_van_sale = 1`, and `is_provisional`.
   - Documented architectural constraint: provisional van sales finalization requires forward migration `0020_van_sales_state_machine.sql` to update `trg_order_status_transition_guard`.

4. **Priority 5: Credit Policy Concurrency & Exposure Precision** ([`backend/src/fmcg-engine.ts`](file:///d:/app/backend/src/fmcg-engine.ts), [`backend/src/index.ts`](file:///d:/app/backend/src/index.ts)):
   - Eliminated double-counting between `credit_reservations` and unfulfilled orders: relies authoritatively on `credit_reservations` when table exists, falling back to `orders` only if table is absent (`no such table`).
   - Configured fail-closed behavior on real database errors (permission errors, disk I/O, locks) rather than silently permitting credit limit breaches.
   - Added conditional update check on retailer balance `AND (outstanding_amount_paise + ?) <= (credit_limit_paise + ?)` to prevent racing credit van sales.

5. **Priority 6: Tenant Scoping on GRN Inward Stock & Role Normalization** ([`backend/src/governance.ts`](file:///d:/app/backend/src/governance.ts)):
   - Added explicit tenant qualification and status guard `WHERE id = ? AND company_id = ? AND status = 'PENDING_APPROVAL'` to `UPDATE goods_receipt_notes` in `POST /grn/:id/approve`.
   - Normalized role checks in `/payments/verification-queue`, `POST /suppliers`, and GRN management using `normalizeRole()`.

---

## 5. Phase 3.3 Provisional Van-Sale Lifecycle Completion Summary (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**.

1. **Dedicated Provisional Van-Sale Confirmation (`POST /van-sales/orders/:id/confirm`)** ([`backend/src/index.ts`](file:///d:/app/backend/src/index.ts)):
   - Authenticates caller and verifies active tenant membership via `verifyTenantMembership()`.
   - Enforces vehicle custody and trip assignment rules: caller must be driver, trip salesperson, beat assigned, or owner/admin.
   - Strictly enforces idempotency: repeated confirmations return original delivery response without duplicate stock movements, invoices, or ledger entries.
   - Revalidates product active state, price, GST, and van stock across FEFO batches.
   - Upon stock deficit: preserves submitted offline order and idempotency key, records auditable `VAN_STOCK_DISCREPANCY` in `audit_logs`, and returns structured HTTP 409 conflict. Does not invent negative stock or financial postings.
   - Evaluates credit policy with `newOrderAmountPaise: 0` to prevent double-counting existing `credit_reservations`.
   - Executes atomic batch updating `orders.status = 'DELIVERED'`, deducting allocations, updating `order_items.delivered_quantity`, creating invoice, updating `retailers.outstanding_amount_paise`, appending `retailer_ledgers`, and writing idempotency record.

2. **D1 Batch Atomicity & Error Invariants** ([`backend/src/index.ts`](file:///d:/app/backend/src/index.ts), [`backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql)):
   - Stock update statements target allocation primary key (`WHERE id = alloc.id AND company_id = ?`) without conditional zero-row filters.
   - Database trigger `trg_van_stock_allocation_guard` and `CHECK(delivered_qty <= allocated_qty)` immediately trigger `RAISE(ABORT)` when quantity exceeds allocation, rolling back the entire batch.
   - Added `trg_van_stock_allocation_status_guard` to abort updates on reconciled or inactive allocations.

3. **Android Client Synchronization Contract Alignment** ([`app/src/main/java/com/routeflow/app/data/sync/OrderSyncWorker.kt`](file:///d:/app/app/src/main/java/com/routeflow/app/data/sync/OrderSyncWorker.kt), [`RouteFlowApi.kt`](file:///d:/app/app/src/main/java/com/routeflow/app/core/network/api/RouteFlowApi.kt), [`RouteFlowDtos.kt`](file:///d:/app/app/src/main/java/com/routeflow/app/core/network/dto/RouteFlowDtos.kt)):
   - Added `VanSaleSubmitRequest` and `VanSaleSubmitResponse` DTOs.
   - Added `submitVanSale` and `confirmVanSale` Retrofit endpoints with stable `Idempotency-Key` headers.
   - Wired `VAN_SALE_ORDER` and `VAN_SALE_CONFIRM` into `OrderSyncWorker` FIFO execution loop, reusing stable client `event.idempotencyKey` across all retries.
   - Permanent 4xx failures (including 409 conflict) quarantine the sync item into `NEEDS_ATTENTION` state without discarding offline data.

---

## 6. Phase 3.4 Static Integrity Audit & Targeted Remediation Summary (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**.

1. **Defect Remediation A: Silent Non-Aborting Credit Overdraw in Spot-Bills** ([`backend/migrations/0019_multi_tenant_organizations_and_catalog.sql`](file:///d:/app/backend/migrations/0019_multi_tenant_organizations_and_catalog.sql#L180-L198), [`backend/src/index.ts`](file:///d:/app/backend/src/index.ts)):
   - *Problem*: In D1 `env.DB.batch(statements)`, an `UPDATE ... WHERE condition` that matches 0 rows returns `changes: 0` without throwing an exception. In `POST /van-sales/orders`, concurrent requests racing against credit limits would have the second update match 0 rows without failing the batch, allowing invoices and delivery records to be created while silently skipping balance tracking.
   - *Static Fix*: Added SQLite trigger `trg_retailer_credit_balance_guard` raising `RAISE(ABORT)` on unauthorized limit breaches. Updated `POST /van-sales/orders` to execute direct balance updates with authorized overrides recorded in `credit_overrides`, guaranteeing batch abortion on credit policy violations.

2. **Defect Remediation B: Concurrent Confirmation Race Guarding** ([`backend/src/index.ts`](file:///d:/app/backend/src/index.ts#L3180-L3186)):
   - *Problem*: In `POST /van-sales/orders/:id/confirm`, the order transition query included `AND status = 'SUBMITTED'`. Under concurrent execution, request B's update matched 0 rows, bypassing `trg_order_status_transition_guard` which only fires on matching row updates.
   - *Static Fix*: Changed update target to `WHERE id = ? AND company_id = ?`. If request B attempts to transition an already-delivered order, SQLite fires `trg_order_status_transition_guard`, which evaluates `OLD.status = 'DELIVERED'` and immediately raises `RAISE(ABORT)`, terminating the entire D1 batch.

3. **Defect Remediation C: Android Room Sync State Synchronization** ([`app/src/main/java/com/routeflow/app/data/sync/OrderSyncWorker.kt`](file:///d:/app/app/src/main/java/com/routeflow/app/data/sync/OrderSyncWorker.kt)):
   - *Problem*: `OrderSyncWorker` acknowledged server responses for `VAN_SALE_ORDER` and `VAN_SALE_CONFIRM` without updating local Room database order entities in `localCommit`, leaving local UI state disconnected from synced server state.
   - *Static Fix*: Wired `database.orderDao().updateOrderStatus(orderId, newStatus, timestamp)` inside `localCommit` within the transaction block.

4. **Static Verification of Core Invariants**:
   - *D1 Transaction Atomicity*: Verified that all multi-statement operations in `/van-sales/orders` and `/van-sales/orders/:id/confirm` are executed via single `env.DB.batch(statements)` calls with trigger-enforced abort semantics.
   - *Credit Reservation Precision*: Verified that `POST /van-sales/orders/:id/confirm` passes `newOrderAmountPaise: 0` during credit evaluation to avoid double-counting orders already present in `credit_reservations`. When transitioning to `DELIVERED`, `release_order_credit` releases reservation as `retailers.outstanding_amount_paise` increases by identical amount.
   - *Payload Hash Verification*: Verified that idempotency replays strictly compare SHA-256 hashes of the incoming payload against stored hashes.
   - *Migration Upgrade Path*: Verified that provisional van-sales lifecycle depends on proposed migration `0020_van_sales_state_machine.sql` and that legacy migrations (0001-0018) remain strictly immutable.

---

## 7. Phase 3.4.1 Deep Static Audit & Risk Resolution (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**. Canonical report: [`docs/PHASE_3_4_1_AUDIT.md`](file:///d:/app/docs/PHASE_3_4_1_AUDIT.md).

1. **Migration Upgrade Path & Lineage Restoration**:
   - Identified retroactive additions to historical migration `0019_multi_tenant_organizations_and_catalog.sql`.
   - Restored `0019` baseline by unbundling `trg_van_stock_allocation_status_guard` and removing flawed `trg_retailer_credit_balance_guard`.
   - Preserved `0020_van_sales_state_machine.sql` (updating `trg_order_status_transition_guard` for van sales).
   - Created clean forward migration [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql) to isolate `trg_van_stock_allocation_status_guard` and index `idx_van_stock_company_trip_status`.
   - Formally documented deterministic execution behavior for both fresh databases and already-migrated environments.

2. **Credit Override Integrity & Concurrency Invariants**:
   - Audited `credit_overrides` table: confirmed it is an append-only audit trail lacking lifecycle columns (`status`, `consumed_at`, `expires_at`).
   - Discovered and resolved severe regression in `trg_retailer_credit_balance_guard`: the trigger treated historical audit entries as immortal credit limits and aborted legitimate deliveries in `POST /orders/:id/deliver`. Removed the trigger.
   - Verified canonical credit reservation mechanics via migration 0009 and 0012: `orders.credit_override_paise` columns are correctly populated in `POST /van-sales/orders`, enabling trigger-based reservation protection for provisional orders.
   - Formally documented unresolved architectural decision regarding direct spot-billing credit concurrency.

3. **Concurrent Confirmation & Replay Invariants**:
   - Statically traced complete SQL statement execution order for concurrent confirmations with identical vs. differing idempotency keys.
   - Proved that `trg_order_status_transition_guard` aborts secondary confirmations attempting `DELIVERED -> DELIVERED` transitions, guaranteeing that invoices (`UNIQUE(order_id)`), ledger entries, and van stock allocations (`CHECK(delivered_qty <= allocated_qty)`) cannot be duplicated.

4. **Android Outbox Call Sites & Recovery Guarantees**:
   - Traced all real enqueue call sites across `NetworkOrderRepository.kt` and `DurableFieldRepository.kt`.
   - Clarified that while `OrderSyncWorker.kt` has been fully wired to dispatch and sync `VAN_SALE_ORDER` and `VAN_SALE_CONFIRM`, the repository and UI enqueue sites are intentionally scheduled for Phase 4.
   - Verified that worker crash recovery is completely idempotent due to server-side `idempotency_records` deduplication.

---

## 8. Phase 3.5 Spot-Bill Credit Integrity & Verification Planning (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**. Canonical reports: [`docs/PHASE_3_5_AUDIT.md`](file:///d:/app/docs/PHASE_3_5_AUDIT.md) and [`docs/PHASE_3_5_VERIFICATION_PLAN.md`](file:///d:/app/docs/PHASE_3_5_VERIFICATION_PLAN.md).

1. **Direct Spot-Bill Credit Concurrency Resolution**:
   - *Problem*: Immediate van spot-bills (`isProvisional = false`, `status = 'DELIVERED'`) bypassed `SUBMITTED` state, meaning trigger `reserve_order_credit` did not run. Racing spot-bills for the same retailer could exceed credit limits without database aborts.
   - *Static Fix*: Authored `trg_spot_bill_credit_guard` in [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql). The trigger evaluates `BEFORE INSERT ON orders WHEN NEW.status = 'DELIVERED' AND NEW.payment_method = 'CREDIT'` and immediately raises `RAISE(ABORT)` if `outstanding + existing reservations + NEW.total > credit_limit + NEW.credit_override_paise`.
   - *Atomicity*: Fires on statement 1 of the D1 batch, guaranteeing that stock deductions, invoices, and ledger entries cannot commit on breached credit limits.

2. **Van-Stock Transaction Integrity & Invariant Hardening**:
   - Verified primary key targeting and `CHECK(delivered_qty <= allocated_qty)` constraints in `van_stock_allocations`.
   - Updated catch block in `POST /van-sales/orders` ([`backend/src/index.ts`](file:///d:/app/backend/src/index.ts#L2953-L2966)) to detect trigger abort messages and return structured HTTP 409 responses with error codes `CREDIT_LIMIT_BREACH` and `VAN_STOCK_BREACH`.

3. **Migration Sequence & Lineage Verification**:
   - Confirmed migration order: 0019 (clean baseline) → 0020 (state machine trigger) → 0021 (van stock and spot-bill credit guards).
   - Ensured zero schema collisions between fresh and already-migrated database execution paths.

4. **Non-Destructive Verification Plan Prepared**:
   - Authored [`docs/PHASE_3_5_VERIFICATION_PLAN.md`](file:///d:/app/docs/PHASE_3_5_VERIFICATION_PLAN.md) detailing test prerequisites, backup procedures, 5 key concurrency and rollback simulation scenarios, and database invariant queries.

---

## 9. Phase 3.6 Credit Override Authorization & Transaction Integrity Audit (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**. Canonical report: [`docs/PHASE_3_6_AUDIT.md`](file:///d:/app/docs/PHASE_3_6_AUDIT.md).

1. **Credit Override Authorization Hardening**:
   - Verified that `credit_override_by` is strictly bound to authenticated `user.sub` (preventing client identity forgery).
   - Confirmed that capability `retailer:credit_override` is required and restricted to `OWNER` and `ADMIN`.
   - Remediated double-counting in `POST /orders/:id/retry-delivery` ([`backend/src/index.ts:1734`](file:///d:/app/backend/src/index.ts#L1734)) by excluding the current order (`AND order_id != ?`) from active reservations query.
   - Proved that credit overrides are scoped strictly to specific `orders` rows and never permanently alter `retailers.credit_limit_paise`.

2. **Trigger NULL-Safety & Fail-Closed Enforcement**:
   - *Problem*: In initial trigger design, ternary logic (`NULL > NULL`) caused SQLite to evaluate conditions as NULL, bypassing `RAISE(ABORT)` if retailer was missing or credit limit was NULL.
   - *Static Fix*: Updated `trg_spot_bill_credit_guard` in [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql#L31-L71) with explicit `NOT EXISTS` retailer check, negative amount aborts, and `COALESCE(..., 0)` wrappers on all arithmetic.

3. **Van-Stock Transaction Boundary & Zero-Row Hazard Analysis**:
   - Documented SQLite engine caveat where an `UPDATE` matching 0 rows does not fire row-level triggers or fail the D1 batch.
   - Identified that an INSERT-driven trigger model guarantees trigger evaluation for every deduction operation.
   - Added structured HTTP 404 response for `RETAILER_NOT_FOUND` in `POST /van-sales/orders` ([`backend/src/index.ts:2954`](file:///d:/app/backend/src/index.ts#L2954)).

---

## 10. Phase 3.7 Zero-Row Transaction Safety & Credit-Path Coverage (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**. Canonical report: [`docs/PHASE_3_7_AUDIT.md`](file:///d:/app/docs/PHASE_3_7_AUDIT.md).

1. **Zero-Row Stock Deduction Hazard Resolved via `van_stock_deductions`**:
   - *Problem*: In SQLite / D1 `batch(statements)`, conditional `UPDATE` matching 0 rows succeeds with `changes: 0`. Row-level triggers do not fire when 0 rows match. In D1 batching, subsequent statements (order, invoice, Khata debit) commit even if stock was never deducted.
   - *Static Fix*: Created `van_stock_deductions` table in [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql#L81-L142) with a guaranteed `BEFORE INSERT` trigger (`trg_van_stock_deduction_guard`) and companion `AFTER INSERT` updater (`trg_van_stock_deduction_apply`).
   - *Guaranteed Trigger Mechanics*: Unlike `UPDATE`, an `INSERT` always provides a target row. The `BEFORE INSERT` trigger validates allocation existence, active status (`IN ('ALLOCATED', 'IN_TRANSIT')`), and available stock balance (`(allocated_qty - delivered_qty) >= quantity`). Any breach executes `RAISE(ABORT)` and rolls back the batch instantly.
   - *Application Wiring*: Updated both `POST /van-sales/orders` ([`backend/src/index.ts:2780-2805`](file:///d:/app/backend/src/index.ts#L2780-L2805)) and `POST /van-sales/orders/:id/confirm` ([`backend/src/index.ts:3172-3196`](file:///d:/app/backend/src/index.ts#L3172-L3196)) to insert into `van_stock_deductions` when the table exists, with graceful fallback to legacy direct updates.

2. **Comprehensive Credit-Policy Coverage Matrix Formalized**:
   - Formalized the single authoritative platform exposure formula:
     $$\text{Total Exposure} = \text{Retailer Outstanding Balance} + \sum(\text{Active Order Reservations}) + \text{New Order Amount}$$
   - Mapped all 8 lifecycle paths: Normal orders (`SUBMITTED`), Approved warehouse orders, Failed deliveries and retries, Immediate van spot-bills, Provisional van sales & confirmations, Cash/UPI sales, Authorized credit overrides, and Payments/cancellations/reversals.
   - Confirmed zero double-counting across all paths, with delivery retry reservation exclusion verified at source.

3. **Migration Lineage Verified (0009-0021)**:
   - Proved clean schema lineage across fresh and upgraded execution paths.
   - Confirmed that migrations 0020 (state machine) and 0021 (guards and deduction table) apply non-destructively.

---

## 11. Phase 3.8 Final Backend Integrity Review (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**. Canonical report: [`docs/PHASE_3_8_AUDIT.md`](file:///d:/app/docs/PHASE_3_8_AUDIT.md).

1. **`van_stock_deductions` Schema & Trigger Hardening**:
   - Added `product_id` column, foreign key, index, and table constraint `CONSTRAINT uq_van_stock_deduction_order_alloc UNIQUE (order_id, allocation_id)` in [`backend/migrations/0021_van_stock_lifecycle_guards.sql`](file:///d:/app/backend/migrations/0021_van_stock_lifecycle_guards.sql#L81-L145).
   - Hardened `trg_van_stock_deduction_guard` with 4 explicit checks: (1) Allocation exists with matching `company_id`, `trip_id`, and `product_id`; (2) Allocation is active (`ALLOCATED` or `IN_TRANSIT`); (3) Allocation has remaining stock $\ge \text{quantity}$; (4) Order exists with matching `company_id` and `trip_id`.
   - Prevented cross-trip or cross-product deduction and duplicate order deduction rows.

2. **Unsafe Silent Fallback Eliminated**:
   - Purged all conditional fallback branches to raw `UPDATE van_stock_allocations` in `POST /van-sales/orders` ([`backend/src/index.ts:2730-2745`](file:///d:/app/backend/src/index.ts#L2730-L2745)) and `POST /van-sales/orders/:id/confirm` ([`backend/src/index.ts:3120-3135`](file:///d:/app/backend/src/index.ts#L3120-L3135)).
   - Handlers check for both `van_stock_deductions` table and `trg_van_stock_deduction_guard` trigger in `sqlite_master`; if missing, they fail closed immediately with HTTP 503 (`SCHEMA_MIGRATION_REQUIRED`), preventing silent stock corruption.

3. **Tenant-Scoped Ledger Subqueries**:
   - Added missing `AND company_id = ?` filter to subqueries selecting `FROM retailers` in collection reversals and return credit notes in [`backend/src/daily-cycle.ts:143, 333, 342`](file:///d:/app/backend/src/daily-cycle.ts#L143).

---

## 12. Phase 3.9 Pre-UI Backend Sign-off (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**. Canonical report: [`docs/PHASE_3_9_AUDIT.md`](file:///d:/app/docs/PHASE_3_9_AUDIT.md).

1. **Deduction Data-Model Validation & Order-Item Bounding**:
   - Validated that multiple allocation rows (batches) can legitimately fulfil one order item under FEFO rules.
   - Enforced database-level quantity bounding in `trg_van_stock_deduction_guard`: verifies that the order item exists for `(order_id, product_id)` and that $\sum(\text{deductions}) \le \text{order\_item.quantity}$.
   - Statically proved that because duplicate products within an order are rejected (`seenProducts`), `UNIQUE(order_id, allocation_id)` correctly models the domain without limiting multi-batch fulfilment.

2. **Migration Lineage Hardening & Forward Migration 0022**:
   - Preserved `backend/migrations/0021_van_stock_lifecycle_guards.sql` at its baseline state to protect existing environments where 0021 may have already been applied.
   - Authored forward migration `backend/migrations/0022_van_stock_deduction_item_guards.sql` containing forward-only DDL: `ALTER TABLE van_stock_deductions ADD COLUMN product_id`, unique index, trip/order indexes, and the comprehensive 7-point relational and quantity guard trigger.
   - Updated `backend/src/index.ts` to inspect `PRAGMA table_info(van_stock_deductions)`; fails closed with HTTP 503 (`SCHEMA_MIGRATION_REQUIRED`) if either migration 0021 or 0022 is missing.

3. **Transaction Atomicity & Idempotency Sign-off**:
   - Statically proved that all spot-bill writes (order, items, deductions, balance, invoices, ledgers, idempotency) commit or roll back as an atomic unit.
   - Statically proved that secondary confirmation requests cannot re-deduct stock or duplicate invoices due to `trg_order_status_transition_guard` and `uq_van_stock_deduction_order_alloc`.
   - Verified that credit overrides are server-evaluated, bounded, and bound to `user.sub`.

---

## 13. Phase 3.10 Final Static Integrity Audit (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**. Canonical report: [`docs/PHASE_3_10_AUDIT.md`](file:///d:/app/docs/PHASE_3_10_AUDIT.md).

1. **Migration 0022 Backfill & Legacy Deduplication**:
   - Verified that `ALTER TABLE van_stock_deductions ADD COLUMN product_id` produces `NULL` for existing rows. Added safe backfill from `van_stock_allocations` in [`backend/migrations/0022_van_stock_deduction_item_guards.sql`](file:///d:/app/backend/migrations/0022_van_stock_deduction_item_guards.sql#L25-L38).
   - Added deduplication query before `CREATE UNIQUE INDEX` to ensure legacy duplicate deductions cannot cause index creation failure.

2. **Order-Item Non-Uniqueness Hardening**:
   - Statically verified that `order_items` lacks a database-level `UNIQUE(order_id, product_id)` constraint.
   - Corrected trigger Check 7 in migration 0022 to use `SUM(oi.quantity)` instead of scalar subquery `SELECT oi.quantity`, deterministically aggregating total ordered quantities across all line items for that SKU in that order.

3. **Catch-Block Error Response Sanitization**:
   - Updated catch blocks in `POST /van-sales/orders` ([`backend/src/index.ts:2988-3004`](file:///d:/app/backend/src/index.ts#L2988-L3004)) and `POST /van-sales/orders/:id/confirm` ([`backend/src/index.ts:3370-3395`](file:///d:/app/backend/src/index.ts#L3370-L3395)).
   - Mapped trigger aborts to structured error codes (`DUPLICATE_DEDUCTION_CONFLICT`, `ORDER_ITEM_QUANTITY_BREACH`, `DUPLICATE_CONFIRM_CONFLICT`) and sanitized fallback responses, preventing raw database internal strings from leaking to clients.

4. **Phase 4 Readiness Recommendation**:
   - Confirmed that backend contracts, schemas, error codes, and DTOs are locked and stable.
   - Recommended that Phase 4 Mobile Van-Sales UI development can proceed immediately without waiting for runtime backend verification, as mobile UI connects cleanly to the locked Retrofit contracts and Room offline models.

---

## 14. Phase 4.0 Android Van-Sales UI Foundation (Pure Static Edits)

All corrections below carry the verified status: **Source corrected — not runtime-verified**. Canonical report: [`docs/PHASE_4_0_IMPLEMENTATION.md`](file:///d:/app/docs/PHASE_4_0_IMPLEMENTATION.md).

1. **Role Capability Enforcement**:
   - Verified that van sales creation is permitted for `OWNER`, `ADMIN`, `SALESPERSON`, and `DELIVERY_EXECUTIVE` in accordance with server capability `van_sales:create`.
   - Built a permission gate in `VanSalesViewModel` that blocks unauthorized roles (`RETAILER`, `WAREHOUSE`) from executing sales.

2. **Trip & Vehicle Stock Context Validation (Fail-Closed Guard)**:
   - Evaluates active trip presence (`('PLANNED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY')`).
   - If trip context is missing, the screen prominently renders a blocking warning card and disables item addition and checkout, strictly upholding the server invariant that spot sales require a vehicle allocation trip ID.

3. **Retailer Credit Health & Limit Warnings**:
   - Integrated live retailer balance (Pending Udhaar, Advance, or No Due) and credit limit metrics.
   - Implemented real-time credit check for `CREDIT` payments, rendering warning alerts when the estimated order total will exceed the retailer's limit and prompting for authorized override reasons.

4. **Integer Financial Calculation & Provisional Disclaimers**:
   - Enforced integer paise math (`Long`) across cart subtotals, 18% GST estimate, and grand total.
   - Surfaced persistent non-authoritative disclaimers in the cart summary and confirmation dialogs explicitly noting that final line item pricing, taxes, schemes, and stock deductions are evaluated authoritatively by the server.

5. **Room Outbox & WorkManager Pipeline Integration**:
   - Implemented `submitVanSaleOrder` in `NetworkOrderRepository` and `OfflineOrderRepository`.
   - Generates stable UUID idempotency keys persisted with the order and outbox row (`type = "VAN_SALE_ORDER"`).
   - Atomically records local order and outbox entity in Room via `database.withTransaction`.
   - Employs immediate online submission with graceful fallback to WorkManager background queueing for transient/offline states and quarantines permanent 4xx errors into `NEEDS_ATTENTION` (`lastError = "VALIDATION_REVIEW"`).

6. **Navigation & Entry Points**:
   - Created route `sales/van-sale/{retailerId}` with localized TopAppBar titles.
   - Added primary CTA button on `SalesHomeScreen` ("Van Spot Sale (Vehicle Stock)") and in-visit action tile on `ShopVisitScreen`.











