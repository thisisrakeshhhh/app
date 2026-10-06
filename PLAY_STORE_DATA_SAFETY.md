# Google Play Store — Data Safety Form Checklist

Use these exact answers when filling out the **Data Safety** questionnaire in the Google Play Console for `com.routeflow.app`:

---

## 1. Data Collection and Security
- **Does your app collect or share any of the required user data types?**  
  👉 **Yes**
- **Is all of the user data collected by your app encrypted in transit?**  
  👉 **Yes** (All requests use HTTPS / TLS 1.3 encryption)
- **Do you provide a way for users to request that their data be deleted?**  
  👉 **Yes** (Distributor administrators can delete accounts and records, or email `privacy@routeflow.in`)

---

## 2. Specific Data Categories

### A. Location Data
- **Approximate location collected?** 👉 **Yes**
- **Precise location collected?** 👉 **Yes**
  - *Collected or Shared:* Collected only (Not shared with 3rd parties)
  - *Ephemeral or Stored:* Stored (Saved to D1 shift log for attendance & distance audit)
  - *Required or Optional:* Required for field sales and delivery shift tracking
  - *Purpose:* **App functionality**, **Analytics**, **Fraud prevention, security, and compliance**

### B. Personal Info
- **Name:** 👉 **Yes** (Employee full name, store owner name)
  - *Purpose:* App functionality, Account management
- **Email address / Username:** 👉 **Yes**
  - *Purpose:* App functionality, Authentication
- **Phone number:** 👉 **Yes**
  - *Purpose:* Delivery OTP SMS dispatch, account communications

### C. Financial Info
- **Purchase history / Transaction info:** 👉 **Yes** (Wholesale order history, cash collection records)
  - *Purpose:* App functionality, Fraud prevention

### D. Device or other identifiers
- **Device or other IDs:** 👉 **Yes** (Device model, session ID)
  - *Purpose:* Fraud prevention, security, account session management

---

## 3. Privacy Policy Link
- **Store Listing Privacy Policy URL:**  
  `https://appdashboardadmin.vercel.app/privacy`

---

## 4. Sensitive Permissions Declaration
- `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`: Used for Kirana shop GPS check-in and shift tracking.
- `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_LOCATION`: Active foreground notification displayed while recording on-duty shift distance.
- `POST_NOTIFICATIONS`: Order status updates and delivery arrival alerts.
