# RouteFlow Privacy Policy & Disclosures

**Last Updated:** October 2026  
**Application:** RouteFlow (com.routeflow.app)  
**Entity:** RouteFlow Technologies (Jaipur, Rajasthan, India)  
**Public Policy URL:** `https://appdashboardadmin.vercel.app/privacy`

---

## 1. Overview
RouteFlow is a B2B warehouse-to-retailer logistics and sales distribution platform designed for wholesale FMCG and Kirana distributors. This document details our data collection policies, user privacy protections, and compliance declarations for Google Play Store publication.

---

## 2. Prominent Location Disclosure (Google Play Policy Compliance)

RouteFlow collects **foreground and background location data** strictly during active employee work shifts.

### Why Location is Collected:
1. **Store Visit Verification:** Confirms that the field salesperson was physically present within the retail Kirana store's geofenced radius during check-in.
2. **Attendance & Shift Distance:** Calculates total kilometers traveled during the day for transparent conveyance and fuel reimbursement.
3. **Delivery Route Optimization:** Enables efficient delivery trip dispatching from warehouse to retail drop points.

### Foreground Service Declaration:
- RouteFlow utilizes an Android Foreground Service (`android.permission.FOREGROUND_SERVICE_LOCATION`) displaying a persistent notification in the status bar whenever location tracking is active.
- Tracking terminates immediately when the employee clocks out or ends their shift.
- Location data is **never** sold, rented, or shared with third-party advertising networks.

---

## 3. Data We Collect and Why

| Data Category | Specific Elements | Purpose | Retention |
|---|---|---|---|
| **Location** | GPS Coordinates (Latitude, Longitude), accuracy | Store check-in audit, shift distance | Active employment duration |
| **Contact Info** | Store name, mobile number, owner name | Order delivery OTP dispatch, invoices | Until retailer deactivation |
| **Financial Info** | Order totals, payment mode, cash collections | Ledger reconciliation, invoice tracking | Audit duration (7 years) |
| **Identifiers** | User ID, Device Model, Android OS Version | Session security, multi-device binding | Until session revocation |
| **Usage Data** | Timestamped action logs (Approvals, Picks) | Internal audit log to prevent fraud | Retained in audit ledger |

---

## 4. Third-Party Data Sharing
RouteFlow does **not** share user data with third-party advertisers. Data is processed exclusively by our core infrastructure providers:
- **Cloudflare Workers & D1 Database:** Edge API processing and serverless database storage (TLS 1.3 encrypted).
- **Vercel:** Web management dashboard hosting.
- **SMS Gateways (Fast2SMS / MSG91 / Twilio):** Transmits transactional 6-digit OTPs to recipient shop owners.

---

## 5. User Data Deletion & Rights
Any employee or distributor can request account deletion or data export by contacting:
- **Email:** `privacy@routeflow.in`
- **Address:** RouteFlow Technologies, Mansarovar, Jaipur, Rajasthan 302020, India.
