# Android Permission Audit & Justification for RouteFlow

**Application Package:** `com.routeflow.app`  
**Target SDK:** 36 (Android 16 Ready, compatible with Android 14+ / SDK 34 requirements)  
**Min SDK:** 26 (Android 8.0 Oreo)  

---

## 1. Complete Permission Declaration Table

The following permissions are declared in [`AndroidManifest.xml`](file:///d:/app/app/src/main/AndroidManifest.xml):

| Permission Name | Protection Level | Runtime Consent Required? | Declared Foreground Service Type | Purpose & Policy Justification |
| :--- | :--- | :---: | :---: | :--- |
| `android.permission.INTERNET` | Normal | No | N/A | Secure HTTPS network communication with the RouteFlow Cloudflare Worker backend and offline outbox sync via WorkManager. |
| `android.permission.ACCESS_FINE_LOCATION` | Dangerous | **Yes** | N/A | Accurate GPS geotagging for retailer shop visits and route tracking during active employee duty shifts. |
| `android.permission.ACCESS_COARSE_LOCATION` | Dangerous | **Yes** | N/A | Network/cell-tower location fallback when high-precision GPS lock is obstructed indoors. |
| `android.permission.FOREGROUND_SERVICE` | Normal | No | N/A | Required on Android 9+ (API 28) for long-running shift tracking services. |
| `android.permission.FOREGROUND_SERVICE_LOCATION` | Normal | No | `location` | Required on Android 14+ (API 34+) to run `ShiftTrackingService` as a persistent, user-visible foreground location tracker. |
| `android.permission.POST_NOTIFICATIONS` | Dangerous | **Yes** (Android 13+) | N/A | Displaying persistent foreground notifications during an active shift, alerting drivers of OTP requests, and sync status. |

---

## 2. High-Risk Permission Compliance

### A. Location Permission (`ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION`)
* **Google Play Policy:** Apps must clearly justify foreground access and obtain explicit runtime consent prior to acquiring coordinates.
* **RouteFlow Implementation:**
  1. Location is accessed strictly at the point of action (Check-In button press, Order Booking submission).
  2. While on duty, `ShiftTrackingService` runs with a persistent, non-dismissible notification stating *"RouteFlow Shift Active — GPS Tracking Active"*.
  3. Clicking *"End Shift"* immediately terminates the foreground service, shuts down the location client, and stops GPS sampling.

### B. Background Location (`ACCESS_BACKGROUND_LOCATION`)
* **Declaration Status:** **NOT DECLARED / NOT REQUESTED**.
* **Rationale:** Google Play imposes an intensive policy audit for apps requesting continuous background location without an active user notification. RouteFlow adheres strictly to Google's best-practice recommendation by using a **Foreground Service with Location Type** instead of unrestricted background location.

### C. Foreground Service Location Declaration for Google Play Console (Android 14+ Policy)
When submitting to Google Play Console, Google requires a declaration answering why the app needs `FOREGROUND_SERVICE_LOCATION`:

* **Question 1: What core feature requires foreground service location?**  
  * **Answer:** Field shift duty tracking and sales territory verification. Field sales representatives and delivery drivers clock in at the beginning of their working shift. The app tracks their delivery route to ensure ordered goods reach retailers on time and verify retailer store visits.
* **Question 2: Why can this feature not be performed using background work or WorkManager?**  
  * **Answer:** Delivery drivers operate vehicles in traffic between fulfillment warehouses and retail shops. The Android OS would aggressively kill or delay periodic background workers or job schedulers when the app is in the background or screen is off. Real-time shift tracking and active route monitoring require uninterrupted foreground execution with a clear, user-visible notification showing active duty status.
* **Question 3: Can the user easily stop the foreground service?**  
  * **Answer:** Yes. A prominent "End Duty / Shift" button is visible at all times on the main screen, which immediately stops the service and dismisses the notification.

---

## 3. Hardware & Sensitive Permission Audit

* **Camera (`android.permission.CAMERA`):**  
  * **Status:** Not currently requested in Manifest. (Future photo/receipt capture will request runtime camera permissions when implemented).
* **Storage / Media (`READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES`):**  
  * **Status:** Not requested. The app stores all local data in app-private SQLite (Room) sandbox.
* **SMS (`RECEIVE_SMS` / `READ_SMS`):**  
  * **Status:** Not requested. Delivery OTPs are entered manually by the driver after being told the 6-digit code by the receiving retailer. RouteFlow does not read retailer or driver SMS inbox.
* **Phone State (`READ_PHONE_STATE`):**  
  * **Status:** Not requested. Device identification is not used; sessions are strictly secured via JWTs.

---

## 4. Exported Components Security Review

* `com.routeflow.app.core.location.ShiftTrackingService`: `android:exported="false"` (Internal only).
* `androidx.startup.InitializationProvider`: `android:exported="false"` (Internal only).
* `com.routeflow.app.app.MainActivity`: `android:exported="true"` (Single entry point containing `MAIN` / `LAUNCHER` intent filter only).
* **Summary:** Zero exported receivers, services, or internal activities exposed to third-party applications on device.
