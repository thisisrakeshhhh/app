# RouteFlow — Final Client Demonstration Script

> **The Definitive End-to-End Walkthrough for Indian FMCG & Kirana Wholesale Distributors**  
> *Target Duration: 5 to 7 Minutes | Cross-Platform: Android Mobile App + Web Management Console*

---

## 1. Demo Narrative & Positioning

> *"Traditional distributor software like Bizom or FieldAssist is complex and built for large corporate headquarters, while billing apps like Vyapar or Khatabook only manage single retail counters. RouteFlow is built specifically for Indian wholesale distributors (लालाजी डिस्ट्रीब्यूटर) connecting the complete daily operational cycle in real time: from morning sales booking, owner credit approval, godown batch fulfillment, and driver OTP delivery, to evening cash handover reconciliation."*

---

## 2. Persona Quick Reference (Credentials)

| Role | Username | Password | Operational Responsibility |
|---|---|---|---|
| **Owner / Admin** | `owner` | `password123` | Credit controls, order approval, staff security, cash reconciliation |
| **Salesperson** | `sales` | `password123` | Beat route, retailer visits, order booking, collection |
| **Warehouse Manager** | `warehouse` | `password123` | Barcode scan, inward stock, FEFO picking, packing, dispatch |
| **Delivery Executive** | `delivery` | `password123` | Delivery stops, navigation, OTP verification, cash custody |

---

## 3. Step-by-Step 7-Minute Demonstration Flow

### Scene 1: The Control Room (Owner Perspective)
*Distributor owner opens the app at 8:00 AM before field staff start their day.*

1. **Login as Owner:**
   - Tap **Owner** quick-fill (or enter `owner` / `password123`).
   - Land directly on the **Control Room** dashboard.
2. **Showcase Executive Metrics:**
   - Highlight the **8 Real-Time KPI Cards**: Today Sales (`₹200`), Pending Udhaar (`₹50,862`), Pending Approvals (`7`), Low Stock Items (`2`), Failed Deliveries (`1`), and Staff On Duty.
   - Point out **Zero Demo Artifacts** — professional, high-density layout.
3. **Inspect Team Live Monitor:**
   - Tap **Staff** quick action (or bottom **Team** tab).
   - Point out salesperson and driver shift progress (`5 / 7 completed`), GPS tracking coordinates, and stale location warnings.

---

### Scene 2: Morning Beat & Order Booking (Salesperson Perspective)
*Sales executive Rakesh Kumar heads out onto Beat Route 4.*

1. **Switch to Sales Account:**
   - Tap **Logout** &rarr; select **Sales** (`sales` / `password123`).
2. **Shift Start & Beat Route:**
   - Tap **Start Shift** — foreground location tracking starts with notifications.
   - View **Beat 04 (Malviya Nagar & Raja Park)** with 14 mapped retail kirana shops.
3. **Retailer Check-In:**
   - Select **Mega Mart** &rarr; tap **Check-In**.
   - Review retailer credit limit (`₹10,000`) and outstanding Udhaar.
4. **Order Booking & Promotions:**
   - Tap **Book Order** &rarr; add 10 packs of *Organic Tea*.
   - System automatically applies active trade scheme: **BUY 10 GET 1 FREE**.
   - Tap **Submit Order** &rarr; order shifts from `Saved Offline` to `Synced` with atomic Cloudflare D1 persistence.
5. **Collection Entry:**
   - Tap **Collect Payment** &rarr; enter `₹500` cash &rarr; ledger balance updates immediately.

---

### Scene 3: Order Approvals & Credit Risk Control (Owner Perspective)
*Owner approves the booked order before the warehouse packs it.*

1. **Switch to Owner Account:**
   - Login as `owner`.
2. **Open Order Approvals:**
   - Tap **Approve Orders** badge (`7 Pending`).
3. **Showcase Financial & Stock Intelligence:**
   - View order `ORD-DEL-862879` for *Mega Mart* (`₹100`).
   - Highlight dynamic validation badges:
     - **Credit OK (Limit: ₹10,000)**: Proves customer has not breached credit headroom.
     - **Stock Ready**: Confirms godown has adequate physical unreserved inventory.
4. **Demonstrate Strict Fraud Prevention:**
   - Tap **Reject** to showcase structured rejection reasons (*Credit Limit Exceeded*, *Stock Shortage*, *Route Closed*).
   - Cancel dialog and tap **Approve** &rarr; order transitions atomically to `APPROVED` and physically reserves godown inventory.

