# Google Play Console Data Safety Questionnaire Mapping

This document provides exact, verified answers for completing the **Data Safety** form in the Google Play Console for **RouteFlow** (`com.routeflow.app`).

---

## 1. Overview & Data Collection Summary

* **Does your app collect or share any of the required user data types?**  
  **Yes**
* **Is all of the user data collected by your app encrypted in transit?**  
  **Yes** (Enforced over HTTPS / TLS 1.3 for all external network communications)
* **Do you provide a way for users to request that their data be deleted?**  
  **Yes** (Users can request account or transaction review/deletion via distributor administrator or privacy@routeflow.com)

---

## 2. Detailed Data Type Declarations

### A. Location
1. **Approximate location (`ACCESS_COARSE_LOCATION`)**
   * **Collected?** Yes
   * **Shared?** No (Not shared with third-party data brokers/advertisers)
   * **Processed ephemerally?** No (Stored with shift attendance and store visit records)
   * **Is this data required or optional?** Required for Field Sales & Delivery duty verification
   * **Purposes:**
     * App functionality (Verifying store visits and beat route coverage)
     * Fraud prevention, security, and compliance (Ensuring authentic physical check-ins)

2. **Precise location (`ACCESS_FINE_LOCATION`)**
   * **Collected?** Yes
   * **Shared?** No
   * **Processed ephemerally?** No
   * **Is this data required or optional?** Required for Shift Tracking
   * **Purposes:**
     * App functionality (Foreground shift tracking during active work duty)
     * Fraud prevention, security, and compliance (Accurate GPS verification of store delivery/order locations)

---

### B. Personal Info
1. **Name**
   * **Collected?** Yes (Employee name & Retailer contact person name)
   * **Shared?** No
   * **Purposes:**
     * App functionality (Displaying user identity, assigning orders, shift management)
     * Account management

2. **Phone number**
   * **Collected?** Yes (Retailer store mobile number)
   * **Shared?** Yes (Shared exclusively with authorized telecom SMS gateway for sending the 6-digit delivery confirmation OTP)
   * **Purposes:**
     * App functionality (Dispatching delivery OTPs via SMS)
     * Account management & retailer identification

3. **User IDs**
   * **Collected?** Yes (Internal employee UUID / username)
   * **Shared?** No
   * **Purposes:**
     * App functionality (Authentication, role-based access control, and audit logs)
     * Account management

---

### C. Financial Info
1. **Purchase history / Commercial Orders**
   * **Collected?** Yes (Wholesale order line items, invoices, returns, credit note amounts)
   * **Shared?** No
   * **Purposes:**
     * App functionality (Wholesale order booking, warehouse fulfillment, credit limit tracking)

2. **Other financial info (Outstanding Balances, Cash Collections)**
   * **Collected?** Yes (Retailer ledger balances, cash collected by salesperson/driver, cash handover records)
   * **Shared?** No
   * **Purposes:**
     * App functionality (Daily cash reconciliation and distributor credit control)

---

### D. Actions / User Activity
1. **App interactions**
   * **Collected?** Yes (Check-in timestamps, order booking events, OTP submission timestamps)
   * **Shared?** No
   * **Purposes:**
     * App functionality (Daily audit trail and operations reporting)
     * Fraud prevention and compliance

---

### E. Device or Other Identifiers
* **Device or other IDs**  
  * **Collected?** No (RouteFlow does not read IMEI, Android ID, MAC address, or Advertising ID / AAID)

---

## 3. Data Safety Summary Checklist for Play Console

| Data Type | Collected | Shared | Ephemeral | Purpose |
| :--- | :---: | :---: | :---: | :--- |
| **Approximate Location** | Yes | No | No | App functionality, Fraud prevention |
| **Precise Location** | Yes | No | No | App functionality (Active Shift Tracking) |
| **Name** | Yes | No | No | App functionality, Account management |
| **Phone number** | Yes | Yes (SMS Gateway) | No | App functionality (Delivery OTP Dispatch) |
| **User IDs** | Yes | No | No | Account management, Authentication |
| **Purchase History / Orders** | Yes | No | No | App functionality (B2B Distribution) |
| **Other Financial Info** | Yes | No | No | App functionality (Ledger & Handover) |
| **App Interactions / Audits** | Yes | No | No | App functionality, Fraud prevention |
