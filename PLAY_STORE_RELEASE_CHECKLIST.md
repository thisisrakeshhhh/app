# Google Play Store Release Checklist for RouteFlow

**Application:** RouteFlow (`com.routeflow.app`)  
**Package:** `com.routeflow.app`  
**Current Version:** `versionCode = 1`, `versionName = "1.0"`  
**Target SDK:** 36 | **Min SDK:** 26  

---

## Phase 1: Pre-Release Build & Security Hardening (Automated in Repository)

- [x] **Cleartext Traffic Blocked:** `network_security_config.xml` blocks all HTTP in release.
- [x] **Demo Mode Hidden:** "Switch to Demo Mode" button is disabled and hidden in release builds.
- [x] **Debug OTP Hidden:** Server debug OTP autofill chip is disabled in release builds (`BuildConfig.DEBUG` only).
- [x] **R8 / ProGuard Optimization:** Explicit keep rules configured in `proguard-rules.pro` for Room entities, Hilt components, and Kotlinx Serialization models.
- [x] **Secure Keystore Signing Setup:** Release build configuration in `app/build.gradle.kts` configured to load signing credentials securely from environment variables or gitignored `keystore.properties`.
- [x] **Multi-tenant Backend Isolated:** Tenant queries strictly verified by authenticated JWT `company_id`.
- [x] **Unit & Integration Tests Passing:** 100% test pass rate across backend and Android unit suites.

---

## Phase 2: Production Infrastructure Pre-Requisites (BLOCKERS before Public Launch)

> [!WARNING]
> The following items require live external provisioning by the team before switching from Staging to Production in Google Play.

1. **Production Domain & Cloudflare Worker Routing (CRITICAL BLOCKER):**
   * **Current State:** `https://api.routeflow.com/` is not yet routed in DNS.
   * **Required Action:** Deploy `wrangler.production.toml`, create production D1 database (`routeflow-db-production`), run migrations, and map the custom domain `api.routeflow.com` to the Cloudflare Worker.
2. **Production SMS Gateway Provisioning (CRITICAL BLOCKER):**
   * **Current State:** Staging simulates SMS delivery.
   * **Required Action:** Secure an enterprise SMS gateway contract (Twilio, Gupshup, Fast2SMS) for Indian DLT-compliant transactional templates and set secrets via Wrangler:
     ```bash
     npx wrangler secret put JWT_SECRET --config wrangler.production.toml
     npx wrangler secret put SMS_GATEWAY_URL --config wrangler.production.toml
     npx wrangler secret put SMS_GATEWAY_TOKEN --config wrangler.production.toml
     ```
3. **Public Privacy Policy URL:**
   * **Required Action:** Host the contents of `PRIVACY_POLICY.md` on a publicly accessible HTTPS website (e.g. `https://routeflow.com/privacy`) and provide the URL in Google Play Console.

---

## Phase 3: Generating Release Signing Keystore & App Bundle (.aab)

To generate the release bundle (`.aab`) for Google Play upload:

### Step 1: Create an Upload Keystore (One-Time Setup)
Run the following keytool command (do NOT commit the `.jks` file to git):
```bash
keytool -genkey -v -keystore routeflow-upload-key.jks -alias routeflow-upload -keyalg RSA -keysize 2048 -validity 10000
```

### Step 2: Configure Environment or `keystore.properties`
Create a file named `keystore.properties` in the root or `app/` folder (already gitignored):
```properties
storeFile=/absolute/path/to/routeflow-upload-key.jks
storePassword=YourKeystorePassword
keyAlias=routeflow-upload
keyPassword=YourKeyPassword
```
*Alternatively, export environment variables:*
`KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

### Step 3: Build the Production Release AAB Bundle
```bash
.\gradlew.bat bundleRelease --no-daemon
```
The resulting bundle will be generated at:  
`app/build/outputs/bundle/release/app-release.aab`

---

## Phase 4: Google Play Console Setup Steps

1. **Create Application in Google Play Console:**
   * App name: **RouteFlow**
   * Default language: **English (United States)** or **English (India)**
   * App type: **App**
   * Free or Paid: **Free** (Enterprise B2B account required)
2. **App Content Declarations:**
   * **Privacy Policy:** Link to `https://routeflow.com/privacy`.
   * **App Access:** Provide credentials for reviewer testing (e.g., test Owner and Sales accounts).
   * **Ads:** Select "No, my app does not contain ads".
   * **Content Rating:** Complete questionnaire (Enterprise/Commercial app -> Everyone / Teen).
   * **Target Audience:** Select **18 and over**.
   * **Data Safety:** Complete using the pre-filled guide in [`PLAY_STORE_DATA_SAFETY.md`](file:///d:/app/PLAY_STORE_DATA_SAFETY.md).
   * **Government Apps:** Select "No".
   * **Financial Features:** Select "No, app does not offer consumer lending/financial services" (App only manages wholesale B2B distributor ledger).
3. **Foreground Service Declaration (Android 14+):**
   * Check **Location (`FOREGROUND_SERVICE_LOCATION`)**.
   * Copy answers directly from [`PERMISSION_AUDIT.md`](file:///d:/app/PERMISSION_AUDIT.md).
   * Upload a 30-second screen recording showing:
     1. Clocking in ("Start Shift").
     2. Visible foreground notification in the status tray.
     3. Clocking out ("End Shift") dismisses notification.

---

## Phase 5: Recommended Rollout Sequence

1. **Track 1: Internal Testing Track (Immediate):**
   * Upload `app-release.aab`.
   * Add distributor testers, QA, and field sales leads to Internal Testers list.
   * Verify on physical Android devices (e.g. Vivo, Samsung, Xiaomi) via Play Store internal testing link.
2. **Track 2: Closed Testing (Alpha/Beta):**
   * Invite 20+ testers across 14 days (mandatory for new personal developer accounts).
3. **Track 3: Production Release:**
   * Enable staged rollout (20% -> 50% -> 100%) after live API and SMS gateway are verified.
