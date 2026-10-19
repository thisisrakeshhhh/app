# RouteFlow — Architecture Review & System Audit
**Document Version:** 1.0.0  
**Audit Date:** October 2026  
**Auditor:** Principal Software & Security Architect  

---

## 1. System Topology Overview

RouteFlow is architected as an offline-first distributed system comprising three primary tiers:

```
┌────────────────────────────────────────────────────────────────────────┐
│                          CLIENT APPLICATIONS                           │
├─────────────────────────────────────┬──────────────────────────────────┤
│ Android Native Client               │ Next.js 14 Enterprise Web        │
│ • Kotlin / Jetpack Compose          │ • TypeScript / React 18          │
│ • Room SQLite (Offline Master)      │ • Tailwind CSS / Lucide          │
│ • WorkManager Sync Engine           │ • Real-time Auto-Refresh         │
│ • Retrofit / OkHttp3                │ • Role-Based Web Workspaces      │
└──────────────────┬──────────────────┴─────────────────┬────────────────┘
                   │                                    │
                   │ HTTPS / JSON REST                  │ HTTPS / JSON REST
                   ▼                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                EDGE BACKEND (Cloudflare Workers + D1)                  │
├────────────────────────────────────────────────────────────────────────┤
│ • Hono.js Edge Framework                                               │
│ • Distributed SQLite (Cloudflare D1 with Foreign Keys Enabled)         │
│ • Stateless JWT Authentication with Stateful Session Revocation        │
│ • Multi-tenant Data Isolation Layer                                    │
│ • Double-Entry Inventory & Financial Ledger Engines                    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Tier-by-Tier In-Depth Analysis

### 2.1 Backend Tier (Cloudflare Workers + Hono + D1)

#### Strengths:
1. **Ultra-Low Latency & Global Distribution**: Deployed on Cloudflare's edge network, providing sub-50ms API response times across India without traditional VM or container cold starts.
2. **Explicit Foreign Key Enforcement**: Early migrations execute `PRAGMA foreign_keys = ON;`, maintaining referential integrity at the database layer.
3. **Session Verification Architecture**: Unlike purely stateless JWT systems that cannot instantly revoke compromised tokens, `authMiddleware` validates every request against a server-side `sessions` table (`is_revoked`, `expires_at`), balancing stateless speed with instantaneous security revocation.
4. **Comprehensive State Engines**: Existing backend modules (`daily-cycle.ts`, `warehouse.ts`, `trips.ts`, `operating.ts`) enforce strict sequence invariants (e.g., an order cannot be picked before approval, nor dispatched without picking).

#### Architectural Debt & Vulnerabilities:
1. **Query-String Bearer Authentication**: `authMiddleware` allowed reading tokens from `c.req.query('token')`. This exposes bearer tokens in server access logs, browser history, referer headers, and proxy caches. Must be removed immediately.
2. **Monolithic Controller Growth**: `backend/src/index.ts` has grown to over 2,500 lines, mixing routing, business transactions, authentication, and reporting. Needs progressive domain modularization.
3. **Tenant Membership Rigidity**: The schema strictly assumes `user.company_id`. Real-world FMCG sales leaders, regional managers, and accountants frequently consult or manage multiple distributorships. An `organization_memberships` model is required.
4. **Batched SQLite Transaction Boundaries**: Cloudflare D1 supports `db.batch([...])` for atomic multi-statement transactions. Complex workflows must rigorously leverage `db.batch` to prevent partial state writes during unexpected edge execution termination.

---

### 2.2 Mobile Client Tier (Android Native)

#### Strengths:
1. **True Offline-First Architecture**: Android models mirror backend tables in Room SQLite. Sales and delivery personnel can book orders, record cash collections, and log shop visits with zero network connectivity.
2. **Robust Sync Queue**: Uses `sync_queue` table combined with Android `WorkManager` for idempotent background sync with exponential backoff and network-type constraints.
3. **Strict Persona Partitioning**: Separate UI and navigation flows for Owner, Admin/TL, Sales, Warehouse, and Delivery.
4. **Bilingual Support**: Integrated English and Hindi resource strings throughout critical field and warehouse workflows.

#### Architectural Debt & UI Gaps:
1. **Room Migration Version Skew**: Mobile schema updates require strict, automated Room migration scripts (`Migration(x, y)`) to prevent database drops or runtime crashes for existing field devices.
2. **UI Clutter & Navigation Stacking**: Complex nested navigation in earlier builds caused state bleed between shop visits and bottom navigation tabs. The UI requires simplified, high-contrast workflows optimized for low-end devices (e.g., Vivo 1935 / 3GB RAM).

---

### 2.3 Web Dashboard Tier (Next.js 14)

#### Strengths:
1. **Clean Responsive Shell**: Modern, mobile-responsive layout built with Tailwind CSS.
2. **Direct API Integration**: Utilizes a centralized API client (`web/src/app/lib/api.ts`) managing authentication tokens, session storage, and standard error handling.

#### Architectural Debt & Missing Portals:
1. **Feature Asymmetry with Mobile**: The web application historically focused on high-level owner metrics. Critical operational tasks (dispatch trip management, warehouse staging, retail khata ledger review, price master authoring) were missing or incomplete on the web.
2. **Polling vs WebSockets**: Uses short polling for real-time order progression. A disciplined polling strategy with immediate mutation revalidation and window-focus triggers is required to maintain real-time responsiveness without overwhelming edge limits.
