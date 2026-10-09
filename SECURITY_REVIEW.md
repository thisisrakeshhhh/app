# RouteFlow — Production Security Architecture & Verification Review

> **Enterprise Security, Multi-Tenant Isolation & Fraud Prevention Audit**  
> *Target System: Cloudflare Workers + D1 Backend & Android Native Application*

---

## 1. Executive Security Architecture

RouteFlow implements a defense-in-depth model engineered specifically for cash-intensive wholesale FMCG operations:

```
[ Android Client / Web Console ]
              │ (Mandatory TLS 1.3 / Strict HTTPS)
              ▼
    [ Cloudflare Workers Edge ]
       ├── CORS & Security Headers
       ├── JWT Verification (15-min Access Tokens)
       ├── Session Revocation Check (is_revoked = 0)
       └── Role-Based Access Control (RBAC)
              │
              ▼
    [ Cloudflare D1 Serverless Database ]
       ├── Multi-Tenant Scoping (company_id mandatory)
       ├── Atomic SQLite Triggers (Credit exposure limits)
       └── Immutable Audit Trails & Ledger Constraints
```

---

## 2. Authentication & Session Governance

### 2.1 Short-Lived Access & Server-Revocable Refresh Tokens
* **Access Tokens:** Signed using HMAC-SHA256 with 15-minute expiration (`JWT_ACCESS_EXPIRY = 900`).
* **Refresh Tokens:** High-entropy random cryptographic tokens with 30-day lifetime stored in the database.
* **Instant Session Revocation:** Refresh tokens contain an `is_revoked` flag. Any logout, deactivation, or password reset immediately updates `is_revoked = 1`, blocking token refresh attempts instantly.

### 2.2 Field Role Lockdown (Zero Password Manipulation)
* **Design Decision:** Field workers (Salespersons, Delivery Executives, Warehouse staff) frequently operate on company-provisioned mobile devices. Allowing in-app password changes introduces employee lock-out and credential theft risks.
* **Enforcement:** In-app password editing is completely excluded from Sales, Warehouse, and Delivery screens.
* **Remote Owner Reset:** Exclusively Owner and Admin roles have access to the staff password reset capability.
* **Server-Side Revocation on Reset:** When an owner resets an employee's credentials (`PUT /employees/:id/reset-password`), the backend updates the password hash AND marks all active sessions for that user ID as revoked:
  ```sql
  UPDATE refresh_tokens SET is_revoked = 1, updated_at = ? WHERE user_id = ?
  ```

---

## 3. Multi-Tenant Isolation Audit

### 3.1 Strict Tenant Boundaries
Every operational entity in RouteFlow (`retailers`, `products`, `orders`, `collections`, `dispatch_batches`, `returns`) contains a mandatory `company_id` foreign key.

* **JWT-Derived Scoping:** The `company_id` is extracted strictly from the validated JWT token claims on every API request. Users have zero ability to query or manipulate entities across different companies.
* **Database Query Binding:** Every SQL query explicitly binds `company_id`:
  ```typescript
  const orders = await db.prepare(
    "SELECT * FROM orders WHERE company_id = ? AND status = ?"
  ).bind(user.company_id, status).all();
  ```
* **Automated Test Validation:** Verified in automated integration test suite (*Subtest 4: Multi-Tenant Isolation*), asserting that Company B credentials receive 404/403 when attempting to access Company A orders, stock, or retailers.

---

## 4. Financial & Stock Fraud Prevention

### 4.1 Atomic Credit Exposure Guards (Database Triggers)
Kirana retailers operate on rolling credit (*Udhaar*). RouteFlow prevents over-extension using native SQLite database triggers that atomically calculate outstanding balance + pending unfulfilled orders:

* If an order approval would cause retailer exposure to exceed `credit_limit_paise`, the database trigger aborts the transaction with `SQLITE_CONSTRAINT_TRIGGER`.
* This completely eliminates race conditions where two simultaneous orders might slip through before balances update.

### 4.2 Tripartite Godown Inventory Ledger
* **Total Physical Stock:** Count of physical goods in the godown.
* **Reserved Stock:** Inventory committed to approved orders awaiting picking/dispatch.
* **Available Stock:** `Total Physical - Reserved Stock`.
* Prevents the godown from promising the same box of goods to multiple sales representatives.

### 4.3 Two-Step Cash Custody Handover
* When a delivery driver collects cash at a store, the collected amount immediately increments the driver's personal cash custody.
* Drivers cannot self-discharge or dismiss cash balances.
* Custody is discharged only when the Owner/Admin physically counts the cash notes and confirms acceptance on the **Cash Handover** screen. Any count discrepancies are tracked with immutable dispute logs.

---

## 5. Delivery OTP Cryptographic Validation

### 5.1 End-to-End Verification Flow
1. Driver arrives at the retailer and taps **Request OTP**.
2. Cloudflare Worker generates a 6-digit cryptographic random code with 5-minute expiry and upserts it into `delivery_otps`.
3. SMS is dispatched to the retailer's registered mobile number via authenticated HTTPS gateway.
4. Driver enters the OTP provided verbally by the shop owner.
5. The backend validates the code against the database record. If correct, order status transitions atomically to `DELIVERED`.

### 5.2 Anti-Leak & Brute-Force Safeguards
* **Attempt Bounding:** Maximum 3 verification attempts allowed (`max_attempts = 3`). Exceeding this invalidates the OTP.
* **Rate Limiting:** Minimum 60-second cooldown between resend requests.
* **Zero Production Debug Leak:** In production (`ENVIRONMENT === 'production'`), `allowDebug` is strictly disabled. Debug OTP fields (`debugOtp`, `serverDebugOtp`) are stripped from API payloads and excluded from the release APK UI.

---

## 6. Mobile Application Client Hardening

| Security Control | Implementation Detail | Status |
|---|---|:---:|
| **HTTPS Only** | `usesCleartextTraffic="false"` and `network_security_config.xml` block all plain HTTP requests. | ✅ Verified |
| **Secure Token Storage** | Auth tokens persisted using private Mode SharedPreferences; cleared on logout. | ✅ Verified |
| **Room Database Scoping** | Room tables purged during logout and re-scoped on login preventing data leaks across account switches. | ✅ Verified |
| **Obfuscation & Shrinking** | Release builds configure Proguard optimization with `isMinifyEnabled = true` and `isShrinkResources = true`. | ✅ Verified |
| **Ephemeral Location** | Foreground location tracking terminates immediately upon ending shift or logging out. | ✅ Verified |

---

## 7. Audit Conclusion

The RouteFlow architecture demonstrates robust defense mechanisms across mobile, API, and storage layers, preventing unauthorized privilege escalation, multi-tenant leaks, and cash misappropriation. The system is verified ready for production deployment.
