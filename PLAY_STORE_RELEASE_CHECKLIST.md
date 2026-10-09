# RouteFlow — Google Play Store Release & Compliance Checklist

> **Comprehensive Readiness Guide for Google Play Store Production Release**  
> *Target Artifact: Android App Bundle (`.aab`) | Compliance Level: Android 15 (API 35/36)*

---

## 1. Application Identity & Configuration

| Parameter | Value in Repository | Verification Status |
|---|---|:---:|
| **Package Name (`applicationId`)** | `com.routeflow.app` | ✅ Verified |
| **App Name** | `RouteFlow` | ✅ Verified |
| **Version Code** | `1` | ✅ Configured |
| **Version Name** | `1.0` | ✅ Configured |
| **Minimum SDK** | `26` (Android 8.0 Oreo) | ✅ Verified |
| **Target / Compile SDK** | `36` (Android 15+ compatible) | ✅ Verified |
| **Cleartext Traffic** | `android:usesCleartextTraffic="false"` (Mandatory HTTPS) | ✅ Enforced |
| **Launcher Icons** | `@mipmap/ic_launcher` & `@mipmap/ic_launcher_round` | ✅ Present |

---

## 2. Release Signing & Keystore Setup

The repository is configured to automatically sign release builds when `keystore.properties` is present.

### Step 2.1: Generate Production Keystore (One-time)
Run this command in terminal to create the official release signing key:

```bash
keytool -genkeypair -v \
  -keystore routeflow-release.jks \
  -alias routeflow-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storetype JKS
```

### Step 2.2: Configure `keystore.properties` (Do NOT commit to Git)
Create `d:\app\keystore.properties` (already ignored by `.gitignore`):

```properties
storeFile=../routeflow-release.jks
storePassword=YOUR_SECURE_KEYSTORE_PASSWORD
keyAlias=routeflow-key
keyPassword=YOUR_SECURE_KEY_PASSWORD
```

### Step 2.3: Build Signed Android App Bundle (AAB)
```bash
.\gradlew.bat bundleRelease --no-daemon
```

*Output Location:*  
`app\build\outputs\bundle\release\app-release.aab`

---

## 3. Privacy Policy & Google Play Data Safety Compliance

The public privacy policy is live and prerendered at:  
👉 **`https://appdashboardadmin.vercel.app/privacy`**

### Google Play Console Data Safety Declarations:

| Data Type | Collected? | Shared? | Purpose | Ephemeral? |
|---|:---:|:---:|---|:---:|
| **Approximate Location** | Yes | No | App functionality (Beat route navigation, store proximity) | No |
| **Precise Location** | Yes | No | Field attendance audit, shift travel calculation | Bound to active shift |
| **Name & Phone** | Yes | No | Account identification, kirana store contact directory | No |
| **User ID & Username** | Yes | No | Authentication & role-based access control | No |
| **Purchase History** | Yes | No | Core app functionality (Orders & invoices) | No |
| **Financial Info (Collections)** | Yes | No | Payment reconciliation (Cash, UPI, Cheque) | No |
| **Photos & Videos** | Yes (Optional) | No | Uploaded only when attaching proof of damaged goods | No |
| **Crash Logs & Diagnostics** | Yes | No | Offline sync error recovery & app performance monitoring | Yes |

### Security Declarations:
- **Data Encrypted in Transit:** Yes (HTTPS/TLS encryption in transit strictly enforced via `network_security_config.xml`).
- **Account Deletion Supported:** Yes (Admin console 1-click deactivation + email `privacy@routeflow.in`).
- **Data Collection Required:** Yes (B2B commercial operations software; field staff require login).

---

## 4. Prominent In-App Disclosures & Permissions

| Permission | In-App Justification | User Consent Flow |
|---|---|---|
| `ACCESS_FINE_LOCATION` | Required to record salesman shop visit attendance and calculate daily travel. | Prominent runtime rationale dialog presented upon tapping **Start Shift**. |
| `ACCESS_COARSE_LOCATION` | Fallback geofencing in low GPS accuracy markets. | Standard Android location permission flow. |
| `FOREGROUND_SERVICE_LOCATION` | Continuous shift tracking notification while app is in background. | Persistent system notification with Stop Shift action. |
| `POST_NOTIFICATIONS` | Alerts owner of pending high-value orders and notifies drivers of new dispatches. | Requested at first app launch (Android 13+). |
| `CAMERA` | Real-time optical barcode scanning for godown inventory and damaged returns inspection. | Requested when opening **Scan Product** modal with graceful fallback. |

---

## 5. Production Build Verification Checklist

Before publishing the `.aab` to Closed or Production tracks:

- [x] **Zero Demo Quick-Fills:** Confirmed `BuildConfig.BUILD_TYPE != "release"` hides all demo account buttons on the login screen.
- [x] **Zero Staging Labels:** `Step 2/8 • Demo` badges hidden when `STAGING_MODE = false`.
- [x] **Zero OTP Leaks:** `debugOtp` and `serverDebugOtp` completely stripped in release builds and production backend (`ENVIRONMENT = 'production'`).
- [x] **Zero Technical Cloudflare/D1 Strings:** Pure business vocabulary across all strings and UI labels.
- [x] **Currency Formatting:** All monetary displays use `CurrencyFormatter` with proper `₹` symbols and Indian number grouping.
- [x] **Hindi / English Localization:** Verified zero text clipping on 360dp narrow screens.
- [x] **Bottom Navigation Clearance:** `120.dp` bottom padding verified across all screens preventing navigation overlap.
- [x] **Multi-Tenant Room Scoping:** Room database tables purged on logout and reconstructed per company ID on login.
- [x] **Production Backend Separation:** Production configuration isolated in `backend/wrangler.production.toml`.
- [x] **Release Proguard Optimization:** `isMinifyEnabled = true` and `isShrinkResources = true` enabled in release build type.

---

## 6. Recommended Release Track Progression

1. **Internal Testing Track:** Upload `app-release.aab` &rarr; invite internal QA and distributor pilot users (5–10 devices).
2. **Closed Testing Track (Alpha/Beta):** Test in production conditions across 2 pilot FMCG distributors in Jaipur for 7 days.
3. **Production Rollout:** 100% rollout on Google Play Store once closed testing verifies zero crash rate.
