# RouteFlow Implementation Status

## Current Stage
**Stage 2: Backend API Contract, Token Lifecycle, Stock Ledger, and Full Order Journey (Completed & Verified)**

---

## 1. Secrets & Credentials Isolation
- **Rotated Development JWT Secret**: The development signing secret has been rotated to a high-entropy cryptographically generated key stored exclusively in `.dev.vars` (gitignored).
- **Session Revocation**: All prior development sessions and refresh tokens were invalidated in the D1 database.
- **Strict Secrecy**: No secrets, private keys, passwords, or token strings are committed to Git, logged, or recorded in status documents.
- **Seed Separation**: Development seed data is completely separated into `backend/seeds/dev_seeds.sql`. Production migrations (`0001_initial.sql`, `0002_seeds.sql`, `0003_order_lifecycle.sql`) contain only schema definitions, performance indices, and integrity triggers without any shared test credentials.
- **Reference Preservation**: Existing IDs (`comp_1`, `ret_1`, `prod_1`, `prod_2`) are preserved when expanding local seed data (`R1`–`R6`, `P1`–`P10`).

---

## 2. API Contract & Network DTO Architecture
- **Dedicated `@Serializable` DTOs**: Created in `com.routeflow.app.core.network.dto`:
  - `RetailerDto`, `ProductDto`, `OrderDto`, `OrderItemDto`
  - `LoginRequest`, `RefreshRequest`, `UserDto`, `AuthResponse`
  - `OrderSubmitRequest`, `OrderSubmitResponse`, `OrderDetailsResponse`, `StatusResponse`
  - `ItemPickRequest`, `DispatchOrderRequest`, `DeliveryCompletionRequest`, `OrderRejectionRequest`
- **Decoupled Architecture**: Bidirectional mappers (`toEntity()` and `toDto()`) decouple Room database entities from the public API contract.
- **Serialization Invariants**: Standardized camelCase JSON fields, nullable fields for optional server properties (`deliveryEmployeeId`, `rejectionReason`, `paymentMethod`), and boolean serialization for line item status (`isPicked`).
- **DTO Response Decoding Tests**: Comprehensive unit tests in `RouteFlowDtoTest.kt` verifying serialization, deserialization, nullability handling, and entity conversions.

---

## 3. Account-Scoped Cache & Leftover Data Purging
- **Cache Synchronization**: On real authentication in `LoginViewModel`, Room tables (`retailers`, `products`, `orders`, `order_items`) are cleared and atomically repopulated with server-authorized catalog and retailer data in a single database transaction.
- **No Leftover Demo Records**: Clean boundary established between demo mode and real server-backed mode, verified on device.

---

## 4. Server-Backed Order Journey (Verified)

### Test Order ID: `test_ord_1790181454228`
- **Submission**:
  - Salesperson (`user_sales`) submits multi-item order for Retailer `R1` (Item 1: 2 units P1 + 1 free promotional unit; Item 2: 3 units P2).
  - Server validates company isolation, retailer credit limit, product pricing, and deduplicates identical submission via `idempotencyKey`.
  - Initial status: `SUBMITTED`.
- **Owner Approval**:
  - Owner (`user_owner`) retrieves pending list and approves order.
  - Stock is atomically reserved for ordered quantity plus promotional free units (3 units of P1, 3 units of P2).
  - Status transitions to `APPROVED`. Repeated approvals are idempotent.
- **Warehouse Picking**:
  - Warehouse manager (`user_warehouse`) picks items sequentially (`/orders/:id/pick-item`).
  - Item 1 picked (`isPicked = true`), order transitions to `PICKING`.
  - Packing attempt before Item 2 is picked is rejected by server with HTTP 400.
  - Item 2 picked (`isPicked = true`).
- **Warehouse Packing**:
  - Packing succeeds once all items are confirmed picked.
  - Status transitions to `PACKED`.
- **Order Dispatch**:
  - Dispatch attempt without assigned delivery driver is rejected with HTTP 400.
  - Warehouse dispatches order assigned to `user_delivery`.
  - Server atomically updates status to `OUT_FOR_DELIVERY`, deducts physical stock, and releases reservations.
  - Repeated dispatches are idempotent.