---

### Scene 4: Godown Fulfillment & Dispatch (Warehouse Perspective)
*Warehouse manager Manoj Kumar prepares cartons for vehicle loading.*

1. **Switch to Warehouse Account:**
   - Login as `warehouse` (`warehouse` / `password123`).
2. **Godown Desk Overview:**
   - Single clean depot header (*Jaipur Godown Depot*), 6 operational counters.
3. **Scan & Batch Inward (Optical Barcode):**
   - Tap **Scan Product** &rarr; CameraX opens with laser targeting.
   - Lookup item `8901030000001` (*Tata Tea Gold*) &rarr; show available vs reserved stock.
   - Tap **Inward Stock** &rarr; add +25 units with batch `OCT-2026` &rarr; physical inventory updates.
4. **FEFO Picking Queue:**
   - Tap **Pick/Pack** tab &rarr; select approved order &rarr; tap **Start Picking**.
   - Point out **FEFO (First-Expiry-First-Out)** badge: algorithm directs worker to oldest batch first, preventing expiry wastage.
5. **Carton Packing:**
   - Tap **Mark Packed** &rarr; enter `2 Cartons` &rarr; status updates to `PACKED`.
6. **Dispatch Handover:**
   - Tap **Dispatch** tab &rarr; select batch `DSP-JPR-001` assigned to driver *Suresh Yadav*.
   - Tap **Handover to Driver** &rarr; inventory custody transfers to driver vehicle.

---

### Scene 5: Last-Mile Delivery & Cash Custody (Delivery Driver Perspective)
*Driver Suresh Yadav arrives at the retailer shop.*

1. **Switch to Delivery Account:**
   - Login as `delivery` (`delivery` / `password123`).
2. **Route Stops & Navigation:**
   - View assigned trip stops sorted in optimized sequence.
   - Tap **Mega Mart** stop &rarr; inspect shop address, phone, amount due (`₹100`), and carton count (`2 Cartons`).
   - Tap **Navigate** &rarr; opens Google Maps directly.
3. **Server-Validated Delivery OTP (Anti-Fraud):**
   - Tap **Request OTP** &rarr; 6-digit cryptographic OTP is dispatched via SMS to shop owner's registered mobile.
   - Enter verified OTP &rarr; select payment collected: `CASH ₹100`.
   - Tap **Confirm Delivery** &rarr; order flips to `DELIVERED` and `₹100` transfers to driver's personal cash custody.
4. **Driver Profile & Security:**
   - Open driver profile &rarr; show cash custody balance, shift status, and **zero password change access** (governed strictly by owner).

---

### Scene 6: Evening Cash Handover & Closing (Owner Perspective)
*Driver returns to the depot in the evening to deposit physical cash.*

1. **Switch to Owner Account:**
   - Login as `owner`.
2. **Cash Handover Reconciliation:**
   - Tap **View Cash** &rarr; view pending driver deposit.
   - Enter physical notes counted; system flags any discrepancy between physical notes and recorded collections.
   - Tap **Accept Handover** &rarr; driver custody is discharged and money moves to owner treasury.
3. **4-Tab Operations Report:**
   - Tap **Reports** (Activity tab):
     - **Field Visits:** Review time-on-site and GPS audit trail.
     - **Sales:** Live list of today's booked, dispatched, and delivered orders.
     - **Collections:** Summary breakdown across Cash, UPI, and Cheque.
     - **Godown Stock:** Live end-of-day warehouse inventory.
4. **Share Daily Summary:**
   - Tap **Share** icon &rarr; triggers native WhatsApp share intent with daily closing figures formatted for business partners.

---

## 4. Key Talking Points for Enterprise Clients

1. **Total Cash Leak Prevention:** Cash cannot disappear between driver, salesperson, and owner. Every rupee is tied to an atomic ledger entry and verified OTP.
2. **Offline-First Resilience:** In rural or basement markets with zero 4G network, sales reps can continue booking orders and collecting payments. The Room database safely queues sync operations with clear status badges.
3. **Multi-Tenant Security:** Competing distributors cannot see each other's data; tenants are isolated at the database schema and JWT claims level.
4. **Strict Role Governance:** Field staff have zero ability to alter passwords or manipulate credit lines; Owner/Admin retains 100% control with instant remote session revocation.
