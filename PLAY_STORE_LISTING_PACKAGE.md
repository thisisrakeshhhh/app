# RouteFlow — Google Play Store Listing & Data Safety Package

> **Release Track:** Google Play Console &rarr; Internal Testing Track  
> **Package Name (`applicationId`):** `com.routeflow.app`  
> **Target Version:** Version Code `2`, Version Name `1.0.0`  
> **Target Android Version:** Android 15 (API 35/36), Minimum Android 8.0 (API 26)  
> **Privacy Policy URL:** `https://appdashboardadmin.vercel.app/privacy`  
> **Support Email:** `support@routeflow.in` / `privacy@routeflow.in`

---

## 1. Google Play Store Listing Assets

### 1.1 App Title (Max 30 characters)
```text
RouteFlow: Kirana Distribution
```

### 1.2 Short Description (Max 80 characters)
```text
FMCG & Kirana distributor app: Sales beat, godown picking, OTP delivery & cash.
```

### 1.3 Full Description (Max 4000 characters)
```text
RouteFlow is the purpose-built field distribution and warehouse management system designed specifically for Indian FMCG and Kirana wholesale distributors (लालाजी डिस्ट्रीब्यूटर). 

Connecting your field salesmen, godown staff, delivery drivers, and owner office in one real-time operational loop, RouteFlow eliminates paper leakage, unaccounted cash, stock mismatches, and delayed market collections.

Whether you run an agency for staples, packaged foods, beverages, personal care, or confectionery, RouteFlow gives you full control from morning order booking to evening cash reconciliation.

============================================================
KEY OPERATIONAL MODULES & ROLES:
============================================================

1. OWNER CONTROL ROOM (लालाजी / डिस्ट्रीब्यूटर डैशबोर्ड)
• Real-time financial cockpit: Today Sales, Cash Collected, Pending Udhaar, and Godown Stock value.
• 1-Click Order Approvals: Inspect retailer outstanding balance, credit limit, and stock availability before approving orders.
• Employee Security & Governance: Add staff, assign beats, reset passwords, deactivate users, and revoke active sessions.
• Cash Reconciliation & Khata: Audit field cash collected by drivers and salesmen with instant settlement confirmation.
• Business Reports: Daily sales summary, collection ledger, stock movement, and staff beat completion reports.

2. FIELD SALES EXECUTIVE (सेल्समैन बीट और ऑर्डर बुकिंग)
• Beat Route Planner: View daily assigned Kirana shops in sequence with turn-by-turn map guidance.
• GPS Geofenced Check-In: Verify salesman presence at the store location before taking orders.
• Fast Order Booking: Digital catalog with real-time stock availability, wholesale rates, and automated trade promotions (Buy X Get Y).
• Instant Payment Collection: Log Cash, UPI, or Cheque payments on the spot with printable ledger balance receipts.
• Offline-First Engine: Continue booking orders in basements and low-network lanes; syncs automatically when online.

3. GODOWN & WAREHOUSE DISPATCH (गोदाम और इनवर्ड / पिकिंग)
• Barcode Scanner: Optical camera scanning for fast inward stock intake, batch registration, and expiry tracking.
• FEFO Batch Picking: Automated First-Expiry-First-Out picking lists prevent warehouse stock spoilage and dead inventory.
• Packing & Carton Generation: Aggregate retail orders into numbered dispatch cartons with printable shipping slips.
• Dispatch Handover: Hand over packed cartons directly to assigned delivery executives.
• Damaged Returns Inspection: Inspect returned items, log damage reasons, and return restockable items to inventory.

4. DELIVERY EXECUTIVE (डिलीवरी और सुरक्षित कैश कलेक्शन)
• Optimized Delivery Run: View trip stops, shop address, contact number, carton count, and cash amount due.
• Secure OTP Delivery: Customer delivers a secure one-time passcode to confirm order receipt and prevent fake drop-offs.
• Cash Custody Ledger: Live digital wallet showing exact cash held on duty.
• Failed Delivery Tracking: Record genuine non-delivery reasons (Shop Closed, Rescheduled, Owner Unavailable).
• Evening Cash Handover: Transfer collected currency to the owner with digital handover receipts.

============================================================
DESIGNED FOR BHARAT:
============================================================
• Bilingual Experience: 1-tap instant switch between English and Hindi (हिन्दी).
• Clean Rupee Formatting: Clear Indian currency grouping (₹ Lakh / ₹ Crore).
• Low-Bandwidth Optimized: Ultra-lightweight payload running smoothly on entry-level Android devices.
• Strict Data Privacy: Multi-tenant isolated databases with enterprise-grade encryption.

Streamline your wholesale agency, eliminate bad debts, and take complete control of your distribution pipeline with RouteFlow today!
```

