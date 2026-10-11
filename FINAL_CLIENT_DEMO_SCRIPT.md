# RouteFlow — Final Client Demonstration Script

> **The Definitive End-to-End Walkthrough for Indian Wholesale & Kirana Distributors**  
> *Target Duration: 5 to 7 Minutes | Architecture: Android Mobile App + Next.js Web Console + Cloudflare D1 Backend*

---

## 1. Demo Narrative & Positioning

> *"Traditional distributor software like Bizom or FieldAssist is complex and built for large corporate headquarters, while billing apps like Vyapar or Khatabook only manage single retail counters. RouteFlow is built specifically for Indian wholesale distributors (लालाजी डिस्ट्रीब्यूटर) connecting the complete daily operational cycle in real time: from morning sales booking, owner credit approval, godown batch fulfillment, and driver OTP delivery, to evening cash handover reconciliation."*

---

## 2. Persona Quick Reference (Credentials)

| Role | Person | Username | Password | Operational Responsibility |
|---|---|---|---|---|
| **Owner** | Ramesh Ji | `owner` | `password123` | Master control, order approval, credit limits, cash reconciliation, P&L |
| **Admin / TL** | Amit | `admin` | `password123` | Staff duty tracking, beat assignments, operational monitoring |
| **Salesperson** | Rakesh Kumar | `sales` | `password123` | Beat route, shop check-in, GPS visit proof, order booking |
| **Warehouse Manager** | Manoj Kumar | `warehouse` | `password123` | Barcode scan, stock inward, FEFO picking, carton packing |
| **Delivery Executive** | Suresh Yadav | `delivery` | `password123` | Route stops, navigation, OTP delivery proof, cash custody |

---

## 3. Canonical Demo Scenario: Jaipur Kirana Distribution

- **Distributor:** Jaipur Wholesale Distributors
- **Beat:** Mansarovar West (BEAT-04)
- **Retailer:** Sharma General Store, Mansarovar
- **Order Details:**
  - 10 Premium Tea @ ₹145 = ₹1,450
  - 5 Biscuit Carton @ ₹200 = ₹1,000
  - 2 Oil Tin @ ₹500 = ₹1,000
  - **Total Order Value:** **₹3,450.00**
- **Delivery Payment:** Cash ₹3,450 collected at shop
- **Evening Cash Handover:** ₹3,450 submitted & settled
- **Unit Economics / Profit Estimate:**
  - Gross Sale: **₹3,450**
  - Product Cost: **₹2,850**
  - Gross Margin: **₹600**
  - Sales Commission / Incentive: **₹35**
  - **Net Margin Estimate:** **₹565**

---

## 4. Step-by-Step 7-Minute Demonstration Flow

### Scene 1: The Control Room (Owner Perspective - Ramesh Ji)
*Ramesh Ji opens the app at 8:00 AM before field staff start their day.*

1. **Login as Owner:**
   - Tap **Owner** quick-fill (or enter `owner` / `password123`).
   - Land directly on the **Control Room** dashboard.
2. **Showcase Executive Metrics:**
   - Review live KPIs: Today Sales, Pending Udhaar, Pending Approvals, Low Stock Items, Staff On Duty.
   - Point out clean B2B layout: Zero emojis, clear single-language toggle, instant responsiveness.
3. **Inspect Team Live Monitor:**
   - View staff duty roster (Amit, Rakesh, Manoj, Suresh) and assigned daily beats.

---

### Scene 2: Morning Beat & Order Booking (Salesperson Perspective - Rakesh)
*Sales executive Rakesh Kumar heads out onto the Mansarovar West beat.*

1. **Switch to Sales Account:**
   - Tap **Logout** &rarr; select **Sales** (`sales` / `password123`).
2. **Shift Start & Beat Route:**
   - Tap **Start Duty** — captures GPS coordinates and start timestamp.
   - View assigned beat: **Mansarovar West (BEAT-04)** with mapped kirana stores.
3. **Retailer Check-In:**
   - Select **Sharma General Store** &rarr; tap **Check-In**.
   - GPS coordinates and check-in dwell time are recorded automatically.
   - Review store credit limit (₹50,000) and current outstanding.
4. **Order Booking:**
   - Shopkeeper orders: *"10 packet chai, 5 biscuit carton, 2 oil tin bhej do."*
   - Add items from catalog:
     - 10x Premium Tea @ ₹145 = ₹1,450 *(Trade Scheme: Buy 10 Get 1 Free)*
     - 5x Biscuit Carton @ ₹200 = ₹1,000
     - 2x Oil Tin @ ₹500 = ₹1,000
   - **Order Total:** **₹3,450.00**
5. **Submit Order:**
   - Tap **Submit Order** &rarr; Order created with status **Approval Pending**.
   - Notice Rakesh's sales target updates immediately with the ₹3,450 order.

---

### Scene 3: Order Approvals & Credit Risk Control (Owner Perspective - Ramesh Ji)
*Ramesh Ji reviews and approves the booked order.*

1. **Switch to Owner Account:**
   - Login as `owner`.
2. **Open Order Approvals:**
   - Open pending approvals queue &rarr; find order for **Sharma General Store** (`₹3,450`).
3. **Credit & Stock Intelligence:**
   - Verify retailer credit headroom: Outstanding + ₹3,450 is within ₹50,000 limit.
   - Verify warehouse stock: Tea (120 avail), Biscuit (80 avail), Oil (20 avail).
4. **Approve Order:**
   - Tap **Approve** &rarr; order atomically flips to `APPROVED`.
   - Inventory is reserved immediately, preventing double-allocation.