- **Delivery Fulfillment**:
  - Unauthorized user (`sales`) attempting delivery is rejected with HTTP 403.
  - Assigned driver (`user_delivery`) completes delivery with payment method `CREDIT`.
  - Server updates status to `DELIVERED` and posts order total (126,000 paise) to retailer `R1` outstanding balance.
  - Repeated delivery requests are idempotent.
- **Rejection & Rollback**:
  - Verified on order `test_rej_*`: Owner rejection records reason and safely releases reserved stock.

### Stock Ledger Tracking (Product `P1`)
| Stage | Stock Quantity | Reserved Quantity | Available Stock | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Initial** | 100 | 0 | 100 | Catalog baseline |
| **After Approval** | 100 | 3 | 97 | 2 ordered units + 1 promotional free unit reserved |
| **After Dispatch** | 97 | 0 | 97 | Reservation released; 3 units physically deducted |

### Retailer Ledger Tracking (Retailer `R1`)
| Stage | Outstanding Balance | Credit Limit | Notes |
| :--- | :--- | :--- | :--- |
| **Initial** | 1,250,000 paise (₹12,500.00) | 5,000,000 paise (₹50,000.00) | Base ledger state |
| **After Credit Delivery** | 1,376,000 paise (₹13,760.00) | 5,000,000 paise (₹50,000.00) | Increased by order total (126,000 paise) |

---

## 5. Security, Concurrency & Invariants Verification

### Authentication & Token Lifecycle
1. **Invalid Credentials**: Rejected with HTTP 401.
2. **Disabled Accounts**: Disabled account rejected on login and token verification with HTTP 403.
3. **Expired & Modified Tokens**: Tampered signature and expired tokens rejected with HTTP 401.
4. **Session Revocation on Logout**: `POST /auth/logout` clears active refresh tokens; subsequent refresh attempts return HTTP 401.
5. **Atomic Refresh Rotation**: New token pair issued; old token recorded as revoked.
6. **Token Reuse Detection**: Replay of old refresh token immediately invalidates all active sessions for the user and returns HTTP 401.
7. **Cross-Company Isolation**: Order submission for retailer belonging to another company or non-existent tenant is rejected with HTTP 400/403.

### Concurrency & Database Invariants
1. **Idempotent Retry**: Lost response replay with same `idempotencyKey` returns existing order without duplication.
2. **Atomic Reservation Triggers**: SQLite database triggers (`trg_check_product_reservation`, `trg_check_product_stock`) strictly enforce non-negative stock and prevent `reserved_quantity > stock_quantity`.
3. **Concurrent Approval Race Protection**: Competing approvals attempting to reserve more stock than available are rejected with HTTP 400; batch transactions roll back completely, ensuring no stock over-reservation.
4. **Failed Operation Rollback**: Price mismatches or credit limit violations roll back completely without inserting partial order records.

---

## 6. Actual Command Execution Results

1. **Backend TypeScript Check**:
   - `npm run types`: **SUCCESS** (types written to `worker-configuration.d.ts`).
2. **Backend Database Seeding**:
   - `npm run seed:local`: **SUCCESS** (4 commands executed successfully).
3. **Backend Integration Tests**:
   - `npm test` (`node --test test/integration.test.mjs`): **PASS** (8 test suites, 8 passed, 0 failed in 2.91s).
4. **Android Build, Unit Tests & Lint**:
   - `.\gradlew.bat assembleDebug testDebugUnitTest lintDebug --no-daemon`: **BUILD SUCCESSFUL** in 2m 23s (61 actionable tasks: 21 executed, 40 up-to-date).
5. **Physical Device Verification (Vivo 1935, Android 10, Serial `4bc99b28`)**:
   - ADB reverse forwarding: `tcp:8787 -> tcp:8787` active.
   - APK install: `Success`.
   - Real server login verified on physical device.
   - Server-authorized retailers (BEAT-04: R1–R6, ret_1) loaded into Room cache and verified on device UI.
   - Logout verified on device UI.

---

## 7. Remaining Items
- **Simultaneous Two-Device Live Testing**: Verification was performed on a single physical Vivo 1935 device using sequential role authentication. Simultaneous two-device live verification remains pending additional physical hardware.
- **Stage 3 Scope**: Outbox WorkManager background synchronization and network retry resilience under disconnected physical Wi-Fi conditions.
