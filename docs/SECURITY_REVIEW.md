# RouteFlow — Security Review & Threat Model
**Document Version:** 1.0.0  
**Compliance Standard:** OWASP Top 10 API Security & Indian DPDP Act 2023  

---

## 1. Threat Modeling & Vulnerability Analysis

### 1.1 Authentication & Token Transmission
- **Vulnerability Found**: Bearer token accepted via query parameter `?token=...` in `authMiddleware`.
  - **Risk**: Token exposure in access logs, intermediate proxies, referer headers, and browser history.
  - **Mitigation**: Removed query string parsing. Strictly require `Authorization: Bearer <jwt>` HTTP header.
- **Session Revocation Mechanism**: Every JWT payload includes `sid` (session ID). Even though JWT signature is cryptographically verified statelessly, `sessions` table is checked in D1 for revocation (`is_revoked === 0`) and expiry. This prevents token reuse upon user logout, device loss, or administrative suspension.

### 1.2 Multi-Tenant Data Isolation
- **Tenant Guard**: All SELECT, INSERT, UPDATE, DELETE queries must explicitly bind `company_id` or `organization_id` derived directly from verified session payload, never from unvalidated request bodies.
- **IDOR Prevention**: Shop, Order, and Batch endpoints check both resource ID and tenant ID in the WHERE clause:
  ```sql
  SELECT * FROM orders WHERE id = ? AND company_id = ?
  ```

### 1.3 Cryptographic Integrity
- Passwords hashed using standard `bcrypt` with salt rounds.
- Delivery OTPs generated via cryptographically secure pseudo-random numbers (4-digit numerical code, 15-minute TTL).
- Audit logs are append-only; updates and deletes are prevented by business logic.

### 1.4 Field Device Integrity
- Offline SQLite databases encrypted using Android Room SQLCipher.
- Strict anti-spoofing heuristics on GPS coordinates: Mobile client logs provider (`gps`, `network`, `fused`), accuracy radius (meters), and mock location flags.
