# RouteFlow — Production Deployment & Device Execution Guide
**Version:** 1.0.0  
**Target Device:** Vivo Physical Android Device (USB Debugging / WiFi ADB)  
**Edge Platform:** Cloudflare Workers + Cloudflare D1 Database  

---

## 1. Quick-Start: Run on Connected Vivo Android Device

### Step 1: Verify Device Connection
Ensure USB Debugging is enabled on the Vivo phone:
```powershell
adb devices -l
```
*Expected Output: `xxxxxxx device model:vivo_1904 ...`*

### Step 2: Launch Flutter App in Debug / Profile Mode
Navigate to `flutter_distributor`:
```powershell
cd d:\app\flutter_distributor
flutter pub get
flutter run -d <device_id>
```

### Step 3: Fast Demo Verification
1. Sign in as **Imran Khan** (Sales Representative) or **Sovereign Owner**.
2. Tap **Add Shop** on the Sales Beat:
   - Enter Shop Name: `Maa Ambey Kirana`
   - Owner Name: `Rajesh Sharma`
   - Mobile: `9829012345`
   - Tap **Capture Current Location** (records GPS lat/lng with accuracy meters).
   - Tap **Save Shop** -> Observe instantaneous creation with `LOCAL-SHP-...` provisional badge.
3. Tap **Order Booking**:
   - Add 2 Boxes of *Kurkure Masala Munch*.
   - Tap **Review & Confirm**.
   - Notice data-driven pricing, zero float round-offs, and provisional order identifier `LOCAL-ORD-...`.
4. Open **Sync Status**:
   - Tap the cloud banner or sync icon.
   - Observe honest status: **"Saved on this phone (Offline Outbox)"**.
   - View the 3-step audit timeline: Booked on Device -> Saved in Local Outbox (Sequence #N) -> Cloud Sync (Pending).

---

## 2. Production Android Release APK Build

### Step 1: Keystore & Properties Check
Ensure `keystore.properties` points to `routeflow-release.jks`:
```properties
storePassword=***
keyPassword=***
keyAlias=routeflow
storeFile=../routeflow-release.jks
```

### Step 2: Build Release APK
```powershell
cd d:\app\flutter_distributor
flutter build apk --release --split-per-abi
```
Outputs are generated in `flutter_distributor/build/app/outputs/flutter-apk/`:
- `app-arm64-v8a-release.apk` (Recommended for modern Vivo devices)
- `app-armeabi-v7a-release.apk`

### Step 3: Install Directly to Device
```powershell
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 3. Cloudflare D1 Backend Migration Deployment

### Step 1: Create Staging D1 Database & Bindings
If the staging database is not yet initialized in your Cloudflare account:
```powershell
cd d:\app\backend
npx wrangler d1 create routeflow-d1-staging
```
Set production / staging JWT secret:
```powershell
npx wrangler secret put JWT_SECRET
```

### Step 2: Run Staging Migrations
Apply all schema migrations (including `0024_offline_sync_outbox_support.sql`, `0025_retailer_class_settings.sql`, `0026_products_oversell_guard_trigger.sql`, and `0027_product_packaging_units.sql`) to the Cloudflare D1 staging database:
```powershell
cd d:\app\backend
npx wrangler d1 migrations apply routeflow-d1-staging --remote
```

### Local Isolated D1 Test Server & Emulation Limits Warning
To run isolated, local-only end-to-end tests against real D1 without touching remote databases:
```powershell
cd d:\app\backend
npm test
# Or boot standalone runner for client HTTP testing:
node test/run-isolated-server.mjs
```

> [!WARNING]
> **CRITICAL: In-Memory D1 Emulator Limits vs. Production Cloudflare D1**
> The local test harness runs on an in-memory SQLite D1 emulator with all migrations `0001` through `0027` applied. While this verifies schema consistency, SQL trigger execution (`trg_prevent_oversell`), and transactional invariants:
> 1. **Production Distributed D1 Multi-Writer Concurrency:** Cloudflare D1 in production uses distributed SQLite replication. Concurrency races, serialized lock acquisition, and distributed batch limits behave differently under high network contention compared to single-process in-memory SQLite.
> 2. **Pre-Production Staging Requirement:** Before production deployment, the entire stress race suite (`stress-concurrency-sync.test.mjs` and `sync_e2e_real_wire_test.dart`) **MUST be re-run against a real Cloudflare D1 staging database** via `wrangler dev --remote` or deployed staging worker. Do not rely on local emulator results alone for production concurrency guarantees.
> 3. **Migration 0026 Trigger Impact:** Migration `0026_products_oversell_guard_trigger.sql` defines `RAISE(ABORT, ...)` triggers directly on `products`. Any writer that attempts to modify `reserved_quantity > stock_quantity` will cause the entire transaction to abort. Verify that all legacy batch updates, inward GRNs, and adjustments observe this constraint.

### Step 3: Deploy Cloudflare Worker API
Deploy edge worker endpoints:
```powershell
npx wrangler deploy --env staging
```

### Step 4: Verify Health Check & Sync Endpoints
```powershell
curl -I https://staging-api.routeflow.in/health
curl -I https://staging-api.routeflow.in/sync/push
```

---

## 4. Client Demo Script for Distributor Owner ("Lala")

| Stage | Feature Demonstrated | Lala's Pain Point Addressed | What to Point Out on Screen |
|---|---|---|---|
| **1** | **Add Shop (Pillar A)** | "My salesperson creates fake shops or takes 5 minutes per shop." | Show the 20-second quick form, live GPS accuracy pill (±14m), and duplicate phone/GSTIN warnings. |
| **2** | **Mixed-Unit Packaging & Pricing** | "Calculators make mistakes with boxes vs strips, losing us margin." | Add 1 Box and 3 Loose Strips in one cart. Show exact integer rupee/paise math with no 1-rupee rounding errors. |
| **3** | **Zero-Network Sales Booking** | "Salesmen complain app crashes when internet drops in market." | Toggle Airplane Mode. Book an order. Order is confirmed in 200ms with provisional ID `LOCAL-ORD-...`. |
| **4** | **Credit / Khata Protection** | "Salespeople give udhaar to risky or new shops without my permission." | Select a Class D or New shop. Show the Credit/Khata option is disabled with clear red notice. |
| **5** | **Honest Sync & Outbox Monitor** | "Other apps say 'synced' and orders vanish into thin air." | Open Sync Status. Point to "Saved on this phone (Offline Outbox)" with exact FIFO Sequence number. |
| **6** | **Owner Control Room** | "I want total control over credit limits and damaged stock." | Switch to Owner role. Show today's live bookings, adjust Class B credit limit, and view inward GRN damage isolation. |
