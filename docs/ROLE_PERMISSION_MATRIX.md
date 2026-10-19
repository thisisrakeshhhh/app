# RouteFlow — Role Permission Matrix (RBAC Specification)
**Document Version:** 1.0.0  
**Enforcement Engine:** Edge Middleware (`backend/src/index.ts` & `security.ts`)  

---

## 1. Enterprise RBAC Capability Matrix

The table below defines granular resource permissions across all RouteFlow user roles:

| Resource & Action | Super Admin | Company Owner | Admin / TL | Warehouse Manager | Sales Executive | Delivery Executive | Retailer |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Catalog: View Global** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Catalog: Create/Edit Master SKU** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Catalog: Manage Tenant Prices** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Order: Book at Shop (Draft)** | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| **Order: Approve / Reject** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Order: Pick & Pack (Godown)** | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Order: Assign to Trip (Dispatch)**| ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Order: Deliver & Collect OTP** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Inventory: View Stock Balances**| ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Inventory: Purchase Inward (GRN)**| ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Inventory: Physical Stock Audit**| ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Inventory: Van Stock Custody** | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| **Retailer: Create New Outlet** | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| **Retailer: Modify Credit Limit** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Retailer: View Khata Ledger** | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ (Own) |
| **Finance: Receive Cash at Shop** | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| **Finance: Handover Driver Cash** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Finance: Cashier Settlement** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Analytics: Gross Margin & P&L** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Analytics: Beat Field Coverage** | ❌ | ✅ | ✅ | ❌ | ✅ (Self)| ❌ | ❌ |
| **Analytics: Tax & GST GSTR-1** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## 2. API Authorization Enforcement Model

In RouteFlow, authorization is enforced hierarchically:

1. **Authentication Guard**: Verifies cryptographic JWT signature, valid expiry, and non-revoked session ID in `sessions` table.
2. **Tenant Boundary Guard**: Enforces `request.organization_id === user.organization_id`.
3. **Permission Guard (`checkPermission`)**: Inspects user's active role against required action permission string:

```typescript
export function canPerform(role: string, action: string): boolean {
  const permissions: Record<string, string[]> = {
    OWNER: ['*'],
    ADMIN: [
      'catalog:read', 'catalog:write',
      'order:read', 'order:create', 'order:approve', 'order:reject', 'order:dispatch',
      'inventory:read', 'inventory:inward',
      'retailer:read', 'retailer:create',
      'finance:settle', 'analytics:read'
    ],
    WAREHOUSE: [
      'catalog:read',
      'order:read', 'order:pick', 'order:pack', 'order:dispatch',
      'inventory:read', 'inventory:inward', 'inventory:adjust'
    ],
    SALES: [
      'catalog:read',
      'order:read', 'order:create',
      'inventory:read',
      'retailer:read', 'retailer:create',
      'finance:collect'
    ],
    DELIVERY: [
      'order:read', 'order:deliver',
      'inventory:van_stock',
      'finance:collect', 'finance:handover'
    ],
    RETAILER: [
      'catalog:read',
      'order:read', 'order:create',
      'retailer:read_own_khata'
    ]
  };

  const userPerms = permissions[role] || [];
  return userPerms.includes('*') || userPerms.includes(action);
}
```