---

### Scene 4: Godown Fulfillment & Dispatch (Warehouse Perspective - Manoj)
*Warehouse manager Manoj Kumar picks and packs the goods.*

1. **Switch to Warehouse Account:**
   - Login as `warehouse` (`warehouse` / `password123`).
2. **Godown Desk Overview:**
   - Jaipur Godown Depot desk displays picking queue with newly approved order.
3. **FEFO Picking Queue:**
   - Tap **Pick/Pack** &rarr; select order for Sharma General Store &rarr; tap **Start Picking**.
   - Scan/confirm items:
     - [✓] 10x Premium Tea (FEFO batch suggested)
     - [✓] 5x Biscuit Carton
     - [✓] 2x Oil Tin
4. **Carton Packing:**
   - Tap **Mark Packed** &rarr; assign **2 Cartons** (Carton 1: Tea + Biscuits, Carton 2: Oil).
   - Status updates to `PACKED` (Ready for Dispatch).
5. **Dispatch Handover:**
   - Assign to delivery driver **Suresh Yadav** &rarr; tap **Dispatch**.
   - Order flips to `OUT_FOR_DELIVERY`; physical custody moves to vehicle.

---

### Scene 5: Last-Mile Delivery & Cash Custody (Delivery Driver Perspective - Suresh)
*Driver Suresh Yadav arrives at Sharma General Store.*

1. **Switch to Delivery Account:**
   - Login as `delivery` (`delivery` / `password123`).
2. **Route Stops & Navigation:**
   - View assigned route stops in Mansarovar West.
   - Stop #1: **Sharma General Store** (2 Cartons | Amount Due: `₹3,450.00`).
   - Tap **Deliver**.
3. **Server-Validated Delivery OTP (Anti-Fraud):**
   - Tap **Request OTP** &rarr; 6-digit OTP sent to registered shopkeeper mobile.
   - Shopkeeper shares OTP &rarr; Suresh enters OTP.
   - Enter recipient name: **Sharma Ji**.
   - Select payment: **CASH ₹3,450.00**.
4. **Confirm Delivery:**
   - Tap **Confirm Delivery** &rarr; status updates to `DELIVERED`.
   - **₹3,450.00** is added to Suresh's live cash-in-hand custody.

---

### Scene 6: Evening Cash Handover & Closing (Owner Perspective - Ramesh Ji)
*Driver Suresh deposits collected physical cash at distributor office.*

1. **Cash Handover Submission (Suresh):**
   - Suresh taps **Submit Handover** &rarr; enters collected amount: **₹3,450.00**.
2. **Reconciliation & Acceptance (Ramesh Ji):**
   - Ramesh Ji opens **Cash Handover** in Owner Control Room.
   - Matches physical notes: ₹3,450 counted vs ₹3,450 system expectation (Discrepancy: ₹0).
   - Tap **Accept Handover** &rarr; status flips to **Accepted / Settled**.
3. **Final Business & Margin Overview:**
   - Today's Delivered Sales: **₹3,450.00**
   - Cash Collected & Settled: **₹3,450.00**
   - Gross Margin: **₹600.00** (₹3,450 sale - ₹2,850 cost)
   - Sales Incentive: **₹35.00**
   - Net Profit Estimate: **₹565.00**
   - Retailer ledger & godown stock updated automatically.

---

## 5. Client Pitch Script (Hindi / Local Distributor Pitch)

> **"सर, RouteFlow सिर्फ आर्डर लेने का ऐप नहीं है—ये आपके पूरे डिस्ट्रीब्यूशन बिज़नेस का रिमोट कंट्रोल है।**
>
> 1. **सेल्समैन (Rakesh)**: मानसरोवर वेस्ट बीट पे शर्मा जनरल स्टोर पहुंचेगा, GPS चेक-इन होगा। 10 पैकेट चाय, 5 बिस्कुट कार्टन, 2 तेल टिन का ₹3,450 का आर्डर बुक करेगा।
> 2. **मालिक (Ramesh Ji)**: गद्दी पर बैठे पार्टी की ₹50,000 की उधारी लिमिट देखकर आर्डर अप्रूव करेंगे।
> 3. **गोदाम (Manoj)**: माल निकाल कर 2 कार्टन पैक करेगा और गाड़ी में लोड कराएगा।
> 4. **डिलीवरी (Suresh)**: दुकान पर पहुंचेगा, OTP डालकर ₹3,450 कैश कलेक्ट करेगा।
> 5. **शाम का कैश हिसाब**: ड्राइवर ₹3,450 जमा कराएगा, मालिक बटन दबाकर 'Settled' करेगा—एक रुपये का भी लीकेज नहीं होगा।
>
> **मालिक को लाइव सेल (₹3,450), उधारी, स्टॉक, स्टाफ लोकेशन और ₹565 का नेट मार्जिन एक स्क्रीन पर साफ दिखेगा।"**

---

## 6. Key Enterprise Value Pillars

1. **Total Cash Leak Prevention:** Driver cash custody is tracked down to the exact rupee. Discrepancies cannot be hidden.
2. **Zero Unauthorized Stock Loss:** Stock cannot be dispatched without owner approval and carton packing verification.
3. **Offline-First Resilience:** In basement or weak 4G markets, field reps book orders offline; Room database syncs seamlessly when back online.
4. **Instant Security Revocation:** If any staff member leaves, owner deactivates their account in 1 tap, killing active sessions instantly across all devices.
