# RouteFlow — Master Requirements Specification
**Document Version:** 1.0.0  
**Status:** Approved Architecture Baseline  
**Classification:** FMCG Enterprise Distribution Operating System  

---

## 1. Executive Summary & Vision

RouteFlow is a multi-tenant, offline-first FMCG Distribution Intelligence and Operations Management System designed specifically for the Indian distribution ecosystem (General Trade, Kirana, Modern Trade, and Wholesale). The platform unifies the field sales force, warehouse/godown operations, delivery logistics, owner financial accounting, and retailer self-ordering into an auditable, real-time operating system.

Unlike generic ERPs or retail CRM applications, RouteFlow addresses the unique constraints of Indian FMCG distribution:
1. **Unstable connectivity**: Field sales executives (SE) and delivery executives (DE) operate in low-bandwidth basements, semi-urban routes, and remote wholesale markets. Offline operation with conflict-free deterministic synchronization is non-negotiable.
2. **Strict Physical Custody**: Inventory transitions from central godowns to delivery vans (van-sales/composite trips), to shops, to return cages with OTP verification and double-entry immutable ledgers.
3. **Complex Indian Pricing & Taxation**: Support for multi-slab GST (0%, 5%, 12%, 18%, 28%), cess, HSN codes, quantity-based schemes (e.g., 10+1 free), cash discounts (CD), trade discounts (TD), and retailer-tier rate cards.
4. **Credit Control & Lala-style Accounting**: Formalized ledger accounting for Khata (retailer credit balance), PDC (post-dated cheques), daily van-cash collections, cashier day-end reconciliation, and trip settlements.

---

## 2. Core Stakeholders & Role Hierarchy

RouteFlow operates with 7 distinct organizational personas:

| Role Name | Scope | Key Capabilities | Primary Interface |
| :--- | :--- | :--- | :--- |
| **Super Admin / Platform Owner** | Global System | Tenant provisioning, plan limits, global brand/catalogue moderation, platform telemetry. | Web Console (Superadmin) |
| **Company Owner / Managing Director** | Tenant Wide | P&L overview, live gross margin tracking, credit limit overrides, trip cash settlements, staff payroll, bank reconciliation. | Android & Web Executive Dashboard |
| **Admin / Sales Team Lead (TL)** | Branch / Tenant | Beat assignment, credit limit governance, order approvals, price master management, target tracking. | Android & Web Operations Portal |
| **Warehouse Manager / Godown Keeper** | Godown / Depot | Inward purchase receipt, batch/lot tracking, expiry quarantine, FIFO picklist generation, staging, dispatch handover. | Android (Godown Mode) & Web Godown Module |
| **Sales Executive (SE)** | Assigned Beat | Offline beat visit, GPS check-in/out, catalogue presentation, stock check, order booking, collection receipt, competitor intelligence. | Android (Sales Persona) |
| **Delivery Executive (DE)** | Assigned Trip | Vehicle loading manifest verification, sequence route navigation, OTP/signature proof of delivery, partial rejection handling, cash/UPI collection. | Android (Delivery Persona) |
| **Retailer / Kirana Merchant (Portal)** | Specific Outlet | B2B self-ordering, real-time dispatch tracking, ledger statement / khata history, invoice download, credit dispute logging. | Progressive Web App / Merchant App |

---

## 3. Real-Time Daily FMCG Operating Cycle

RouteFlow strictly enforces a state-driven daily business cycle to prevent ghost inventory, cash leakage, and unapproved credit exposure.

