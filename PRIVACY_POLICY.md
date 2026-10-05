# Privacy Policy for RouteFlow

**Effective Date:** October 5, 2026  
**Last Updated:** October 5, 2026  
**Application Name:** RouteFlow ("RouteFlow", "App", "Service")  
**Target Audience:** Enterprise B2B FMCG & Distribution Entities, Authorized Employees, and Retail Partners  

---

## 1. Introduction

RouteFlow is an enterprise wholesale distribution, field sales, and delivery management platform developed for authorized businesses, distributors, and their field personnel (Sales Representatives, Warehouse Staff, and Delivery Executives).

This Privacy Policy explains how RouteFlow collects, uses, stores, and protects personal and operational information when field employees and partners access or use the RouteFlow mobile application and related services.

---

## 2. Information We Collect

### A. Account & Authentication Information
* **Employee Identifiers:** Username, Full Name, Role (Owner, Salesperson, Warehouse Manager, Delivery Executive), and assigned Enterprise/Distributor Company ID.
* **Authentication Credentials:** Encrypted authentication tokens. Passwords are never stored in plaintext on device storage or database logs.

### B. Location Information (Precise & Coarse)
* **Foreground Shift Tracking:** With explicit user authorization, RouteFlow collects GPS coordinates (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) through a persistent, user-visible foreground notification (`FOREGROUND_SERVICE_LOCATION`) **only while an employee is actively clocked into their shift or duty**.
* **Shop Visit Geotagging:** GPS coordinates are captured at the discrete moment a sales representative records a store check-in, in-store stock audit, or order booking to verify physical presence at the retailer's establishment.
* **No Background Location without Active Shift:** RouteFlow **does not** collect background location (`ACCESS_BACKGROUND_LOCATION`) when an employee is off-duty, logged out, or has ended their shift.

### C. Commercial, Sales & Inventory Records
* **Retailer Business Details:** Retailer Store Name, Contact Mobile Number, Beat/Territory, Shop Address, GPS Coordinates, and Credit Terms.
* **Transaction Data:** In-store stock audits, SKU order lines, promotional allotments, invoice totals, payment collection records (Cash, Cheque, UPI reference IDs), and customer return counts.
* **Delivery Verification (OTP & Receiver Name):** 6-digit one-time passcodes and authorized recipient names collected at the point of physical delivery handover.

### D. Device & Technical Diagnostics
* **Offline Outbox & Device Storage:** Unsynchronized transactions, visits, and stock audits stored locally in encrypted on-device SQLite (Room) pending network synchronization.
* **Diagnostic & Network Metadata:** Network state, sync timestamps, and application performance metrics. RouteFlow does not track advertising IDs (AAID/IDFA) or third-party behavioral trackers.

---

## 3. How We Use Collected Data

Collected data is utilized strictly for legitimate business and distribution operations:
1. **Order Processing & Fulfillment:** Routing booked orders from sales beats to warehouse queues for picking, packing, and dispatch.
2. **Delivery Proof & Accountability:** Validating order handover to retailer owners via cryptographically generated 6-digit OTPs and recipient identity logging.
3. **Territory Management & Fair Wage Allocation:** Recording visited retailer locations and shift active times for route optimization and field expense calculation.
4. **Credit Risk Management:** Enforcing real-time distributor credit limits and ledger reconciliations for outstanding retailer accounts.
5. **Offline Reliability:** Buffering operations locally when field personnel visit areas with weak or absent cellular connectivity.

---

## 4. Data Sharing & Disclosure

RouteFlow **never sells, rents, or monetizes** personal, operational, or location data to third parties, data brokers, or advertisers.

Data is shared exclusively in the following operational contexts:
* **Tenant Isolation:** Data collected is strictly partitioned by Company ID. Staff of Company A cannot view or access data of Company B.
* **Hosting & Cloud Infrastructure:** Scalable data storage and edge compute provided by enterprise infrastructure providers (Cloudflare D1/Workers).
* **Telecom / SMS Gateways:** Retailer phone numbers are transmitted via encrypted HTTPS to authorized telecommunications gateways strictly for sending 6-digit delivery verification OTPs.
* **Legal Compliance:** In response to lawful requests by authorized government authorities in accordance with applicable laws in India and operating jurisdictions.

---

## 5. Security & Data Protection

RouteFlow employs defense-in-depth security measures to protect business and user data:
* **End-to-End Transport Security:** All client-server communication is strictly enforced over TLS 1.3/HTTPS. Cleartext HTTP traffic is blocked in production builds.
* **On-Device Cryptography:** Access tokens and session keys are secured using the Android Keystore system and `EncryptedSharedPreferences` with `AES-256-GCM` and `AES-256-SIV`.
* **Zero Hardcoded Secrets:** Production credentials, JWT signing secrets, and telecommunication keys are managed strictly via isolated edge environment secrets.
* **Session Revocation:** Administrators can revoke compromised or terminated employee sessions in real time, invalidating refresh tokens immediately.

---

## 6. Retention & Data Deletion Rights

* **Operational Retention:** Order records, tax invoices, and cash handover logs are retained in accordance with commercial accounting and taxation regulations.
* **Employee Account Termination:** When an employee account is deactivated by an administrator, mobile app access is immediately halted.
* **Data Deletion Inquiries:** Field employees or retailers may submit access, correction, or deletion requests regarding personal data by contacting their employing distributor administrator or emailing our data privacy desk at:  
  **privacy@routeflow.com**

---

## 7. Children's Privacy

RouteFlow is strictly a B2B enterprise application intended for adult business owners and authorized corporate employees. We do not knowingly collect or solicit personal information from individuals under the age of 18.

---

## 8. Updates to this Policy

We may update this Privacy Policy from time to time to reflect operational or regulatory changes. Material changes will be accompanied by an updated effective date at the top of this document.

---

## 9. Contact Us

If you have questions regarding this Privacy Policy or RouteFlow's data handling practices:
* **Email:** privacy@routeflow.com  
* **Distributor Support Office:** Compliance & Enterprise Security Operations, RouteFlow Technologies.
