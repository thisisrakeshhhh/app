# RouteFlow — Complete Project Architecture & Visual Guide

> **Warehouse-to-Retailer Logistics & Field Distribution System for Indian FMCG / Kirana Distributors**

---

## 1. Executive Summary & Core Value

**RouteFlow** connects the entire daily distribution lifecycle into one real-time system:
$$\text{Owner Setup} \longrightarrow \text{Sales Beat \& GPS Visit} \longrightarrow \text{Order Booking} \longrightarrow \text{Owner Approval} \longrightarrow \text{Godown Picking} \longrightarrow \text{Driver OTP Delivery} \longrightarrow \text{Cash Handover Settlement}$$

Unlike heavy corporate enterprise software (Bizom, FieldAssist) or single-shop billing apps (Vyapar, Khatabook), RouteFlow gives the distributor complete visibility across **Web Dashboard** and **Android Mobile App**, synced to a unified **Cloudflare Workers + D1 database backend**.

---

## 2. Technology Stack

- **Android App:** Kotlin, Jetpack Compose, Material 3, Room Database (Offline-first cache), Hilt DI, Retrofit/OkHttp, WorkManager.
- **Web Dashboard:** Next.js 16 (App Router), React 19, TypeScript, Tailwind CSS, deployed on Vercel (`https://appdashboardadmin.vercel.app`).
- **Backend API:** Cloudflare Workers running Hono framework (`https://routeflow-api-staging.thisisrakesh21.workers.dev`).
- **Database:** Cloudflare D1 (Serverless SQLite with atomic ledger constraints).
- **Localization:** Real-time 1-tap English and Hindi (`हिन्दी`) language engine.

---

## 3. UI Design System & Brand Palette

| Token Name | Hex Code | Purpose / Where It Appears |
|---|---|---|
| **Primary Brand Blue** | `#2563EB` | Primary buttons (`Sign In`, `Submit Order`, `Proceed to Deliver`), active navigation icons, headers |
| **Accent / Selected Tint** | `#EFF6FF` | Navigation pill highlight, active chip background |
| **Success / Approved Green** | `#10B981` / `#059669` | `Synced` badges, `DELIVERED` status, `ACCEPTED` cash handover |
| **Warning / Pending Amber** | `#F59E0B` / `#D97706` | `Pending Approvals`, `OUT_FOR_DELIVERY` status, low stock alerts |
| **Error / Exception Red** | `#EF4444` / `#DC2626` | Logout action, delivery failed alerts, negative stock guards |
| **Background Neutral** | `#F8FAFC` | App screen background |
| **Card Surface** | `#FFFFFF` | Elevated cards, input fields, modals |
| **Text Primary** | `#0F172A` / `#1E293B` | Titles, store names, currency amounts |
| **Text Secondary / Muted** | `#64748B` / `#94A3B8` | SKUs, addresses, timestamps, secondary labels |

---

## 4. Visual Workflow & Screenshots (Captured from Physical Device)

### Phase 1: Authentication & Localization
The app features instant 1-tap demo credential selectors and dynamic English/Hindi localization.

| 01. Login Screen (English) | 02. Login Screen (Hindi - हिन्दी) |
|:---:|:---:|
| ![Login Screen](docs/screenshots/01_login_screen.png) | ![Login Screen Hindi](docs/screenshots/02_login_hindi_screen.png) |
| *Role selectors: Owner, Admin, Sales, Warehouse, Delivery* | *Complete localized interface without text clipping* |

---

### Phase 2: Owner & Business Overview
The distributor owner monitors operations, approvals, outstanding credit, and exceptions.

| 03. Owner Dashboard (English) | 04. Owner Dashboard (Hindi - हिन्दी) |
|:---:|:---:|
| ![Owner Dashboard](docs/screenshots/03_owner_dashboard.png) | ![Owner Dashboard Hindi](docs/screenshots/04_owner_dashboard_hindi.png) |
| *Business KPIs: Approvals, Stock, Delivered Sales, Outstanding* | *Local language interface for Indian business owners* |

---

### Phase 3: Field Sales Operations (Beat, Shops & GPS)
Sales executives visit shops on their beat, onboard new retailers with phone GPS, and book orders.

| 05. Sales Today Beat | 06. Beat Shops List |
|:---:|:---:|
| ![Sales Beat](docs/screenshots/05_sales_today_beat.png) | ![Shops List](docs/screenshots/06_sales_shops_list.png) |
| *Assigned Beat, visit progress, order totals, target tracker* | *Active shops on route with outstanding balances and Check-In* |

| 07. Add Shop with Phone GPS | 08. Product Catalog & Order Booking |
|:---:|:---:|
| ![Add Shop GPS](docs/screenshots/07_sales_add_shop_gps.png) | ![Order Booking](docs/screenshots/08_sales_order_booking.png) |
| *1-Tap GPS coordinate capture for new Kirana onboarding* | *Warehouse stock badges, schemes (Buy 10 Get 1 Free), instant cart* |

---

### Phase 4: Warehouse Picking, Delivery & Cash Handover
Godown picking desk, driver OTP delivery verification, and physical cash handover reconciliation.

| 09. Warehouse Picking Queue | 10. Delivery Route & Assigned Orders |
|:---:|:---:|
| ![Warehouse Picking](docs/screenshots/09_warehouse_picking_queue.png) | ![Delivery List](docs/screenshots/10_delivery_assigned_orders.png) |
| *Godown desk: Approved orders, item checklists, carton packing* | *Driver dispatch list with amount due and shop location* |

| 11. Server OTP Delivery Verification | 12. Cash Custody & Owner Reconciliation |
|:---:|:---:|
| ![Delivery OTP](docs/screenshots/11_delivery_otp_verification.png) | ![Cash Handover](docs/screenshots/12_cash_handover_reconciliation.png) |
| *6-Digit Server OTP verification and store person name proof* | *Driver cash custody ledger and 1-tap owner settlement* |

---

## 5. Role & Permission Matrix

| Role | Primary Device | Navigation Tabs | Permissions & Purpose |
|---|---|---|---|
| **Owner** | Web + Phone | Home, Orders, Business, Team, Activity | Master control, order approvals, cash settlement, employee management |
| **Admin / TL** | Web + Phone | Home, Orders, Team, Activity | Operations manager, delivery assignment, route exceptions |
| **Sales Executive** | Phone (Field) | Today, Shops, Booking, Collections, Profile | Store onboarding with GPS, shop visits, order booking, payment receipts |
| **Warehouse Manager** | Phone (Godown) | Queue, Stock, Picking, Returns | Inventory audits, item picking, carton packing, return inspections |
| **Delivery Executive** | Phone (Van/Bike)| Trips, Deliveries, Handover, Profile | Route navigation, OTP delivery proof, cash custody, owner handover |

---

## 6. How to Run & Deploy

```bash
# Backend (Cloudflare Workers)
cd backend
npm test                                                                # Run 30 integration tests
node --dns-result-order=ipv4first test/test-hardcore-empty-business.mjs # 16-step hardcore test
npx wrangler deploy --config wrangler.staging.toml                      # Deploy API

# Web Dashboard (Next.js)
cd web
npm run build                                                           # Verify build
# Deployed to Vercel: https://appdashboardadmin.vercel.app

# Android App (Gradle)
.\gradlew.bat testStagingUnitTest --no-daemon                           # Run unit tests
.\gradlew.bat assembleStaging --no-daemon                               # Build Staging APK
adb install -r app\build\outputs\apk\staging\app-staging.apk             # Install on device
```