```
       [ 08:00 AM - Sales Force Beat Dispatch ]
                          │
                          ▼
            Sales Executive books Order at Shop
           (Status: SUBMITTED / PENDING_APPROVAL)
                          │
                          ▼
             Admin / Owner Review & Approval
        (Checks Credit Limit, Overdues, Min Margin)
                          │
                          ▼
                    Order APPROVED
      (Inventory Reserved, Picklist Sent to Godown)
                          │
                          ▼
      [ 02:00 PM - Godown Picking & Batch Packing ]
      (Picker allocates FEFO Batches, Generates Invoice)
                          │
                          ▼
              Order PACKED / READY_FOR_DISPATCH
                          │
                          ▼
      [ 04:00 PM - Trip Formation & Vehicle Staging ]
   (Orders assigned to Trip, Van Stock Loaded & Confirmed)
                          │
                          ▼
                  Order IN_TRANSIT
                          │
                          ▼
       [ Delivery to Retailer - OTP / Signature ]
    (Full Delivery OR Partial Rejection with Return Slip)
                          │
                          ▼
                  Order DELIVERED
        (Khata updated, Cash/Cheque/UPI collected)
                          │
                          ▼
      [ 08:00 PM - Driver Trip End & Cash Handover ]
     (Unsold goods returned to godown, Cash deposited to Owner)
                          │
                          ▼
                 Trip SETTLED & CLOSED
```

---

## 4. Multi-Tenant Architecture & Enterprise Boundary

### 4.1 Tenant Isolation
- Every database row is scoped by `organization_id` (and legacy `company_id` for backward compatibility).
- JWT claims carry `sub` (user_id), `sid` (session_id), `org_id` (active organization), and `role`.
- Every query executes through an enforced tenant guard. Cross-tenant leakage is prevented at database and middleware layers.

### 4.2 Shared Global vs. Tenant Catalogs
- **Global Catalog**: Master brands, master SKUs, universal barcodes (EAN-13, UPC), HSN codes, and base unit definitions. Managed at the platform level.
- **Tenant Catalog**: Distributors subscribe to global SKUs or define private SKUs, setting their own Purchase Price, Wholesale Rate, MRP, Selling Price, Tax Category, and minimum order quantities.

---

## 5. End-to-End Functional Domains

### Domain 1: Master Data Management
- Multi-warehouse/godown master (Main Godown, Damaged Goods Cage, Van/Mobile Godowns).
- Category, Brand, Variant hierarchy with multi-UOM (e.g., Piece, Box, Master Carton) and conversion factors.
- Route & Beat master with geofenced retail shop locations, GSTIN validation, and KYC documents.

### Domain 2: Inventory & Double-Entry Stock Ledger
- Every stock movement (Inward Purchase, Sales Order Allocation, Dispatch, Return, Damage, Stock Adjustment) writes an immutable record to `inventory_ledger`.
- Zero negative stock policy: System strictly prohibits reserving or dispatching uncommitted stock.
- Batch and FEFO (First-Expired, First-Out) tracking with manufacturing dates, expiry alerts, and batch-wise landed costs.

### Domain 3: Sales Force Automation (SFA)
- Geo-fenced shop visits: Enforces proximity check (<150m) or mandatory reason code for remote check-ins.
- No-Order Reasons: Audits unproductive visits (e.g., Shop Closed, Owner Not Available, Sufficient Stock, Competitor Promo).
- Offline-first Room DB synchronization: Works completely detached from network; synchronizes orders, collections, and visits upon reconnecting.

### Domain 4: Logistics & Last-Mile Delivery
- Trip Sheet / Loading Manifest: Automated aggregation of approved orders into delivery runs by beat/vehicle capacity.
- 4-digit Secure OTP delivery verification or photo-based paper signature.
- Split settlement: Supports cash, UPI QR, cheque, and credit (Khata) within the same invoice.

### Domain 5: Financial Accounting & Credit Control
- Dynamic Khata Ledger: Real-time debit (invoices) and credit (payments, return credits).
- Credit Limit & Days Aging Enforcement: Automated order hold when retailer exceeds allowed credit amount (e.g., ₹50,000) or payment age (e.g., 21 days overdue).
- Cashier Day-End Handover: Two-party cryptographic confirmation when delivery drivers surrender physical currency to the godown cashier.
