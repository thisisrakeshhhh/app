# RouteFlow Flutter

RouteFlow Flutter is a pilot-ready, offline-first B2B distributor operating system for Indian kirana/FMCG wholesalers. Built with Flutter, Drift SQLite v3, and an atomic local outbox architecture, it powers high-velocity FMCG distribution in low-connectivity wholesale markets.

> **145 / 145 Tests Passing (100%)** • **Drift SQLite v3 Offline Outbox** • **Verified on Physical Android Hardware (Vivo 1935)**

---

## What It Does

```
Kirana Sales Booking ──► Owner Approval ──► Warehouse Picking ──► Driver Delivery OTP ──► Depot Cash Settlement
  (RAM Cart + Outbox)     (Credit & Stock)    (Cartons & Strips)   (Tamper-Proof OTP)     (Driver Balance ₹0.00)
```

1. **Field Sales Booking & Beat Navigation:** Sales reps visit mapped Kirana stores on daily routes (e.g., *Nai Sadak & Sardarpura Beat*), explore wholesale catalog pricing with multi-tier packaging (Boxes, Strips, Units), and book orders completely offline.
2. **Atomic Offline Outbox Persistence:** Order confirmation generates a cryptographically secure UUIDv4 idempotency key and writes an immutable `CREATE_ORDER` mutation to local SQLite disk in a single write transaction.
3. **Strict Stock & Ledger Invariants:** Local bookings hold virtual reservations to prevent overselling, but **never decrement physical warehouse godown stock** or alter retailer ledger balances until warehouse dispatch.
4. **Owner Control & Real-Time KPIs:** Distributors monitor live sales revenue, pending booking approvals, customer credit exposure, and warehouse inventory levels.
5. **Warehouse Picking & Carton Packing:** Godown managers fulfill approved bookings into ready vehicle stock with automated packaging ratio conversions (e.g. 1 Box = 96 Pieces).
6. **Delivery Route Dispatch & Server OTP Verification:** Drivers navigate stop-by-stop routes, collect Cash on Delivery (COD), verify physical handover via 6-digit server OTP, and reconcile driver cash custody down to ₹0.00 at the depot.

---

## 4-Role Field Operations

| Role | Field Operations (Mobile App) | Core Invariants Enforced |
|---|---|---|
| **Sales Representative** | Beat route navigation, Kirana catalog booking, wholesale tiered pricing, in-memory cart preview | Zero-destructive booking, volatile RAM cart, durable local outbox commit, idempotency payload mismatch protection |
| **Owner / Admin** | Credit limit governance, pending booking approvals, live depot revenue, driver cash settlement | Authoritative ledger custody, multi-tenant scoping, real-time KPI aggregates |
| **Warehouse Manager** | Approved picking queue, physical inward stock receipts, vehicle loading, carton packing manifests | Separation of physical godown stock from virtual booking reservations |
| **Delivery Executive** | Stop sequencing, 6-digit server OTP delivery confirmation, physical COD cash custody ledger | Strict cash custody tracking, tamper-proof OTP validation, depot cash handover |

---

## Verified Mobile Screens (Vivo 1935 Hardware)

All mobile screens captured directly from physical **Vivo 1935 (`4bc99b28`)** running the RouteFlow Flutter release:

### Field Sales & Offline Outbox Booking Flow

| 1. Role Authentication | 2. Sales Beat Dashboard | 3. Catalog & Godown Stock |
|:---:|:---:|:---:|
| <img src="screenshots/device_step1_login.png" width="220" alt="Login Portal" /><br><b>4-Role Quick Fill</b><br>Instant role switching & JWT auth | <img src="screenshots/device_step2_quarantine_with_button.png" width="220" alt="Sales Dashboard" /><br><b>Beat Route Active</b><br>12 retail Kirana shops mapped | <img src="screenshots/device_step3_order_taking.png" width="220" alt="Catalog Stock" /><br><b>Live Wholesale Stock</b><br>180 godown boxes on hand |

