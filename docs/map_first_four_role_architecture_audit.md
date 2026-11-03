# RouteFlow — Four-Role Map-First Architecture & Real-Time Logistics Audit

**Document:** `docs/map_first_four_role_architecture_audit.md`  
**Mode:** **STRICT PLANNING & AUDIT ONLY — ZERO IMPLEMENTATION**  
**Author:** Principal Product Architect & Senior FMCG Logistics Systems Engineer  
**Date:** November 2, 2026  
**Status:** Complete Architectural Audit & Specification  
**Execution Boundary:** Zero code edits, zero test changes, zero migrations, zero database modifications, zero Git commits or pushes.  

---

## Executive Summary & Core Product Direction

> **"RouteFlow is not four dashboards with a map added to each. It is one unified distributor network observed through four distinct operational windows."**

An Indian FMCG distributor (e.g. Ramesh Ji in Jodhpur) operates a physical logistics business with strict role specialization:
- **Owner / Admin (Business Control Room):** Observes the entire territory—active field sales reps, live delivery vehicles, retail Kirana accounts, godown inventory levels, and financial risk (credit headroom, cash reconciliation).
- **Sales Representative (Field Sales & Beat Map):** Observes assigned Kirana shops along today's beat route, records GPS store check-ins, checks real-time available stock, and books orders without mutating ledger balances.
- **Warehouse Manager (Godown & Dispatch Map):** Observes warehouse hubs, loading bays, approved orders awaiting picking, FEFO stock batches, carton packing manifests, and vehicle handovers.
- **Delivery Executive (Live Delivery Route Map):** Observes assigned delivery stops in route sequence, executes GPS arrival check-ins, performs 6-digit server OTP deliveries, collects physical cash, and executes depot cash handovers.

This audit evaluates the current state of both repositories:
1. **Reference Kotlin Project (`D:\app\app` & `backend/`):** Houses the backend Cloudflare Workers + D1 database, 23 production migrations, comprehensive RBAC, location ingestion endpoints (`/shifts/locations`, `/visits`, `/team/status`), and Android MapLibre/Google Maps implementations.
2. **Current Published Flutter Project (`flutter_distributor/`):** Houses the multiplatform FMCG client, Drift SQLite v3 offline outbox (`outbox_mutations`), 4-role shell (`role_shell.dart`), and 145/145 passing tests. **Currently, Flutter screens are 100% list/card-based with zero map widgets.**

---

## 1. Existing Architecture Findings

