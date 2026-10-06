# RouteFlow — Warehouse-to-Retailer Logistics & Field Distribution System

> **Designed for Indian FMCG & Kirana Distributors (Jaipur Operations Demo)**  
> **Unified Dual-Platform:** Native Android App (Field Operations) + Next.js Web Dashboard (Office Control)  
> **Live Web Dashboard:** [https://appdashboardadmin.vercel.app](https://appdashboardadmin.vercel.app)  
> **Backend API:** Cloudflare Workers + D1 Serverless SQL  
> **Architecture & Handover Guide:** [PROJECT_GUIDE.md](file:///d:/app/PROJECT_GUIDE.md)

---

## 💻 Section 1: Web Management Console (Office & Owner)

Screenshots captured directly from the live RouteFlow Operations Dashboard:

| Web Login Portal | Web Owner Overview |
|:---:|:---:|
| <img src="docs/screenshots/13_web_login_portal.png" width="480" alt="Web Login" /> | <img src="docs/screenshots/14_web_owner_dashboard.png" width="480" alt="Web Dashboard" /> |
| *Role Quick-Fills: Owner, Admin, Sales, Godown, Driver* | *Executive KPIs: Delivered sales, godown stock, outstanding credit* |

| Orders Management & Approvals | Godown Master Stock & Inventory |
|:---:|:---:|
| <img src="docs/screenshots/15_web_orders_management.png" width="480" alt="Web Orders" /> | <img src="docs/screenshots/16_web_godown_inventory.png" width="480" alt="Web Stock" /> |
| *Status filtering (Pending, Approved, Dispatched, Delivered)* | *Live SKU inventory counts, unit wholesale prices & stock alerts* |

| Retailer Directory & Beat Mapping | Cash Handovers & Ledger Audit |
|:---:|:---:|
| <img src="docs/screenshots/17_web_retailer_directory.png" width="480" alt="Web Retailers" /> | <img src="docs/screenshots/18_web_cash_reconciliation.png" width="480" alt="Web Handovers" /> |
| *Store contact directory, assigned beats & credit limits* | *Driver collection ledger and 1-click cash reconciliation* |

| Add Retailer Modal (GPS Capture) | Add Product Modal (Godown SKU) |
|:---:|:---:|
| <img src="docs/screenshots/19_web_add_retailer_modal.png" width="480" alt="Web Add Retailer" /> | <img src="docs/screenshots/20_web_add_product_modal.png" width="480" alt="Web Add Product" /> |
| *Browser GPS detection, beat assignment & credit limit* | *Item creation with wholesale unit pricing and opening stock* |

---

## 📱 Section 2: Mobile App Visual Tour (Physical Vivo 1935 Phone)

All mobile screenshots captured directly from an actual **Vivo 1935** Android device running the RouteFlow Staging build:

### 1. Authentication & Native Hindi Localization

| Login Screen (English) | Login Screen (Hindi - हिन्दी) |
|:---:|:---:|
| <img src="docs/screenshots/01_login_screen.png" width="340" alt="Login Screen" /> | <img src="docs/screenshots/02_login_hindi_screen.png" width="340" alt="Login Hindi" /> |
| *Role Quick-Fills: Owner, Admin, Sales, Warehouse, Delivery* | *Complete localized interface without text clipping* |

---

### 2. Owner & Executive Control

| Owner Dashboard (English) | Owner Dashboard (Hindi - हिन्दी) |
|:---:|:---:|
| <img src="docs/screenshots/03_owner_dashboard.png" width="340" alt="Owner Dashboard" /> | <img src="docs/screenshots/04_owner_dashboard_hindi.png" width="340" alt="Owner Dashboard Hindi" /> |
| *Business KPIs: Approvals, Stock, Delivered Sales, Outstanding* | *Vernacular interface tailored for Indian wholesale distributors* |

| Owner Orders & Approvals Hub | Owner Master Business Godown Hub |
|:---:|:---:|
| <img src="docs/screenshots/27_owner_orders_approvals.png" width="340" alt="Owner Orders Hub" /> | <img src="docs/screenshots/28_owner_business_hub.png" width="340" alt="Owner Business Hub" /> |
| *Atomic order approvals & physical stock reservation* | *Godown catalog, product pricing & category breakdown* |

| Owner Team Management & Roster | Owner Field Operations Activity |
|:---:|:---:|
| <img src="docs/screenshots/29_owner_team_management.png" width="340" alt="Owner Team" /> | <img src="docs/screenshots/30_owner_field_activity.png" width="340" alt="Owner Activity" /> |
| *Staff directory, assigned beats, phone & role permissions* | *Live field check-ins, sales visits, and GPS audit log* |

---

### 3. Field Sales Operations (Beat, Stores & GPS)

| Sales Today Beat (`BEAT-04`) | Active Beat Shops List |
|:---:|:---:|
| <img src="docs/screenshots/05_sales_today_beat.png" width="340" alt="Sales Today Beat" /> | <img src="docs/screenshots/06_sales_shops_list.png" width="340" alt="Shops List" /> |
| *Assigned Beat, store visits counter, monthly sales target progress* | *Kirana stores on route with live balances & Check-In* |

| Add Shop with Phone GPS | Product Catalog & Order Booking |
|:---:|:---:|
| <img src="docs/screenshots/07_sales_add_shop_gps.png" width="340" alt="Add Shop GPS" /> | <img src="docs/screenshots/08_sales_order_booking.png" width="340" alt="Order Booking" /> |
| *1-Tap GPS detection locks exact shop location* | *Warehouse stock badges, schemes (Buy 10 Get 1 Free), cart* |

| Sales Collections & Payment History | Sales Profile & Shift Tracking |
|:---:|:---:|
| <img src="docs/screenshots/21_sales_collections_ledger.png" width="340" alt="Sales Collections" /> | <img src="docs/screenshots/22_sales_profile_shift.png" width="340" alt="Sales Profile" /> |
| *Store payment records, receipt ledger & cash collections* | *Attendance shift tracker, language toggle & security* |

| Sales Offline Local Sync & Logout |
|:---:|
| <img src="docs/screenshots/23_sales_offline_sync_logout.png" width="340" alt="Sales Sync & Logout" /> |
| *Room DB local cache sync with Cloudflare server & secure logout* |

---

### 4. Warehouse Picking, Driver Delivery & Cash Reconciliation

| Warehouse Picking Queue Desk | Warehouse Stock Inventory & Badges |
|:---:|:---:|
| <img src="docs/screenshots/09_warehouse_picking_queue.png" width="340" alt="Warehouse Picking Queue" /> | <img src="docs/screenshots/24_warehouse_stock_inventory.png" width="340" alt="Warehouse Stock" /> |
| *Godown desk: Approved orders queue, item checklist, packing* | *Godown SKU counts, threshold alerts & inventory levels* |

| Warehouse Returns Processing Desk | Delivery Route Day Overview |
|:---:|:---:|
| <img src="docs/screenshots/25_warehouse_returns_desk.png" width="340" alt="Warehouse Returns Desk" /> | <img src="docs/screenshots/26_delivery_day_overview.png" width="340" alt="Delivery Day" /> |
| *Damaged / rejected goods inspection desk* | *Assigned route trip progress & stops remaining* |

| Delivery Route Assigned Orders | Server OTP Delivery Verification |
|:---:|:---:|
| <img src="docs/screenshots/10_delivery_assigned_orders.png" width="340" alt="Delivery List" /> | <img src="docs/screenshots/11_delivery_otp_verification.png" width="340" alt="Delivery OTP" /> |
| *Driver dispatch list with amount due & shop address* | *6-Digit Server OTP verification & store person signature proof* |

| Driver Cash Custody & Owner Settlement |
|:---:|
| <img src="docs/screenshots/12_cash_handover_reconciliation.png" width="340" alt="Cash Handover" /> |
| *Driver physical COD cash custody ledger & Owner settlement to ₹0.00* |

---

## 👥 Role Access & Multi-Platform Matrix

RouteFlow is designed so field workers use the phone, while the owner & admin control everything from web or phone:

| Role | Phone App | Web Dashboard (`/dashboard`) |
|---|---|---|
| **Owner** | View alerts, quick approvals, business status | Full dashboard, reports, employees, stock, payments, settings |
| **Admin / TL** | Monitor team, assign delivery, handle exceptions | Operations dashboard, route/beat monitoring, approvals |
| **Sales Executive** | Add shop, visit, order, collect payment, GPS | Basic web view (My shops & orders) |
| **Warehouse Manager** | Pick, pack, stock entry, return inspection | Godown dashboard, stock reports, GRN/inward |
| **Delivery Executive** | Route navigation, OTP delivery, collect payment, cash handover | Trip & cash history |

---

## 🔄 The Complete Daily 7-Stage Workflow

```
[1. FIELD VISIT] ──> [2. BOOK ORDER] ──> [3. OWNER APPROVAL] ──> [4. WAREHOUSE PICK & PACK]
 Salesperson          Salesperson         Owner Web/App           Warehouse Manager
 Check-in & GPS       Applies Promos      Reserves Stock          Packs Cartons
                                                                          │
                                                                          ▼
[7. CASH HANDOVER] <── [6. PAYMENT] <── [5. OTP DELIVERY] <────── [ASSIGN DRIVER]
 Owner Settles         Driver Collects   Driver Verifies          Admin / Owner
 Driver Balance to ₹0  Cash into Custody 6-Digit Server OTP       Dispatches Order
```

1. **Owner Setup:** Registers company profile, beats, and adds employees.
2. **Sales Visit & GPS Onboarding:** Salesperson visits kirana stores on beat; taps `+ Add Shop` with 1-tap phone GPS coordinate capture.
3. **Order Booking:** Books orders with auto-promotions (*Buy 10 Get 1 Free*).
4. **Owner Approval:** Owner approves order on Web or App; physical stock is atomically reserved.
5. **Godown Fulfillment:** Warehouse manager picks line items and packs into heavy cartons.
6. **Driver Dispatch & OTP Delivery:** Delivery executive delivers order with server-validated 6-digit OTP and store person name.
7. **Cash Reconciliation:** Driver submits collected physical COD cash; Owner verifies and settles driver balance to ₹0.00.

---

## 🛠️ Tech Stack & Architecture

- **Android App:** Kotlin, Jetpack Compose, Material 3, Room Database, Hilt DI, Retrofit/OkHttp, WorkManager.
- **Web Dashboard:** Next.js 16 (App Router), React 19, Tailwind CSS (Deployed on Vercel).
- **Backend API:** Cloudflare Workers running Hono framework.
- **Database:** Cloudflare D1 (Serverless SQLite with atomic ledger constraints).

---

## 🚀 Quick Start Commands

### Backend Tests & Verification
```bash
cd backend
npm test                                                                # 30 unit & integration tests
node --dns-result-order=ipv4first test/test-hardcore-empty-business.mjs # 16-step hardcore test
npx wrangler deploy --config wrangler.staging.toml                      # Deploy API to Cloudflare
```

### Web Dashboard
```bash
cd web
npm install
npm run dev    # Local development at http://localhost:3000
npm run build  # Production build
```

### Android App
```bash
# Run unit tests
.\gradlew.bat testStagingUnitTest --no-daemon

# Build Staging APK
.\gradlew.bat assembleStaging --no-daemon

# Install on physical phone over ADB
adb install -r app\build\outputs\apk\staging\app-staging.apk
```