| 4. Kirana Shop Selection | 5. In-Memory Cart Staging | 6. Checkout Review Sheet |
|:---:|:---:|:---:|
| <img src="screenshots/device_step4_new_order_screen.png" width="220" alt="Shop Select" /><br><b>Retailer Selection</b><br>Shree Ganesh Kirana Store | <img src="screenshots/device_step5_cart_added.png" width="220" alt="Cart Bar" /><br><b>Volatile RAM Cart</b><br>1 Box Kurkure • ₹775.20 | <img src="screenshots/device_step6_review_bottom_sheet.png" width="220" alt="Review Sheet" /><br><b>Review & Taxes</b><br>CGST 6% + SGST 6% • COD/Credit |

| 7. Outbox Mutation Confirmed | 8. Real-Time Sales Turnover | 9. Recent Bookings Stream |
|:---:|:---:|:---:|
| <img src="screenshots/device_step7_order_confirmed.png" width="220" alt="Order Confirmed" /><br><b>Durable Outbox Write</b><br>178 avail • 180 physical godown | <img src="screenshots/device_step8_home_stream.png" width="220" alt="Home Counters" /><br><b>Real-Time Sync</b><br>Bookings: 3 → 4 • ₹54,220 turnover | <img src="screenshots/device_step9_recent_orders_card.png" width="220" alt="Recent Orders" /><br><b>Local Order Stream</b><br>Order LOCAL-ORD-975851-D6715F |

### Multi-Role Operations (Owner, Warehouse & Delivery)

| Admin Control Room | Warehouse Inward Stock | Delivery Driver Handover |
|:---:|:---:|:---:|
| <img src="screenshots/crud_admin_logged_in.png" width="220" alt="Admin Dashboard" /><br><b>Owner Control Room</b><br>Live revenue, credit & staff KPIs | <img src="screenshots/crud_warehouse_logged_in.png" width="220" alt="Warehouse Operations" /><br><b>Warehouse Fulfillment</b><br>Physical godown inward & vehicle dispatch | <img src="screenshots/crud_delivery_handover_verified.png" width="220" alt="Cash Handover" /><br><b>Cash Custody & Settlement</b><br>COD handover to depot settling balance to ₹0.00 |

---

## Offline-First Architecture & Invariants

RouteFlow Flutter implements a rigorous offline-first architecture powered by Drift SQLite:

```
┌────────────────────────────────────────────────────────────────────────┐
│                          LOCAL DEVICE RUNTIME                          │
├────────────────────────────────────────────────────────────────────────┤
│  [ UI Checkout Review ]                                                │
│         │                                                              │
│         ▼ (Generates UUIDv4 checkoutIdempotencyKey)                    │
│  [ Idempotency Mismatch Guard ] ──(Payload Differs?)──► FAIL CLOSED    │
│         │ (Safe Replay / Fresh Key)                                    │
│         ▼                                                              │
│  [ Drift SQLite Transaction (WAL Single-Writer) ]                      │
│         ├── 1. Compute monotonic MAX(sequence_order) + 1 for Org       │
│         ├── 2. Unique Index Check: idx_outbox_org_seq                  │
│         └── 3. Insert immutable CREATE_ORDER mutation into outbox      │
│         │                                                              │
│         ▼                                                              │
│  [ In-Memory DistributorOrder Created (stage: booking) ]               │
│         ├── availableGodownPieces decremented (Virtual Reservation)     │
│         ├── Physical InventorySnapshots UNTOUCHED                      │
│         └── Retailers.outstandingPaise UNTOUCHED                       │
│                                                                        │
│  [ Process Restart / Cold Boot ]                                       │
│         └── _syncFromDatabase() reconstructs all pending outbox rows   │
│             directly into memory without network access!               │
└────────────────────────────────────────────────────────────────────────┘
```

### Verified Outbox Mutation Payload (from Live Device SQLite)