### 1.1 Flutter Distributor Client State (`flutter_distributor/`)
- **Navigation & Routing:** Managed via `RoleShell` ([role_shell.dart](file:///d:/app/flutter_distributor/lib/screens/role_shell.dart)) using `CanonicalRole` (`sales`, `warehouse`, `delivery`, `admin`).
- **Dashboard Views:**
  - `AdminDashboard`: KPI metric cards, Staff list, Products, Retailers, Orders, Inventory, Reports.
  - `SalesDashboard`: Daily target, Beat selector chip, Retailer shop list, Cart bar, Recent orders.
  - `WarehouseDashboard`: Low stock alerts, Inward GRN button, Critical stock table.
  - `DeliveryDashboard`: Driver cash custody card, Stops list, Trip progress bar.
- **Current Map Implementation:** **NON-EXISTENT.** No map package (`google_maps_flutter`, `maplibre_gl`, `flutter_map`) is declared in `pubspec.yaml`. Every screen renders flat column/list layouts.
- **Current GPS Implementation:** `AndroidManifest.xml` declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`, but Dart code contains zero calls to GPS APIs (`geolocator` or `location` are absent).
- **Data Hydration:** Primarily in-memory (`ApiService._initializeData()`) with outbox mutation persistence in local SQLite (`outbox_mutations`). Live cloud synchronization is in development.

### 1.2 Kotlin Native Implementation State (`D:\app\app/`)
- **Map Architecture:** Features a multi-provider engine in `com.routeflow.app.core.design.map`:
  - `MapProviderMode`: Tri-modal failover (`GOOGLE_MAPS` $\to$ `MAPLIBRE_OFFLINE` via regional PMTiles $\to$ `LOGISTICS_CANVAS` algorithmic grid fallback).
  - `RouteFlowMap.kt`: Composable container rendering markers, routes, and layer toggles.
  - `MapContextualSheet.kt`: 25% screen height bottom sheet for marker interactions without covering the map.
  - `MapMarkerModel.kt`: Unified spatial model (`LogisticsMarker`) with type-safe marker types (`RETAILER`, `DELIVERY_STOP`, `VEHICLE`, `WAREHOUSE_HUB`) and statuses (`PENDING`, `IN_PROGRESS`, `COMPLETED`, `ALERT`, `VISITED`, `UNVISITED`).
- **Location Services:** Full Android foreground service with visible notification tracking salesperson shifts and batched GPS uploads.

### 1.3 Cloudflare Backend & D1 State (`backend/`)
- **D1 Database Schemas:** 23 migrations with extensive spatial tables:
  - `retailers`: Contains `latitude REAL`, `longitude REAL`.
  - `shifts`: Contains `start_latitude`, `start_longitude`, `end_latitude`, `end_longitude`.
  - `shift_locations`: Stores high-frequency GPS breadcrumbs (`latitude`, `longitude`, `accuracy`, `timestamp`).
  - `visits`: Stores check-in GPS (`latitude`, `longitude`, `accuracy`, `check_in_time`, `check_out_time`).
  - `planned_routes` & `planned_route_stops`: Stores OSRM route geometries, stop sequence, stop coordinates, and visit statuses.
- **API Endpoints:**
  - `POST /shifts/start`: Shift start with GPS.
  - `POST /shifts/locations`: Batches up to 100 GPS points with monotonic timestamps.
  - `POST /visits`: Geofenced retailer visit check-in.
  - `GET /team/status`: Provides Owner/Admin with real-time staff status and last known GPS coordinates.
- **Real-Time Push:** D1 is a serverless SQLite database; **it does not support native real-time WebSocket subscriptions**. Workers currently handle request-response cycles. Real-time push requires Cloudflare Durable Objects + WebSockets or Server-Sent Events (SSE).

---

## 2. Exact Current Role-to-Screen Mapping

| Canonical Role | Active Navigation Tabs (`role_shell.dart`) | Subviews Rendered (`lib/screens/views/`) | Map State |
| :--- | :--- | :--- | :--- |
| **SALES** | 1. Home<br>2. New Order<br>3. Retailers<br>4. Products<br>5. My Visits | `SalesDashboard`<br>`SalesOrderBookingView`<br>`SalesRetailersView`<br>`SalesProductsView`<br>`SalesVisitsView` | **None** (Static text cards, list views, cart bottom sheet) |
| **WAREHOUSE** | 1. Home<br>2. Godown Stock<br>3. Inward<br>4. Pick & Pack<br>5. Load Van | `WarehouseDashboard`<br>`WarehouseStockView`<br>`WarehouseInwardView`<br>`WarehousePickingView`<br>`WarehouseLoadingView` | **None** (SKU inventory rows, text checklists) |
| **DELIVERY** | 1. Home<br>2. My Trips<br>3. Stops<br>4. Collections<br>5. Handover | `DeliveryDashboard`<br>`DeliveryTripsView`<br>`DeliveryStopsView`<br>`DeliveryCollectionsView`<br>`DeliveryHandoverView` | **None** (Trip overview card, stop list, OTP entry modal) |
| **ADMIN** | 1. Overview<br>2. Orders<br>3. Products<br>4. Retailers<br>5. Staff<br>6. Inventory<br>7. Reports | `AdminDashboard`<br>`AdminOrdersView`<br>`AdminProductsView`<br>`AdminRetailersView`<br>`AdminEmployeesView`<br>`AdminInventoryView`<br>`AdminReportsView` | **None** (Horizontal tab scroll, high-level business cards) |
| **OWNER** | *Fails closed to null* | *Routed to `RoleBlockedView`* | **None** (Missing mapping in `CanonicalRole.fromString`) |

> [!CRITICAL]
> **Governance Finding:** `OWNER` currently returns `null` in `CanonicalRole.fromString` and is blocked. Furthermore, `ADMIN` currently lacks a live territory map. Both roles must be unified under the **Management Control Room** experience with distinct authorization tiers.

---

## 3. Four-Role Map-First Product Specification

```
                               ┌─────────────────────────────────────────┐
                               │           ROUTEFLOW PLATFORM            │
                               └────────────────────┬────────────────────┘
                                                    │
         ┌───────────────────────────┬──────────────┴────────────┬───────────────────────────┐
         ▼                           ▼                           ▼                           ▼
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│  OWNER / ADMIN   │       │   FIELD SALES    │       │    WAREHOUSE     │       │     DELIVERY     │
│  (Control Room)  │       │   (Beat Route)   │       │ (Godown Hub & Van)│       │  (Delivery Trip) │
├──────────────────┤       ├──────────────────┤       ├──────────────────┤       ├──────────────────┤
│ • Full territory │       │ • Today's Beat   │       │ • Godown Hubs    │       │ • Assigned Route │
│ • All vehicles   │       │ • Retailer Shops │       │ • Loading Bays   │       │ • Ordered Stops  │
│ • Active reps    │       │ • Dwell Times    │       │ • Dispatch Vans  │       │ • Real Navigation│
│ • Credit alerts  │       │ • In-Memory Cart │       │ • Inward Batches │       │ • Server OTP POD │
└──────────────────┘       └──────────────────┘       └──────────────────┘       └──────────────────┘
```

---

### Role 01: OWNER / ADMIN — Business Control Room

#### Purpose & Mental Model
Ramesh Ji controls the entire distributor territory from his office or phone. The map is his primary situational awareness dashboard. He sees where his team is, what stock is moving, which shops are ordering, and where business risks (uncollected cash, credit violations) are emerging.

#### Screen Structure & Viewport
- **Default Viewport:** Bounding box containing all distributor warehouses, active field staff, and delivery vehicles (e.g. Jodhpur Metropolitan Area: $26.2389^\circ\text{ N}, 73.0243^\circ\text{ E}$, Zoom level 11–13).
- **Navigation Chrome:**
  - Floating Top Bar: Real-time company KPIs (Today's Turnover `₹54,220`, Live Field Reps `4/5 Active`, Cash-in-Transit `₹18,450`, Pending Approvals `3`).
  - Layer Filter Chips: `[All]`, `[Sales Reps]`, `[Delivery Vans]`, `[Retailers]`, `[Warehouses]`, `[Alerts]`.
  - Bottom Contextual Drawer: Peek height (80dp) showing urgent exception alerts; expands to 25% height when tapping any map marker.

#### Spatial Markers & States
1. **Salesperson Marker (`PERSON` icon):**
   - *Active on Shift (Green):* Rep is currently logged in, within assigned beat, GPS fresh (<5 min).
   - *At Retailer (Blue Pulse):* Rep is currently checked in at a shop (dwelling).
   - *Stale / Offline (Amber):* Last GPS update >15 min old.
   - *Off Shift (Grey):* Duty ended.
2. **Delivery Vehicle Marker (`TRUCK` icon):**
   - *In Transit (Green):* Moving between stops. Heading vector arrow displayed.
   - *At Delivery Stop (Blue):* Stationary at Kirana store for delivery.
   - *Cash Limit Warning (Red):* Driver cash custody exceeds threshold (e.g. >₹50,000).
3. **Retailer Store Marker (`STORE` icon):**
   - *Visited Today (Green Check).*
   - *Pending Visit (Blue).*
   - *Overdue Debt / Credit Block (Red).*
4. **Warehouse Hub Marker (`BUILDING` icon):**
   - Primary depot and branch distribution centres with live carton inventory capacity.

#### Contextual Bottom Sheets & Permitted Actions
- **Tap Sales Rep:** Reveals rep name, phone, assigned beat, current visit, orders booked today (`₹`), shift start time, battery level, and last GPS timestamp.  
  *Actions:* `[Call Rep]`, `[View Beat Route]`, `[View Orders Today]`.
- **Tap Delivery Vehicle:** Reveals vehicle reg (`RJ-19-GB-4021`), driver name, assigned trip (`TRIP-04`), completed stops (`8/14`), cash custody in van (`₹12,400`).  
  *Actions:* `[Call Driver]`, `[View Trip Stops]`, `[Authorize Emergency Return]`.
- **Tap Retailer:** Reveals shop name, owner phone, address, credit limit (`₹50,000`), outstanding balance (`₹18,200`), last payment date, last order.  
  *Actions:* `[Call Owner]`, `[View Ledger]`, `[Adjust Credit Limit (Owner Only)]`.

#### OWNER vs. ADMIN Authorization Matrix
| Capability | OWNER | ADMIN |
|---|:---:|:---:|
| Full Territory & Fleet Map Visibility | YES | YES |
| Staff Management & Role Assignment | YES | YES (Delegated) |
| Order Approval & Stock Reservation | YES | YES |
| Retailer Credit Limit Modifications | **YES** | **NO (Read-Only)** |
| Depot Driver Cash Settlement to ₹0.00 | **YES** | **NO** |
| Profit Margin & Financial Ledger Access | **YES** | **NO** |
| Warehouse Inventory Write-Offs | **YES** | **NO (Requires Owner Approval)** |

---

### Role 02: SALES REPRESENTATIVE — Field Sales & Beat Map

#### Purpose & Mental Model
Rakesh is in the wholesale market visiting 25–30 Kirana shops daily. The map guides his beat navigation, prevents skipping stores, captures genuine store check-in dwell time, and launches order booking.

#### Screen Structure & Viewport
- **Default Viewport:** Centered on salesperson's genuine current GPS position, zoomed to immediate beat cluster (Zoom level 15–16), auto-centering on check-in.
- **Navigation Chrome:**
  - Top Floating Card: Beat progress bar (`7 / 24 Shops Visited • ₹18,400 Booked • Next: Shree Ganesh Kirana (120m)`).
  - Floating Action Buttons: `[My Location]`, `[Beat Sequence Route Polyline]`, `[Offline Cart Indicator]`.
  - Bottom Drag Sheet: Active shop card with immediate 1-tap `[Check In]` or `[Book Order]`.

#### Spatial Markers & States
1. **Current Location:** Blue pulsing circle with dynamic accuracy ring (accuracy in meters).
2. **Retailer Markers (Numbered Sequence):**
   - *Next Target (Gold Star / Pulsing Border):* Recommended sequence stop.
   - *Pending Visit (Neutral Blue):* Unvisited beat store.
   - *Checked-In (Green Animated Beacon):* Store where salesperson is currently dwelling.
   - *Order Booked (Green Check):* Successful booking recorded.
   - *No Order / Skipped (Red / Amber Cross):* Visited with mandatory reason (e.g. *Stock Full*, *Owner Absent*).
   - *Credit Blocked (Grey Padlock):* Retailer exceeds credit limit; cash-only banner shown.

#### Contextual Bottom Sheets & Permitted Actions
- **Tap Retailer Marker:**
  - Card displays: Shop Name, Address, Owner Name, Contact, Distance from Rep (`85m`), Credit Headroom (`₹12,500 available`).
  - *Primary Action 1:* `[GPS Check In]` (Active when within 100m geofence; captures GPS latitude, longitude, accuracy, timestamp).
  - *Primary Action 2 (When Checked In):* `[Book Order]` (Launches in-memory wholesale cart; preserves all Phase O1.1 packaging ratios and outbox persistence).
  - *Secondary Action:* `[Record Collection]` (Log cash/cheque payment with receipt snapshot).
  - *Tertiary Action:* `[Mark Store Closed / Skipped]` (Mandatory dropdown reason).

#### Data Visibility & Boundary Constraints
- Strictly scoped to **assigned beat retailers**. Sales reps cannot view shops on other beats or browse competitor sales performance.
- Physical godown carton deductions remain strictly disabled; booking creates virtual reservations only.

---

### Role 03: WAREHOUSE MANAGER — Godown & Dispatch Map

#### Purpose & Mental Model
Manoj manages physical inventory within the distributor's central godown and loading yard. His map interface visualizes the physical depot layout, loading bays, delivery vehicles staged for departure, and incoming supplier delivery trucks.

#### Screen Structure & Viewport
- **Default Viewport:** Tight spatial framing of the distributor warehouse depot, loading bays, and staging zones (Zoom level 17–18), with branch transfer capability.
- **Navigation Chrome:**
  - Top Bar: Fulfillment Queue (`5 Orders Ready to Pick • 3 Cartons Packing • 2 Vans Loading`).
  - Toggle Tabs: `[Depot Yard Map]` $\longleftrightarrow$ `[SKU Inventory Table]`.
  - Floating Alert: Low Stock Warning Badges (e.g. *Kurkure Masala Munch < 20 boxes*).

#### Spatial Markers & States
1. **Warehouse Hub Marker:** Physical depot pin showing current godown capacity, total SKU cartons on hand, and active shift staff.
2. **Loading Bay / Staging Markers (Bay 1, Bay 2, Bay 3):**
   - *Bay Available (Dashed Green).*
   - *Loading in Progress (Solid Orange).*
   - *Vehicle Loaded & Awaiting Dispatch (Solid Blue).*
3. **Delivery Van Markers (In Yard):**
   - Vehicle reg, assigned route name, loaded carton count vs. capacity, and driver assignment status.

#### Contextual Bottom Sheets & Permitted Actions
- **Tap Staged Vehicle:**
  - Reveals vehicle ID (`RJ-19-GB-4021`), Driver name, Route name, Packing manifest (e.g. `48 Cartons • 12 Strips`).
  - *Primary Action:* `[Start Vehicle Loading]` (Itemized loading checklist).
  - *Secondary Action:* `[Complete Dispatch Handover]` (Confirms physical transfer of cartons from godown to vehicle custody).
- **Tap Warehouse Hub:**
  - *Primary Action:* `[Receive Inward Stock (GRN)]` (Supplier receipt, batch allocation, expiry tracking).
  - *Secondary Action:* `[Stock Adjustment / Audit]` (Damaged goods quarantine, physical carton counts).

---

### Role 04: DELIVERY EXECUTIVE — Live Delivery Route Map

#### Purpose & Mental Model
Suresh drives the delivery vehicle across town. The map is his step-by-step route navigator. He needs to know the exact stop sequence, navigate turn-by-turn, deliver cartons, verify the customer via server OTP, collect COD cash, and return to the depot.

#### Screen Structure & Viewport
- **Default Viewport:** Centered on driver's vehicle location along the active planned route line, showing upcoming 3 stops (Zoom level 15–16).
- **Navigation Chrome:**
  - Top Route Navigation Banner: Turn-by-turn or Next Stop guidance (`Stop #4: Mahaveer Kirana • 450m ahead • 2 Cartons • ₹3,850 COD`).
  - Route Polyline: Road route connecting stops in sequence with green completed segments and blue pending segments.
  - Bottom Delivery Card: Persistent floating card with 1-tap `[Navigate (Google Maps / Intent)]`, `[Arrived at Store]`, and `[Confirm Delivery via OTP]`.

#### Spatial Markers & States
1. **Current Vehicle Position:** Heading-oriented arrow showing live driver movement.
2. **Delivery Stop Pins (Numbered 1 to N):**
   - *Current Stop (Pulsing Gold / Active):* Next destination.
   - *Pending Stops (Blue Circles with Stop Numbers).*
   - *Delivered & Settled (Green Checkmark):* OTP verified, cash recorded.
   - *Delivery Failed (Red Triangle):* Shop closed, payment refused, or damaged goods.

#### Contextual Bottom Sheets & Permitted Actions
- **Tap Next Stop / Arrived:**
  - Card displays: Shop Name, Retailer Contact, Address, Total Cartons to Unload, Payment Mode (`COD` or `Credit/Khata`), Amount Due (`₹3,850.00`).
  - *Action 1:* `[Navigate]` (Dispatches `geo:` intent or external navigation).
  - *Action 2:* `[Arrived at Shop]` (Captures arrival GPS coordinate and timestamp).
  - *Action 3:* `[Enter 6-Digit Server OTP]` (Tamper-proof delivery completion; flips order to `DELIVERED` and increments driver cash custody).
  - *Action 4:* `[Delivery Failed]` (Mandatory photo capture / rejection reason; holds goods in vehicle custody).
- **End of Route (Depot Handover):**
  - Triggers depot return workflow: displays total cash collected (`₹42,800.00`) and undelivered cartons, awaiting Owner cash handover verification.

---

## 4. Real Data and GPS Source-of-Truth Matrix

| Business Data Entity | Current Client State | Authoritative Backend Table / Endpoint | Local Storage Cache | Real-Time Push Channel | Engineering Gap / Missing Work |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Retailer Master & GPS** | In-memory `_retailers` in `ApiService` (No Lat/Lng in Dart model) | `retailers` table (`latitude REAL`, `longitude REAL`) | SQLite `retailers` table (Drift v3) | Pull sync / REST `GET /retailers` | Add `latitude`, `longitude` to Drift schema & Dart `RetailerShop` model. |
| **Warehouse Hubs** | Hardcoded string `'Central Godown (Basni)'` | `warehouses` table / config | Not cached | REST / Static config | Define `WarehouseHub` model, coordinates, and Drift table. |
| **Staff & Assignments** | In-memory `_currentRole` & session | `users`, `employees`, `company_memberships` | Secure storage (`UserSession`) | REST `GET /team/status` | Ingest real employee assignment and role permissions from server. |
| **Field Sales GPS Visits** | In-memory visit timer (No GPS coordinates) | `visits` table (`latitude`, `longitude`, `check_in_time`) | Drift outbox (`RECORD_VISIT` mutation) | REST `POST /visits` | Connect check-in UI to genuine device GPS & outbox insertion. |
| **Vehicle GPS Breadcrumbs** | Non-existent in Flutter | `shift_locations` table (`latitude`, `longitude`, `timestamp`) | Local location buffer table in SQLite | REST `POST /shifts/locations` + Durable Object push | Implement Android foreground location service & batch synchronization. |
| **Delivery Trips & Stops** | In-memory `_deliveryStops` (No coordinates) | `planned_routes`, `planned_route_stops` (Migration 0023) | Drift `delivery_stops` table | REST `GET /trips/active` | Add stop latitude, longitude, and route geometry to Flutter models. |
| **Inventory & Reservations** | In-memory stock + RAM virtual reservation | D1 `inventory_snapshots`, `batches` | Drift `inventory_snapshots` | REST `GET /products` + WebSocket invalidation | Connect outbox booking reservations with server inventory approvals. |
| **Driver Cash Custody** | In-memory accumulator `totalDeliveredRupees` | D1 `driver_cash_ledger`, `trips` | Drift `cash_custody` | REST `POST /orders/:id/deliver` | Implement authoritative driver cash ledger in local Drift SQLite. |

### Real-Time Infrastructure Architecture (Cloudflare Workers + Durable Objects)
Cloudflare D1 cannot deliver push notifications to mobile clients. The production real-time topology must be structured as follows:

```
┌─────────────────────────┐          ┌───────────────────────────┐          ┌─────────────────────────┐
│  Field Mobile Client    │          │  Cloudflare Edge Network  │          │  Distributor Console    │
│  (Sales / Delivery GPS) │          │  (Workers + Durable Obj)  │          │  (Owner Live Map)       │
└───────────┬─────────────┘          └─────────────┬─────────────┘          └───────────┬─────────────┘
            │                                      │                                    │
            │ 1. POST /shifts/locations (Batch GPS)│                                    │
            ├─────────────────────────────────────►│                                    │
            │                                      │ 2. Broadcast via WebSocket / SSE   │
            │                                      │    to Org-Scoped Durable Object    │
            │                                      ├───────────────────────────────────►│
            │                                      │                                    │ (Updates live marker)
            │                                      │ 3. Asynchronous Write              │
            │                                      │    to Cloudflare D1 Storage        │
            │                                      ├──┐                                 │
            │                                      │  │                                 │
            │                                      │◄─┘                                 │
```

1. **Location Ingestion:** Mobile field workers send batched location points via HTTP POST `/shifts/locations` to Cloudflare Workers.
2. **Event Routing:** The Worker writes location points to D1 and forwards the event to a company-scoped **Durable Object** (`DistributorLiveSession`).
3. **Live Map Delivery:** The Owner's mobile/web app connects to the `DistributorLiveSession` via **WebSocket** or **Server-Sent Events (SSE)**, receiving instant coordinate broadcasts with zero polling delay.
4. **Fallback:** If WebSockets disconnect, the client polls `GET /team/status` every 30 seconds.

---

## 5. Security and GPS Architecture

### 5.1 Shift Lifecycle & GPS Tracking Boundaries
- **Explicit Duty Tracking:** GPS location recording occurs **exclusively during an active, authenticated shift**.
- **Lifecycle Triggers:**
  - Shift Start (`POST /shifts/start`): Foreground service starts; permanent status bar notification displayed (`"RouteFlow Field Duty Active • Tracking GPS"`).
  - Shift Pause (`POST /shifts/pause`): Location polling drops to low-power standby or pauses completely.
  - Shift End (`POST /shifts/end`): Foreground service terminates immediately; GPS hardware is released.
- **Privacy & Audit Guarantee:** Zero background tracking when logged out or off-shift. Coordinates are never captured outside authorized operational hours.

### 5.2 Foreground Service & Android Notification Specification
To ensure Android does not kill the location worker in battery optimization mode:
- Service Type: `foregroundServiceType="location"` (Android 14 API 34 compliance).
- Persistent Notification: Shows current beat name, GPS lock status, and last sync timestamp.
- Android Permissions required in `AndroidManifest.xml`:
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_LOCATION`
  - `android.permission.ACCESS_FINE_LOCATION`
  - `android.permission.ACCESS_COARSE_LOCATION`

### 5.3 Stale, Missing, or Denied Location Invariants
- **GPS Denied / Disabled:** Map displays prominent banner: `[GPS Disabled: Enable location to check in at shops]`.
- **Accuracy Filter:** Points with `accuracy > 50m` are flagged as low-accuracy; check-in geofences require `accuracy <= 30m`.
- **Stale Indicator:** Vehicle or salesperson markers older than 15 minutes are rendered with an amber warning badge (`"Last seen 18m ago"`).
- **Strict Anti-Fabrication Rule:** **Never interpolate, simulate, or fabricate moving markers when GPS data is absent.** If no recent coordinates exist, the marker remains stationary at its last known verified position with an explicit staleness timestamp.

---

## 6. Map Provider Recommendation: MapLibre vs. Google Maps

A rigorous comparison based on Indian FMCG distributor operational realities:

| Evaluation Dimension | Google Maps Flutter (`google_maps_flutter`) | MapLibre Flutter (`maplibre_gl` / PMTiles) | Recommendation |
| :--- | :--- | :--- | :--- |
| **Offline Vector Maps** | **Poor.** Requires continuous network connection; offline caching is opaque, limited, and ephemeral. | **Exceptional.** Native support for pre-seeded offline PMTiles vector basemaps (e.g. 50MB regional archive for Rajasthan). | **MapLibre** for field offline operations. |
| **API Costs & Billing** | High risk. Dynamic tile loads scale per map impression ($7.00 per 1,000 loads); requires billing account & credit card. | **Zero tile cost.** Self-hosted OpenStreetMap vector tiles packaged in regional PMTiles archives. | **MapLibre** eliminates recurring API bills. |
| **API Key Management** | Requires `MAPS_API_KEY` injected into `AndroidManifest.xml` and restricted by SHA-1. | Zero API keys required for offline vector basemaps. Optional tile server URL for online mode. | **MapLibre** simplifies distribution. |
| **Turn-by-Turn Navigation** | Native intent launch to external Google Maps navigation app (`geo:0,0?q=lat,lng`). | Launches external Google Maps / Waze intent seamlessly via URL launcher. | **Tie.** Both launch Google Navigation. |
| **Performance & Battery** | Standard Google Play Services overhead; high battery consumption under active rendering. | Native C++ OpenGL/Vulkan vector rendering; lightweight memory and battery footprint. | **MapLibre** superior on low-end hardware. |

### Strategic Recommendation
Adopt the proven **Hybrid Tri-Modal Engine** already verified in the Kotlin app (`RouteFlowMap.kt`):
1. **Primary Mode:** **MapLibre with Offline PMTiles Basemap.** Pre-seed a regional PMTiles archive (`jodhpur_region.pmtiles` ~45MB) inside the app assets or external storage. Provides crisp, vector street maps with street names in English and Hindi even in zero-network bazaar alleys.
2. **Secondary Mode:** **Google Maps (Optional).** Activated only if the distributor configures a Google Maps API Key and has constant high-speed data.
3. **Fallback Mode:** **Logistics Canvas Grid.** If no street tiles exist and Google Maps is unconfigured, renders an algorithmic vector 2D plane showing relative retailer coordinates, bearings, and beat paths, preventing white-screen failure.

---

## 7. Backend & API Gaps Analysis

1. **Missing WebSocket / Push Infrastructure:**
   - *Current State:* `backend/src/index.ts` provides REST endpoints.
   - *Requirement:* Implement a Cloudflare Durable Object (`DistributorLiveSession`) to accept WebSocket connections from connected Owner dashboards and broadcast location events.
2. **Missing Flutter Master Data Coordinate Ingestion:**
   - *Current State:* `GET /retailers` in `backend/src/index.ts` returns `latitude` and `longitude`, but Flutter's `_syncFromDatabase` in `api_service.dart` does not map these into Drift SQLite.
   - *Requirement:* Add `latitude` and `longitude` to Drift `Retailers` table and `RetailerShop` domain model.
3. **Missing Warehouse Master Data Endpoints:**
   - *Current State:* Warehouse locations are hardcoded in strings.
   - *Requirement:* Add `GET /warehouses` endpoint returning physical depots and loading bay coordinates.
4. **Missing Route Stop Polylines in Mobile Client:**
   - *Current State:* Migration `0023_daily_planned_routes.sql` has `route_geometry TEXT` (encoded polyline), but Flutter client does not deserialize or render route paths.
   - *Requirement:* Add polyline decoder and path renderer in Flutter map view.

---

## 8. Tenant Isolation & Security Risks

1. **Cross-Tenant Coordinate Leakage:**
   - *Risk:* A WebSocket broadcast sending location events without company filtering could leak salesperson coordinates to rival distributors.
   - *Mitigation:* The Durable Object must be keyed strictly by `company_id` (e.g. `durableObjectId = env.LIVE_SESSIONS.idFromName(user.company_id)`). Incoming WebSocket connections must validate JWT claims and fail closed if `company_id` does not match.
2. **Stale Outbox Mutation Sequence Collisions:**
   - *Risk:* Location breadcrumbs queued offline could collide with business mutation sequence numbers.
   - *Mitigation:* Store GPS location breadcrumbs in a dedicated SQLite table (`pending_location_events`), completely separated from financial `outbox_mutations`. Location sync must be best-effort and non-blocking.
3. **Role Elevation Vulnerability:**
   - *Risk:* A sales rep spoofing their role claim could attempt to access the Owner Control Room.
   - *Mitigation:* The server enforces RBAC via `authMiddleware` on every endpoint. Client-side navigation fencing in `role_routing.dart` blocks unauthorized screens and renders `RoleBlockedView`.

---

## 9. Proposed File Modification Map (Future Implementation)

When authorized, the implementation will touch these files:

### 1. Client Domain & Database Models
- `flutter_distributor/pubspec.yaml`: Add `maplibre_gl` (or `flutter_map`), `geolocator`, `web_socket_channel`.
- `flutter_distributor/lib/data/local/app_database.dart`: Add `latitude`, `longitude` to `Retailers`, `DeliveryStops`, and create `LocationBreadcrumbs` table.
- `flutter_distributor/lib/models/models.dart`: Add spatial properties to `RetailerShop`, `DeliveryStop`, `WarehouseHub`, `VehicleMarkerModel`.
- `flutter_distributor/lib/domain/auth/role_routing.dart`: Add `CanonicalRole.owner`, update permission matrix to separate OWNER from ADMIN.

### 2. Map Components (Shared Map Engine)
- `flutter_distributor/lib/screens/map/routeflow_map_view.dart`: Shared multi-provider map widget.
- `flutter_distributor/lib/screens/map/map_contextual_sheet.dart`: 25% height interactive bottom sheet.
- `flutter_distributor/lib/screens/map/map_marker_painter.dart`: Custom vector pins (Store, Truck, Person, Hub).

### 3. Role-Specific Screens
- `flutter_distributor/lib/screens/dashboards/owner_dashboard.dart`: Integrated control room with live fleet map.
- `flutter_distributor/lib/screens/views/sales_subviews.dart`: Beat route map with store check-in geofencing.
- `flutter_distributor/lib/screens/views/warehouse_subviews.dart`: Depot yard and loading bay map.
- `flutter_distributor/lib/screens/views/delivery_subviews.dart`: Turn-by-turn stop sequence delivery route map.

### 4. Background GPS & Sync Service
- `flutter_distributor/android/app/src/main/AndroidManifest.xml`: Add location foreground service declarations.
- `flutter_distributor/lib/services/location_service.dart`: Native shift location tracker and batch outbox queue.
- `flutter_distributor/lib/services/realtime_service.dart`: WebSocket / SSE client connecting to Cloudflare Durable Objects.

---

## 10. Ordered Implementation Roadmap & Test Strategy

```
┌────────────────────────────────────────────────────────────────────────┐
│                      IMPLEMENTATION SEQUENCE                           │
├────────────────────────────────────────────────────────────────────────┤
│ Phase M1: Role Governance & Domain Coordinates (Schema & Models)       │
│           • Add OWNER role, separate from ADMIN in role_routing.dart    │
│           • Add Lat/Lng to Drift Retailers, Stops & Hubs               │
├────────────────────────────────────────────────────────────────────────┤
│ Phase M2: Shared Map Engine & Contextual Sheets                        │
│           • Integrate MapLibre / PMTiles offline vector engine         │
│           • Build MapContextualSheet (~25% height) for all markers     │
├────────────────────────────────────────────────────────────────────────┤
│ Phase M3: Role-Specific Spatial Windows                                │
│           • Window 1: Sales Beat Map with GPS Check-In geofence        │
│           • Window 2: Delivery Route Map with Stop Sequencing          │
│           • Window 3: Warehouse Depot Map with Staged Vehicles         │
│           • Window 4: Owner Control Room with Live Multi-Entity Map    │
├────────────────────────────────────────────────────────────────────────┤
│ Phase M4: Live GPS Ingestion & Durable Object Push                     │
│           • Background foreground location service during shifts       │
│           • Cloudflare Durable Object WebSocket broadcaster            │
├────────────────────────────────────────────────────────────────────────┤
│ Phase M5: Hardware Dual-Device Verification                            │
│           • Device A (Sales/Driver): Moves and sends genuine GPS       │
│           • Device B (Owner): Renders live marker movement on map      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Explicit Boundary & Non-Implementation Confirmation

> [!IMPORTANT]
> **Strict Confirmation:**
> - Zero application source files have been modified.
> - Zero test files or database migrations have been executed.
> - No map packages or dependencies have been added to `pubspec.yaml`.
> - Remote Cloudflare Workers and D1 databases remain completely untouched.
> - The Git working tree remains identical to the pre-audit baseline.
> - This report represents the complete, verified architectural blueprint awaiting user review.