---

## 2. Google Play Data Safety Answers (Console Questionnaire)

Google Play requires developers to complete the Data Safety questionnaire. Below are the exact answers to input:

### Overview Questions:
- **Does your app collect or share any of the required user data types?**  
  👉 **Yes**
- **Is all of the user data collected by your app encrypted in transit?**  
  👉 **Yes** (All API communication is strictly encrypted over TLS 1.3 / HTTPS via Cloudflare).
- **Do you provide a way for users to request that their data be deleted?**  
  👉 **Yes** (Distributor admins can deactivate employees and wipe credentials directly; accounts can also request data deletion at `privacy@routeflow.in`).

### Specific Data Type Declarations:

| Category | Data Field | Collected? | Shared? | Purpose | Ephemeral? | Required / Optional? |
|---|---|:---:|:---:|---|:---:|:---:|
| **Location** | Approximate Location | Yes | No | **App functionality:** Retailer store vicinity, beat route navigation | No | Required |
| **Location** | Precise Location | Yes | No | **App functionality & Fraud prevention:** Field salesman shop check-in audit and shift travel tracking | No (Tied to active duty shift) | Required |
| **Personal Info** | Name | Yes | No | **Account management & App functionality:** Staff name, Kirana shop owner name | No | Required |
| **Personal Info** | Phone Number | Yes | No | **Account management & Communication:** Login authentication, Kirana contact dialer | No | Required |
| **Personal Info** | User IDs | Yes | No | **Account management:** Internal employee ID and company tenant ID | No | Required |
| **Financial Info** | Purchase History | Yes | No | **App functionality:** Wholesale orders, invoices, and credit balances | No | Required |
| **Financial Info** | Payment Info | Yes | No | **App functionality:** Field payment collection logs (Cash amount, UPI transaction ref, Cheque number) | No | Required |
| **Photos & Videos** | Photos | Yes | No | **App functionality:** Attaching photo proof of damaged goods during warehouse returns inspection | No | Optional (Only when capturing damaged items) |
| **App Info & Performance** | Diagnostics & Crash Logs | Yes | No | **Analytics & App performance:** Offline sync queue errors and crash diagnostic logs | Yes | Required |

---

## 3. Prominent In-App Permission Explanations (Reviewer & User Facing)

Provide these exact justifications in the Google Play Console "App access & Permissions declaration" forms and review notes:

### 3.1 Location (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE_LOCATION`)
- **Console Declaration Text:**
  ```text
  RouteFlow is a B2B logistics and field sales distribution platform for commercial FMCG distributors. Field sales executives and delivery drivers must visit 15-30 registered retail kirana stores daily along assigned beats. 

  Location is accessed during an active duty shift to:
  1. Verify the salesman is physically present at the retailer store during order booking (geofenced check-in).
  2. Provide turn-by-turn route sequencing between delivery stops.
  3. Calculate field travel distance for daily fuel allowance reimbursement.

  Location is ONLY tracked while the employee explicitly starts their duty shift, with a persistent Android foreground service notification clearly indicating tracking is active. Tracking stops immediately when 'End Shift' is tapped.
  ```