```json
{
  "mutation_id": "out_e83b2d72-c9a6-4497-a7bc-3fc148d0474d",
  "organization_id": "org_jaipur_dist",
  "user_id": "usr_local_sales",
  "sequence_order": 1,
  "mutation_type": "CREATE_ORDER",
  "sync_status": "PENDING",
  "idempotency_key": "5116302f-8df5-424a-bd69-dae232caeeed",
  "provisional_order_id": "ord_1793612975851_d6715f",
  "order_number": "LOCAL-ORD-975851-D6715F",
  "payload": {
    "retailer": {
      "id": "RET-JDH-01",
      "name": "Shree Ganesh Kirana Store",
      "address": "Opp. Ghanta Ghar, Station Rd, Jodhpur"
    },
    "items": [
      {
        "productId": "KURK-01",
        "productName": "Kurkure Masala Munch",
        "orderedUnit": "box",
        "orderedQuantity": 1,
        "stripQty": 12,
        "boxQty": 96,
        "totalPieces": 96,
        "unitPricePaiseAtTime": 77520,
        "taxableAmountPaise": 69214,
        "gstAmountPaise": 8306,
        "lineTotalPaise": 77520
      }
    ],
    "totals": {
      "totalAmountPaise": 77520,
      "taxableAmountPaise": 69214,
      "gstAmountPaise": 8306
    },
    "paymentMode": "COD"
  }
}
```

---

## Automated Test Suite Matrix (145 / 145 Passing)

Every business invariant, role workflow, and database mutation is enforced by comprehensive automated tests:

| Test Suite | File | Tests | Status |
|---|---|:---:|:---:|
| **Order Confirmation Durability** | `test/order_confirmation_durability_test.dart` | 12 | **PASS** |
| **Outbox DAO & Persistence** | `test/outbox_persistence_test.dart` | 8 | **PASS** |
| **Hardcore Four-Role CRUD** | `test/hardcore_four_role_crud_test.dart` | 12 | **PASS** |
| **Ruthless Hardcore Invariants** | `test/ruthless_hardcore_invariant_test.dart` | 15 | **PASS** |
| **Tenant Boundary Containment** | `test/tenant_boundary_containment_test.dart` | 12 | **PASS** |
| **Auth Repository & Multi-Org** | `test/auth_repository_test.dart` | 11 | **PASS** |
| **Auth Lifecycle & Token Rotation** | `test/auth_service_test.dart` | 10 | **PASS** |
| **Delivery OTP & Cash Safety** | `test/delivery_safety_test.dart` | 10 | **PASS** |
| **Role Routing & Dashboard Shell** | `test/role_routing_test.dart` | 7 | **PASS** |
| **Database Migrations (v1 → v2 → v3)** | `test/database_migration_test.dart` | 3 | **PASS** |
| **Order Preview & Cart Safety** | `test/order_preview_safety_test.dart` | 6 | **PASS** |
| **Auth & App Widget Smoke Tests** | `test/auth_ui_test.dart`, `widget_test.dart` | 39 | **PASS** |
| **Total Test Suite** | **18 test files** | **145** | **100% PASS** |

---

## Tech Stack & Dependencies

- **Framework:** Flutter 3.x (Dart 3.x)
- **Local Database:** Drift SQLite v3 with SQLite WAL locking and foreign keys enabled
- **State Management:** Provider with strongly-typed reactive ViewModels
- **UI & Theme:** Custom Airbnb-inspired Design System (`AirbnbTheme`) tailored for high-contrast outdoor visibility in FMCG markets
- **Security:** In-memory transient access tokens, scoped refresh token storage, and tenant boundary gate quarantine

---

## Quick Start Commands

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Code Generation (Drift SQLite & Models)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Run Static Analysis & Verification
```bash
flutter analyze
```

### 4. Run Full Automated Test Suite
```bash
flutter test
```

### 5. Run Focused Durability Test Suite
```bash
flutter test test/order_confirmation_durability_test.dart
```

### 6. Run on Connected Device
```bash
flutter run -d <device-id>
```

### 7. Build Debug / Release Android APK
```bash
# Debug APK
flutter build apk --debug

# Production Release APK
flutter build apk --release
```

---

## License

Proprietary — RouteFlow FMCG Operating System. All rights reserved.
