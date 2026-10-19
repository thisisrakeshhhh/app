import type { Context } from 'hono';

export async function sha256(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
}

/** Atomic D1 counters across Worker instances; no credentials or raw IP persisted. */
export async function rateLimit(c: Context<any>, scope: string, subject: string, limit: number, seconds = 900): Promise<boolean> {
  const start = Math.floor(Date.now() / 1000 / seconds) * seconds;
  const subjectHash = await sha256(`${scope}:${subject}`);
  const row = await (c.env.DB as D1Database).prepare(`INSERT INTO auth_rate_limits VALUES(?,?,?,1)
  ON CONFLICT(scope,subject_hash,window_start) DO UPDATE SET attempts=attempts+1 RETURNING attempts`).bind(scope, subjectHash, start).first<{ attempts: number }>();
  if ((row?.attempts ?? limit + 1) > limit) { c.header('Retry-After', String(seconds)); return false; }
  return true;
}

export const requestIp = (c: Context<any>) => c.req.header('CF-Connecting-IP') || 'local';

export function validPassword(value: unknown): value is string {
  return typeof value === 'string' && value.length >= 12 && new TextEncoder().encode(value).length <= 72;
}

/** Maps legacy backend role strings to canonical FMCG domain roles */
export function normalizeRole(role: string): string {
  const upper = (role || '').trim().toUpperCase();
  if (upper === 'SALESPERSON') return 'SALES';
  if (upper === 'WAREHOUSE_MANAGER') return 'WAREHOUSE';
  if (upper === 'DELIVERY_EXECUTIVE') return 'DELIVERY';
  return upper;
}

/** Granular enterprise RBAC capability checker supporting canonical and legacy role representations */
export function canPerform(role: string, action: string): boolean {
  const normalized = normalizeRole(role);
  const permissions: Record<string, string[]> = {
    OWNER: ['*'],
    ADMIN: [
      'catalog:read', 'catalog:write',
      'order:read', 'order:create', 'order:approve', 'order:reject', 'order:dispatch',
      'inventory:read', 'inventory:inward', 'inventory:adjust',
      'retailer:read', 'retailer:create', 'retailer:credit_override',
      'finance:settle', 'analytics:read',
      'van_sales:manage', 'van_sales:create', 'van_sales:confirm'
    ],
    WAREHOUSE: [
      'catalog:read',
      'order:read', 'order:pick', 'order:pack', 'order:dispatch',
      'inventory:read', 'inventory:inward', 'inventory:adjust',
      'van_stock:load'
    ],
    SALES: [
      'catalog:read',
      'order:read', 'order:create',
      'inventory:read',
      'retailer:read', 'retailer:create',
      'finance:collect',
      'van_sales:create', 'van_sales:confirm'
    ],
    DELIVERY: [
      'order:read', 'order:deliver',
      'inventory:van_stock',
      'finance:collect', 'finance:handover',
      'van_sales:create', 'van_sales:confirm'
    ],
    RETAILER: [
      'catalog:read',
      'order:read', 'order:create',
      'retailer:read_own_khata'
    ]
  };

  const userPerms = permissions[normalized] || [];
  return userPerms.includes('*') || userPerms.includes(action);
}

/** Route middleware helper to enforce fine-grained capability using authenticated context user */
export function requirePermission(action: string) {
  return async (c: Context<any>, next: () => Promise<void>) => {
    const user = c.get('user');
    const userRole = user?.role || c.get('userRole') || c.get('role');
    if (!userRole || !canPerform(userRole, action)) {
      return c.json({ error: `Forbidden: role '${userRole || 'UNKNOWN'}' lacks permission '${action}'` }, 403);
    }
    await next();
  };
}

/**
 * Validates that the requested organization is authorized for the given user,
 * checking organization_memberships with a backward-compatible fallback to users.company_id.
 */
export async function verifyTenantMembership(
  db: D1Database,
  userId: string,
  targetOrganizationId: string
): Promise<{ isMember: boolean; role: string | null }> {
  // 1. Check organization_memberships table
  try {
    const membership = await db.prepare(
      'SELECT role, is_active FROM organization_memberships WHERE organization_id = ? AND user_id = ?'
    )
      .bind(targetOrganizationId, userId)
      .first<{ role: string; is_active: number }>();

    if (membership) {
      if (membership.is_active === 1) {
        return { isMember: true, role: membership.role };
      }
      // Explicit membership exists but is deactivated: DENY immediately, do not fall back
      return { isMember: false, role: null };
    }
  } catch {
    // If table does not yet exist or migration is pending, proceed to legacy check
  }

  // 2. Legacy fallback to users.company_id
  const user = await db.prepare(
    'SELECT company_id, role, is_active FROM users WHERE id = ?'
  )
    .bind(userId)
    .first<{ company_id: string; role: string; is_active: number }>();

  if (user && user.is_active === 1 && user.company_id === targetOrganizationId) {
    return { isMember: true, role: user.role };
  }

  return { isMember: false, role: null };
}