### 3.2 Camera (`android.permission.CAMERA`)
- **Console Declaration Text:**
  ```text
  Camera permission is used strictly for optical barcode and QR code scanning inside the warehouse:
  1. Scanning manufacturer barcodes on inventory items during inward stock intake.
  2. Verifying dispatch carton codes during delivery handover.
  3. Optional photo capture of damaged product packaging during returns inspection.

  Camera access is completely on-demand and is never used in the background or for biometric identification. If permission is denied, staff can manually enter barcodes without app crash.
  ```

### 3.3 Notifications (`android.permission.POST_NOTIFICATIONS`)
- **Console Declaration Text:**
  ```text
  Required on Android 13+ to provide:
  1. Persistent foreground service indicator while field staff duty shift is active (mandatory for Android foreground location policy).
  2. High-priority dispatch and delivery assignments for drivers.
  3. Urgent approval alerts to the business owner for orders exceeding credit limits.
  ```

---

## 4. Internal Testing Credentials & Reviewer Demo Script

When publishing to Google Play **Internal Testing Track**, configure the following credentials in the **App Access** section of the Google Play Console:

### 4.1 Test Accounts (All 4 Operational Roles)

> **Important:** Testing accounts operate on the live staging cloud backend.

| Role | Username / Mobile | Password / OTP | Responsibility in Demo |
|---|---|---|---|
| **Distributor Owner / Admin** | `owner` | `password123` | Complete visibility, order credit approvals, staff management, cash closing. |
| **Sales Executive** | `sales` | `password123` | Beat route, Kirana shop check-in, order booking, cash collection. |
| **Warehouse Manager** | `warehouse` | `password123` | Barcode scanning, inward stock, FEFO order picking, carton packing. |
| **Delivery Driver** | `delivery` | `password123` | Route stops, navigation, customer OTP delivery, cash custody handover. |

*Alternative Mobile Login (if testing OTP flow):*  
- Mobile: `9876543210` (or `owner`)  
- Default verification code for staging: `123456`

---

### 4.2 Reviewer 3-Minute Walkthrough Flow (Step-by-Step)

```text
Step 1: Log in as Owner (`owner` / `password123`)
- View the 'Control Room' dashboard showing daily sales, live pending credit (Udhaar), and godown alerts.
- Tap 'Approvals' to inspect a high-value pending retail order. Approve the order.

Step 2: Log in as Salesperson (`sales` / `password123`)
- Tap 'Start Shift' to initiate the daily beat.
- Select 'Mega Mart' from Beat 04, tap 'Check-In', and tap 'Book Order'.
- Add items to cart and submit. Order persists locally and syncs immediately to the cloud.

Step 3: Log in as Warehouse Manager (`warehouse` / `password123`)
- View the newly approved order under 'Picking'.
- Tap 'Start Picking', select batch (FEFO), and mark as packed in Carton #1.

Step 4: Log in as Delivery Driver (`delivery` / `password123`)
- View assigned delivery stop at 'Mega Mart' with 1 carton and amount due.
- Tap 'Proceed to Deliver' &rarr; enter OTP `1234` &rarr; mark as delivered.
- Cash collected is added to driver custody.
- Go to 'Cash Handover' to return collected funds to the owner.
```

---

## 5. Security & Keystore Policy

- **No Secrets in Version Control:** The generated keystore file `routeflow-release.jks` and local configuration `keystore.properties` are strictly excluded by `.gitignore` and are NOT tracked in git.
- **Production Keystore Rotation Note:** Because the initial keystore password appeared in the development logs during internal testing setup, **a fresh, distinct production keystore with a secret passphrase stored in an external secrets manager (e.g. Google Cloud KMS or 1Password) will be generated prior to final public production rollout.** For Google Play Internal Testing, the current keystore is fully valid and signs the bundle securely.
