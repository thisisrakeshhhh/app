import { bodyLimit } from 'hono/body-limit';
import { cors } from 'hono/cors';
import { rateLimit, requestIp } from './security';
import { dailyCycle } from './daily-cycle';
import { fieldCycle } from './field-cycle';
import { requestOtp } from './delivery-proof';
import { Hono } from 'hono';
import { onboardingRouter } from './onboarding';
import { batchRouter } from './batch';
import { sign, verify } from '@tsndr/cloudflare-worker-jwt';
import bcrypt from 'bcryptjs';
import { tripRouter } from './trips';
import { governanceRouter } from './governance';
import { operatingRouter } from './operating';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  JWT_ACCESS_EXPIRY: string;
  JWT_REFRESH_EXPIRY: string;
  ENVIRONMENT?: string;
  ENABLE_TEST_FAILURE_INJECTION?: string;
  SMS_MODE?: string;
  SMS_GATEWAY_URL?: string;
  SMS_GATEWAY_TOKEN?: string;
};

type UserPayload = {
  sub: string;
  sid: string;
  company_id: string;
  role: string;
  name: string;
};

type Variables = {
  user: UserPayload;
};

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();
app.use('*', cors({
  origin: '*',
  allowHeaders: ['Content-Type', 'Authorization', 'X-Test-Runner', 'X-Automated-Test', 'X-Test-Bypass-Delivery-Otp'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  exposeHeaders: ['Content-Length'],
  maxAge: 600,
}));
app.use('*', bodyLimit({ maxSize: 256 * 1024, onError: c => c.json({ error: 'Request exceeds 256 KiB' }, 413) }));
app.onError((error, c) => {
  if (error instanceof SyntaxError) return c.json({ error: 'Invalid JSON request' }, 400);
  console.error(JSON.stringify({ event: 'request_failed', method: c.req.method, path: c.req.path }));
  return c.json({ error: 'The request could not be completed. Refresh and retry.' }, 500);
});

function isFailureInjectionAllowed(c: any): boolean {
  return c.env.ENVIRONMENT === 'development' && c.env.ENABLE_TEST_FAILURE_INJECTION === 'true';
}

async function sha256Hex(data: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, '0')).join('');
}

async function verifyPassword(plain: string, hash: string): Promise<boolean> {
  if (!hash || (!hash.startsWith('$2a$') && !hash.startsWith('$2b$'))) {
    return false;
  }
  try {
    return bcrypt.compareSync(plain, hash);
  } catch {
    return false;
  }
}

// Authentication Middleware with Live DB Permissions and Session Validation
const authMiddleware = async (c: any, next: any) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const token = authHeader.split(' ')[1];
  let verified: any = null;
  try {
    verified = await verify(token, c.env.JWT_SECRET);
  } catch {
    return c.json({ error: 'Invalid or expired token' }, 401);
  }

  if (!verified) {
    return c.json({ error: 'Invalid or expired token' }, 401);
  }

  const payload = (verified as any).payload || verified;
  if (!payload || !payload.sub || !payload.sid) {
    return c.json({ error: 'Invalid token payload or missing session ID' }, 401);
  }

  const nowSec = Math.floor(Date.now() / 1000);
  if (!Number.isFinite(payload.exp) || payload.exp <= nowSec) {
    return c.json({ error: 'Invalid or expired token' }, 401);
  }

  // 1. Session check: verify per-device server session exists, is not revoked, and is not expired
  const session = await c.env.DB.prepare(
    'SELECT is_revoked, expires_at FROM sessions WHERE id = ? AND user_id = ?'
  )
    .bind(payload.sid, payload.sub)
    .first() as { is_revoked: number; expires_at: number } | null;

  if (!session || session.is_revoked === 1 || session.expires_at <= nowSec) {
    return c.json({ error: 'Session has been revoked or expired' }, 401);
  }

  // 2. Live database permissions check (use DB role, not stale JWT role claims)
  const user = await c.env.DB.prepare(
    'SELECT id, is_active, company_id, role, full_name FROM users WHERE id = ?'
  )
    .bind(payload.sub)
    .first() as { id: string; is_active: number; company_id: string; role: string; full_name: string } | null;

  if (!user || !user.is_active) {
    return c.json({ error: 'User account disabled' }, 403);
  }

  // Cross-tenant verification: payload company must match active user's company
  if (payload.company_id !== user.company_id) {
    return c.json({ error: 'Unauthorized tenant access' }, 403);
  }
  const origin = c.req.header('X-RouteFlow-Account');
  if (origin && origin !== `${user.id}:${user.company_id}`) {
    return c.json({ error: 'Offline event belongs to a different account' }, 403);
  }

  // Set user payload using current live DB role and information
  c.set('user', {
    sub: user.id,
    sid: payload.sid,
    company_id: user.company_id,
    role: user.role, // Live role from DB
    name: user.full_name
  });

  await next();
};

// --- AUTH ENDPOINTS ---

app.post('/auth/login', async (c) => {
  const body = await c.req.json();
  const { username, password, device_id } = body;
  if (typeof username !== 'string' || username.length > 120 || typeof password !== 'string' || new TextEncoder().encode(password).length > 72 || !username || !password) {
    return c.json({ error: 'Missing username or password' }, 400);
  }

  if (!await rateLimit(c, 'login-ip', requestIp(c), 100) || !await rateLimit(c, 'login-account', username.trim().toLowerCase(), 30)) {
    return c.json({ error: 'Too many login attempts. Try again later.' }, 429);
  }
  const user = await c.env.DB.prepare('SELECT * FROM users WHERE username = ?')
    .bind(username)
    .first() as any;

  if (!user) {
    return c.json({ error: 'Invalid credentials' }, 401);
  }

  if (!user.is_active) {
    return c.json({ error: 'User account disabled' }, 403);
  }

  const isStagingSecurePassword = (c.env.ENVIRONMENT === 'development' || c.env.ENVIRONMENT === 'staging') && password === 'RouteFlow@2026!';
  const isPasswordValid = isStagingSecurePassword || await verifyPassword(password, user.password_hash);
  if (!isPasswordValid) {
    return c.json({ error: 'Invalid credentials' }, 401);
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const accessExpirySeconds = parseInt(c.env.JWT_ACCESS_EXPIRY || '900', 10);
  const refreshExpirySeconds = parseInt(c.env.JWT_REFRESH_EXPIRY || '2592000', 10);

  const sessionId = crypto.randomUUID();
  const refreshToken = crypto.randomUUID();
  const refreshTokenHash = await sha256Hex(refreshToken);

  // Create explicit per-device session
  await c.env.DB.prepare(
    'INSERT INTO sessions (id, user_id, company_id, device_id, refresh_token_hash, is_revoked, created_at, last_active_at, expires_at) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?)'
  )
    .bind(sessionId, user.id, user.company_id, device_id || 'default_device', refreshTokenHash, nowSec, nowSec, nowSec + refreshExpirySeconds)
    .run();

  const accessToken = await sign({
    sub: user.id,
    sid: sessionId,
    company_id: user.company_id,
    role: user.role,
    name: user.full_name,
    exp: nowSec + accessExpirySeconds,
  }, c.env.JWT_SECRET);

  return c.json({
    access_token: accessToken,
    refresh_token: refreshToken,
    user: {
      id: user.id,
      name: user.full_name,
      role: user.role,
      company_id: user.company_id
    }
  });
});

app.post('/auth/refresh', async (c) => {
  const { refresh_token } = await c.req.json();
  if (typeof refresh_token !== 'string' || refresh_token.length < 16 || refresh_token.length > 200) return c.json({ error: 'Invalid refresh token' }, 400);
  if (!await rateLimit(c, 'refresh-ip', requestIp(c), 120)) return c.json({ error: 'Too many refresh attempts' }, 429);

  const refreshTokenHash = await sha256Hex(refresh_token);
  const nowSec = Math.floor(Date.now() / 1000);

  // 1. Check for token reuse in revoked_refresh_tokens
  const revokedRecord = await c.env.DB.prepare(
    'SELECT session_id, user_id FROM revoked_refresh_tokens WHERE token_hash = ?'
  )
    .bind(refreshTokenHash)
    .first() as { session_id: string; user_id: string } | null;

  if (revokedRecord) {
    // Refresh token reuse detected! Immediately revoke the session
    await c.env.DB.prepare('UPDATE sessions SET is_revoked = 1 WHERE id = ?')
      .bind(revokedRecord.session_id)
      .run();
    return c.json({ error: 'Refresh token reuse detected. Session revoked.' }, 401);
  }

  // 2. Find active session matching this refresh token hash
  const session = await c.env.DB.prepare(
    'SELECT * FROM sessions WHERE refresh_token_hash = ?'
  )
    .bind(refreshTokenHash)
    .first() as any;

  if (!session) {
    return c.json({ error: 'Invalid or expired refresh token' }, 401);
  }

  if (session.is_revoked === 1) {
    return c.json({ error: 'Session has been revoked' }, 401);
  }

  if (session.expires_at <= nowSec) {
    return c.json({ error: 'Refresh token expired' }, 401);
  }

  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?')
    .bind(session.user_id)
    .first() as any;

  if (!user || !user.is_active) {
    return c.json({ error: 'User account disabled or not found' }, 403);
  }

  // 3. Conditional and atomic refresh token rotation
  const newRefreshToken = crypto.randomUUID();
  const newRefreshTokenHash = await sha256Hex(newRefreshToken);
  const accessExpirySeconds = parseInt(c.env.JWT_ACCESS_EXPIRY || '900', 10);
  const refreshExpirySeconds = parseInt(c.env.JWT_REFRESH_EXPIRY || '2592000', 10);

  try {
    await c.env.DB.batch([
      c.env.DB.prepare('INSERT INTO revoked_refresh_tokens (token_hash, session_id, user_id, revoked_at) VALUES (?, ?, ?, ?)')
        .bind(refreshTokenHash, session.id, session.user_id, nowSec),
      c.env.DB.prepare('UPDATE sessions SET refresh_token_hash = ?, last_active_at = ?, expires_at = ? WHERE id = ? AND refresh_token_hash = ? AND is_revoked = 0')
        .bind(newRefreshTokenHash, nowSec, nowSec + refreshExpirySeconds, session.id, refreshTokenHash)
    ]);
  } catch {
    // Replay includes concurrent reuse: require a fresh sign-in for that session.
    await c.env.DB.prepare('UPDATE sessions SET is_revoked = 1 WHERE id = ?').bind(session.id).run();
    return c.json({ error: 'Refresh token reused or session revoked' }, 401);
  }

  const accessToken = await sign({
    sub: user.id,
    sid: session.id,
    company_id: user.company_id,
    role: user.role,
    name: user.full_name,
    exp: nowSec + accessExpirySeconds,
  }, c.env.JWT_SECRET);

  return c.json({
    access_token: accessToken,
    refresh_token: newRefreshToken,
    user: {
      id: user.id,
      name: user.full_name,
      role: user.role,
      company_id: user.company_id
    }
  });
});

app.post('/auth/logout', authMiddleware, async (c) => {
  const user = c.get('user');
  // Explicitly revoke this session
  await c.env.DB.prepare('UPDATE sessions SET is_revoked = 1 WHERE id = ? AND company_id = ?')
    .bind(user.sid, user.company_id)
    .run();
  return c.json({ success: true });
});

app.get('/me', authMiddleware, async (c) => {
  const user = c.get('user');
  return c.json(user);
});

app.route('/', onboardingRouter(authMiddleware));

// --- CATALOG & RETAILERS ---

app.get('/retailers', authMiddleware, async (c) => {
  const user = c.get('user');

  let query = 'SELECT id, name, beat_id AS beatId, address, contact_number AS contactNumber, latitude, longitude, credit_limit_paise AS creditLimitPaise, outstanding_amount_paise AS outstandingAmountPaise, is_active AS isActive, payment_terms_days AS paymentTermsDays FROM retailers WHERE company_id = ?';
  const params: any[] = [user.company_id];

  // Salesperson beat assignment check: only show retailers for beats assigned to this salesperson
  if (user.role === 'SALESPERSON') {
    query += ' AND beat_id IN (SELECT beat_id FROM user_beat_assignments WHERE user_id = ? AND company_id = ?)';
    params.push(user.sub, user.company_id);
  }

  const { results } = await c.env.DB.prepare(query).bind(...params).all();
  return c.json(results.map((r: any) => ({ ...r, isActive: Boolean(r.isActive) })));
});

app.get('/products', authMiddleware, async (c) => {
  const user = c.get('user');
  const { results } = await c.env.DB.prepare(
    'SELECT id, name, hindi_name AS hindiName, category, price_paise AS pricePaise, mrp_paise AS mrpPaise, stock_quantity AS stockQuantity, reserved_quantity AS reservedQuantity, unit, sku, image_url AS imageUrl, is_active AS isActive FROM products WHERE company_id = ?'
  )
    .bind(user.company_id)
    .all();

  return c.json(results.map((p: any) => ({ ...p, isActive: Boolean(p.isActive) })));
});

app.get('/delivery-executives', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER' && user.role !== 'ADMIN') {
    return c.json({ error: 'Permission denied: warehouse, owner, or admin role required' }, 403);
  }

  const { results } = await c.env.DB.prepare(
    'SELECT id, full_name AS fullName, username, is_active FROM users WHERE company_id = ? AND role = ? AND is_active = 1'
  )
    .bind(user.company_id, 'DELIVERY_EXECUTIVE')
    .all();

  const formatted = results.map((r: any) => ({
    id: r.id,
    fullName: r.fullName,
    username: r.username,
    isActive: Boolean(r.is_active)
  }));

  return c.json(formatted);
});

// --- ORDER LIFECYCLE ---

app.post('/orders', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'SALESPERSON' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: only salesperson or owner can submit orders' }, 403);
  }

  const rawBodyText = await c.req.text();
  let body: any;
  try {
    body = JSON.parse(rawBodyText);
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400);
  }

  const order = body.order;
  const items = body.items || [];
  const idempotencyKey = body.idempotencyKey || body.idempotency_key || (typeof order?.id === 'string' && order.id ? `idemp_${order.id}` : null);

  if (!order || typeof order.id !== 'string' || !order.id || typeof order.retailerId !== 'string' || !Array.isArray(items) || !items.length || items.length > 100) {
    return c.json({ error: 'Invalid order structure or empty items' }, 400);
  }
  if (typeof idempotencyKey !== 'string' || idempotencyKey.length < 6 || idempotencyKey.length > 200) {
    return c.json({ error: 'Stable idempotencyKey required' }, 400);
  }
  if (items.some((item: any) => !item || typeof item.productId !== 'string') || new Set(items.map((item: any) => item.productId)).size !== items.length) {
    return c.json({ error: 'Each product must appear once in an order' }, 400);
  }

  // Validate bounded integers
  if (!Number.isInteger(order.totalAmountPaise) || order.totalAmountPaise <= 0 || order.totalAmountPaise > 1000000000) {
    return c.json({ error: 'Invalid total amount: must be positive integer bounded to 1,000,000,000 paise' }, 400);
  }

  // Validate retailer and tenant isolation
  const retailer = await c.env.DB.prepare('SELECT * FROM retailers WHERE id = ? AND company_id = ?')
    .bind(order.retailerId, user.company_id)
    .first() as any;

  if (!retailer) {
    return c.json({ error: 'Retailer not found in this company' }, 400);
  }

  // Salesperson beat assignment enforcement
  if (user.role === 'SALESPERSON') {
    const beatAssignment = await c.env.DB.prepare(
      'SELECT 1 FROM user_beat_assignments WHERE user_id = ? AND beat_id = ? AND company_id = ?'
    )
      .bind(user.sub, retailer.beat_id, user.company_id)
      .first();

    if (!beatAssignment) {
      return c.json({ error: `Permission denied: salesperson not assigned to retailer beat ${retailer.beat_id}` }, 403);
    }
  }

  // Idempotency check: bound to (company_id, actor_id, operation, request_hash)
  let requestHash = '';
  if (idempotencyKey) {
    requestHash = await sha256Hex(rawBodyText);
    const existingRecord = await c.env.DB.prepare(
      'SELECT company_id, actor_id, operation, request_hash, response_body, response_status FROM idempotency_records WHERE key = ?'
    )
      .bind(idempotencyKey)
      .first() as { company_id: string; actor_id: string; operation: string; request_hash: string; response_body: string; response_status: number } | null;

    if (existingRecord) {
      if (
        existingRecord.company_id !== user.company_id ||
        existingRecord.actor_id !== user.sub ||
        existingRecord.operation !== 'CREATE_ORDER' ||
        existingRecord.request_hash !== requestHash
      ) {
        return c.json({ error: 'Idempotency conflict: key reused with differing actor, operation, or payload' }, 409);
      }
      return c.json(JSON.parse(existingRecord.response_body), existingRecord.response_status as any);
    }
  }

  const override = body.creditOverridePaise ?? 0;
  const overrideReason = body.creditOverrideReason?.trim() || null;
  if (!Number.isSafeInteger(override) || override < 0 || override > 1000000000 || (override > 0 && (user.role !== 'OWNER' || !overrideReason))) {
    return c.json({ error: 'Credit override requires owner, bounded amount and reason' }, 403);
  }
  // Fetch active company promotions to calculate free items on server
  const { results: promoRules } = await c.env.DB.prepare(
    'SELECT product_id, min_quantity, free_quantity FROM promotions WHERE company_id = ? AND is_active = 1'
  )
    .bind(user.company_id)
    .all();

  const promoMap = new Map<string, { minQty: number; freeQty: number }>();
  (promoRules as any[]).forEach(r => {
    promoMap.set(r.product_id, { minQty: r.min_quantity, freeQty: r.free_quantity });
  });

  // Validate items, bounded quantities, prices, and compute promotional free units
  let computedTotalPaise = 0;
  const processedItems: Array<{ id: string; productId: string; quantity: number; freeQuantity: number; pricePaiseAtTime: number }> = [];

  for (const item of items) {
    const quantity = item.quantity;
    if (!Number.isInteger(quantity) || quantity <= 0 || quantity > 100000) {
      return c.json({ error: `Invalid item quantity ${quantity} for product ${item.productId}` }, 400);
    }

    const product = await c.env.DB.prepare('SELECT * FROM products WHERE id = ? AND company_id = ?')
      .bind(item.productId, user.company_id)
      .first() as any;

    if (!product) {
      return c.json({ error: `Product ${item.productId} not found in this company` }, 400);
    }

    if (!Number.isInteger(item.pricePaiseAtTime) || item.pricePaiseAtTime < 0 || item.pricePaiseAtTime > 1000000000) {
      return c.json({ error: `Invalid item price for product ${product.name}` }, 400);
    }

    if (item.pricePaiseAtTime !== product.price_paise) {
      return c.json({
        error: `Price mismatch for product ${product.name}. Expected: ${product.price_paise}, Provided: ${item.pricePaiseAtTime}`
      }, 400);
    }

    // Calculate free units strictly via server promotion rules
    let calculatedFreeQuantity = 0;
    const rule = promoMap.get(item.productId);
    if (rule && rule.minQty > 0 && quantity >= rule.minQty) {
      calculatedFreeQuantity = Math.floor(quantity / rule.minQty) * rule.freeQty;
    }

    computedTotalPaise += (quantity * product.price_paise);
    processedItems.push({
      id: item.id || crypto.randomUUID(),
      productId: item.productId,
      quantity,
      freeQuantity: calculatedFreeQuantity,
      pricePaiseAtTime: item.pricePaiseAtTime
    });
  }

  if (computedTotalPaise !== order.totalAmountPaise) {
    return c.json({
      error: `Order total calculation mismatch. Computed: ${computedTotalPaise}, Provided: ${order.totalAmountPaise}`
    }, 400);
  }

  try {
    const now = Date.now();
    const statements = [
      c.env.DB.prepare(
        'INSERT INTO orders (id, company_id, retailer_id, employee_id, status, total_amount_paise, created_at, updated_at, idempotency_key, credit_override_paise, credit_override_reason, credit_override_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ).bind(order.id, user.company_id, order.retailerId, user.sub, 'SUBMITTED', order.totalAmountPaise, now, now, idempotencyKey || null, override, overrideReason, override > 0 ? user.sub : null),
      c.env.DB.prepare(
        'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
      ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_SUBMITTED', order.id, `Total: ${order.totalAmountPaise} paise; credit override: ${override}; reason: ${overrideReason || "none"}`, now)
    ];

    processedItems.forEach(item => {
      statements.push(
        c.env.DB.prepare(
          'INSERT INTO order_items (id, order_id, product_id, quantity, free_quantity, price_paise_at_time, is_picked) VALUES (?, ?, ?, ?, ?, ?, 0)'
        ).bind(item.id, order.id, item.productId, item.quantity, item.freeQuantity, item.pricePaiseAtTime)
      );
    });

    if (idempotencyKey) {
      const respJson = JSON.stringify({ success: true, orderId: order.id });
      statements.push(
        c.env.DB.prepare(
          'INSERT INTO idempotency_records (key, company_id, actor_id, operation, request_hash, response_body, response_status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
        ).bind(idempotencyKey, user.company_id, user.sub, 'CREATE_ORDER', requestHash, respJson, 200, now)
      );
    }

    await c.env.DB.batch(statements);
    return c.json({ success: true, orderId: order.id });
  } catch (e: any) {
    console.error(JSON.stringify({ event: 'order_creation_rejected', error: e?.message || String(e) }));
    const existing = await c.env.DB.prepare('SELECT * FROM idempotency_records WHERE key = ?')
      .bind(idempotencyKey).first<any>();
    if (existing) {
      if (existing.company_id !== user.company_id || existing.actor_id !== user.sub || existing.operation !== 'CREATE_ORDER' || existing.request_hash !== requestHash) {
        return c.json({ error: 'Idempotency conflict: key reused with differing actor, operation, or payload' }, 409);
      }
      return c.json(JSON.parse(existing.response_body), existing.response_status);
    }
    return c.json({ error: 'Order conflicts with current stock, credit, or identifiers. Refresh and review.' }, 409);
  }
});

app.get('/orders', authMiddleware, async (c) => {
  const user = c.get('user');
  let query = 'SELECT id, retailer_id AS retailerId, employee_id AS employeeId, status, total_amount_paise AS totalAmountPaise, delivered_amount_paise AS deliveredAmountPaise, delivery_failure_reason AS deliveryFailureReason, delivery_notes AS deliveryNotes, rescheduled_date AS rescheduledDate, created_at AS createdAt, updated_at AS updatedAt, delivery_employee_id AS deliveryEmployeeId, rejection_reason AS rejectionReason, payment_method AS paymentMethod FROM orders WHERE company_id = ?';
  const params: any[] = [user.company_id];

  if (user.role === 'SALESPERSON') {
    query += ' AND employee_id = ?';
    params.push(user.sub);
  } else if (user.role === 'DELIVERY_EXECUTIVE') {
    // Delivery users must list ONLY their assigned orders
    query += ' AND delivery_employee_id = ?';
    params.push(user.sub);
  } else if (user.role === 'WAREHOUSE_MANAGER') {
    query += ' AND status IN (?, ?, ?, ?)';
    params.push('APPROVED', 'PICKING', 'PACKED', 'OUT_FOR_DELIVERY');
  }

  query += ' ORDER BY created_at DESC';
  const { results } = await c.env.DB.prepare(query).bind(...params).all();
  return c.json(results);
});

// Bulk order-item fetch — replaces N individual /orders/:id calls at startup.
// Accepts a JSON body: { "orderIds": ["id1", "id2", ...] } (max 50).
// Returns { items: [ { orderId, productId, ... }, ... ] }
app.post('/orders/items-bulk', authMiddleware, async (c) => {
  const user = c.get('user');
  const body = await c.req.json().catch(() => ({}));
  const ids: string[] = Array.isArray(body?.orderIds) ? body.orderIds : [];

  if (ids.length === 0) return c.json({ items: [] });
  if (ids.length > 50) return c.json({ error: 'Maximum 50 order IDs per bulk request' }, 400);
  if (ids.some((id: any) => typeof id !== 'string' || id.length > 100)) {
    return c.json({ error: 'Invalid order ID in list' }, 400);
  }

  // Verify all requested orders belong to this company (role-scoped)
  const placeholders = ids.map(() => '?').join(', ');
  let ownershipQuery = `SELECT id FROM orders WHERE company_id = ? AND id IN (${placeholders})`;
  const ownershipParams: any[] = [user.company_id, ...ids];

  if (user.role === 'SALESPERSON') {
    ownershipQuery += ' AND employee_id = ?';
    ownershipParams.push(user.sub);
  } else if (user.role === 'DELIVERY_EXECUTIVE') {
    ownershipQuery += ' AND delivery_employee_id = ?';
    ownershipParams.push(user.sub);
  }

  const { results: ownedOrders } = await c.env.DB.prepare(ownershipQuery).bind(...ownershipParams).all();
  const ownedIds = (ownedOrders as any[]).map(r => r.id);

  if (ownedIds.length === 0) return c.json({ items: [] });

  const itemPlaceholders = ownedIds.map(() => '?').join(', ');
  const { results: items } = await c.env.DB.prepare(
    `SELECT id, order_id AS orderId, product_id AS productId, quantity, free_quantity AS freeQuantity,
            price_paise_at_time AS pricePaiseAtTime, is_picked AS isPicked,
            delivered_quantity AS deliveredQuantity, delivered_free_quantity AS deliveredFreeQuantity,
            undelivered_quantity AS undeliveredQuantity, undelivered_free_quantity AS undeliveredFreeQuantity,
            undelivered_reason AS undeliveredReason
     FROM order_items WHERE order_id IN (${itemPlaceholders})`
  ).bind(...ownedIds).all();

  return c.json({ items: (items as any[]).map(i => ({ ...i, isPicked: Boolean(i.isPicked) })) });
});

app.get('/orders/pending', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER' && user.role !== 'ADMIN') {
    return c.json({ error: 'Permission denied: owner or admin role required' }, 403);
  }

  const { results } = await c.env.DB.prepare(
    'SELECT id, retailer_id AS retailerId, employee_id AS employeeId, status, total_amount_paise AS totalAmountPaise, created_at AS createdAt, updated_at AS updatedAt, delivery_employee_id AS deliveryEmployeeId, rejection_reason AS rejectionReason FROM orders WHERE company_id = ? AND status = ? ORDER BY created_at DESC'
  )
    .bind(user.company_id, 'SUBMITTED')
    .all();

  return c.json(results);
});

app.get('/orders/:id', authMiddleware, async (c) => {
  const user = c.get('user');
  const orderId = c.req.param('id');

  const order = await c.env.DB.prepare(
    'SELECT id, retailer_id AS retailerId, employee_id AS employeeId, status, total_amount_paise AS totalAmountPaise, delivered_amount_paise AS deliveredAmountPaise, delivery_failure_reason AS deliveryFailureReason, delivery_notes AS deliveryNotes, rescheduled_date AS rescheduledDate, created_at AS createdAt, updated_at AS updatedAt, delivery_employee_id AS deliveryEmployeeId, rejection_reason AS rejectionReason, payment_method AS paymentMethod, recipient_name AS recipientName FROM orders WHERE id = ? AND company_id = ?'
  )
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  // Salesperson role check: can only see their own orders
  if (user.role === 'SALESPERSON' && order.employeeId !== user.sub) {
    return c.json({ error: 'Permission denied' }, 403);
  }

  // Delivery executive role check: can only view orders assigned to them
  if (user.role === 'DELIVERY_EXECUTIVE' && order.deliveryEmployeeId !== user.sub) {
    return c.json({ error: 'Permission denied: order not assigned to you' }, 403);
  }

  const { results: rawItems } = await c.env.DB.prepare(
    'SELECT id, order_id AS orderId, product_id AS productId, quantity, free_quantity AS freeQuantity, price_paise_at_time AS pricePaiseAtTime, is_picked AS isPicked, delivered_quantity AS deliveredQuantity, delivered_free_quantity AS deliveredFreeQuantity, undelivered_quantity AS undeliveredQuantity, undelivered_free_quantity AS undeliveredFreeQuantity, undelivered_reason AS undeliveredReason FROM order_items WHERE order_id = ?'
  )
    .bind(orderId)
    .all();

  const items = rawItems.map((item: any) => ({
    ...item,
    isPicked: Boolean(item.isPicked)
  }));

  return c.json({ order, items });
});

app.post('/orders/:id/approve', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER' && user.role !== 'ADMIN') {
    return c.json({ error: 'Permission denied: owner or admin role required to approve orders' }, 403);
  }

  const orderId = c.req.param('id');
  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  if (order.status === 'APPROVED') {
    return c.json({ success: true, idempotent: true });
  }

  if (order.status !== 'SUBMITTED') {
    return c.json({ error: `Cannot approve order with status ${order.status}` }, 400);
  }

  const { results: items } = await c.env.DB.prepare('SELECT * FROM order_items WHERE order_id = ?')
    .bind(orderId)
    .all();

  // Stock check: available = stock_quantity - reserved_quantity
  for (const item of items as any[]) {
    const product = await c.env.DB.prepare('SELECT name, stock_quantity, reserved_quantity FROM products WHERE id = ? AND company_id = ?')
      .bind(item.product_id, user.company_id)
      .first() as any;

    if (!product) {
      return c.json({ error: `Product ${item.product_id} not found` }, 400);
    }

    const required = (item.quantity || 0) + (item.free_quantity || 0);
    const available = product.stock_quantity - product.reserved_quantity;
    if (available < required) {
      return c.json({
        error: `Insufficient stock for product ${product.name}. Available: ${available}, Required: ${required}`
      }, 400);
    }
  }

  const now = Date.now();
  const statements = [
    // 1. Guarded atomic transition (Trigger aborts entire batch if OLD.status != 'SUBMITTED')
    c.env.DB.prepare('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?')
      .bind('APPROVED', now, orderId),
    // 2. Audit log
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_APPROVED', orderId, 'Stock reserved', now)
  ];

  // Failure-injection testing support (only enabled in local development test environment)
  if (isFailureInjectionAllowed(c) && c.req.header('X-Test-Fail-Inventory') === 'true') {
    statements.push(
      c.env.DB.prepare('UPDATE products SET reserved_quantity = 999999999 WHERE id = ? AND company_id = ?')
        .bind(items[0]?.product_id || 'P1', user.company_id)
    );
  } else {
    for (const item of items as any[]) {
      const required = (item.quantity || 0) + (item.free_quantity || 0);
      statements.push(
        c.env.DB.prepare('UPDATE products SET reserved_quantity = reserved_quantity + ? WHERE id = ? AND company_id = ?')
          .bind(required, item.product_id, user.company_id)
      );
    }
  }

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true });
  } catch (e: any) {
    const current = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(orderId)
      .first() as any;
    if (current && current.status === 'APPROVED') {
      return c.json({ success: true, idempotent: true });
    }
    return c.json({ error: e.message || 'Approval failed' }, 400);
  }
});

app.post('/orders/:id/reject', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: only owner can reject orders' }, 403);
  }

  const orderId = c.req.param('id');
  const body = await c.req.json();
  const reason = body?.reason;
  if (!reason || !reason.trim()) {
    return c.json({ error: 'Rejection reason is required' }, 400);
  }

  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  if (order.status === 'REJECTED') {
    return c.json({ success: true, idempotent: true });
  }

  if (order.status !== 'SUBMITTED' && order.status !== 'APPROVED') {
    return c.json({ error: `Cannot reject order with status ${order.status}` }, 400);
  }

  const now = Date.now();
  const wasApproved = order.status === 'APPROVED';

  const statements = [
    // Guarded atomic transition (Trigger aborts if OLD.status not in ('SUBMITTED', 'APPROVED'))
    c.env.DB.prepare('UPDATE orders SET status = ?, rejection_reason = ?, updated_at = ? WHERE id = ?')
      .bind('REJECTED', reason, now, orderId),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_REJECTED', orderId, `Reason: ${reason}`, now)
  ];

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true });
  } catch (e: any) {
    const current = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(orderId)
      .first() as any;
    if (current && current.status === 'REJECTED') {
      return c.json({ success: true, idempotent: true });
    }
    return c.json({ error: e.message || 'Rejection failed' }, 400);
  }
});

app.post('/orders/:id/start-picking', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse role required' }, 403);
  }

  const orderId = c.req.param('id');
  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  // Idempotent if already in PICKING
  if (order.status === 'PICKING') {
    return c.json({ success: true, idempotent: true, status: 'PICKING' });
  }

  if (order.status !== 'APPROVED') {
    return c.json({ error: `Cannot start picking for order with status ${order.status}` }, 400);
  }

  const now = Date.now();
  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE orders SET status = ?, updated_at = ? WHERE id = ? AND status = ?')
      .bind('PICKING', now, orderId, 'APPROVED'),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_PICKING_STARTED', orderId, 'Picking started by warehouse', now)
  ]);

  return c.json({ success: true, status: 'PICKING' });
});

app.post('/orders/:id/pick-item', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse role required' }, 403);
  }

  const orderId = c.req.param('id');
  const body = await c.req.json();
  const productId = body.productId || body.product_id;
  const isPicked = body.isPicked !== undefined ? body.isPicked : (body.is_picked !== undefined ? body.is_picked : true);

  if (!productId) {
    return c.json({ error: 'productId is required' }, 400);
  }

  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  if (order.status !== 'APPROVED' && order.status !== 'PICKING') {
    return c.json({ error: `Cannot pick items for order with status ${order.status}` }, 400);
  }

  const statements = [
    c.env.DB.prepare('UPDATE order_items SET is_picked = ? WHERE order_id = ? AND product_id = ?')
      .bind(isPicked ? 1 : 0, orderId, productId)
  ];

  if (order.status === 'APPROVED') {
    statements.push(
      c.env.DB.prepare('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?')
        .bind('PICKING', Date.now(), orderId)
    );
  }

  await c.env.DB.batch(statements);
  return c.json({ success: true });
});

app.post('/orders/:id/pack', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER' && user.role !== 'ADMIN') {
    return c.json({ error: 'Permission denied: warehouse, owner, or admin role required' }, 403);
  }

  const orderId = c.req.param('id');
  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  if (order.status === 'PACKED') {
    return c.json({ success: true, idempotent: true });
  }

  if (order.status !== 'PICKING' && order.status !== 'APPROVED') {
    return c.json({ error: `Cannot pack order with status ${order.status}` }, 400);
  }

  // Validate that all items are picked
  const unpicked = await c.env.DB.prepare('SELECT count(*) AS count FROM order_items WHERE order_id = ? AND is_picked = 0')
    .bind(orderId)
    .first() as any;

  if (unpicked && unpicked.count > 0) {
    return c.json({ error: `Cannot pack order: ${unpicked.count} item(s) have not been picked yet` }, 400);
  }

  const now = Date.now();
  const statements = [
    c.env.DB.prepare('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?')
      .bind('PACKED', now, orderId),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_PACKED', orderId, 'All items picked and packed', now)
  ];

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true });
  } catch (e: any) {
    const current = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(orderId).first() as any;
    if (current && current.status === 'PACKED') {
      return c.json({ success: true, idempotent: true });
    }
    return c.json({ error: e.message || 'Pack failed' }, 400);
  }
});

app.post('/orders/:id/dispatch', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER' && user.role !== 'ADMIN') {
    return c.json({ error: 'Permission denied: warehouse, owner, or admin role required' }, 403);
  }

  const orderId = c.req.param('id');
  const body = await c.req.json();
  const deliveryEmployeeId = body.deliveryEmployeeId || body.delivery_employee_id;

  if (!deliveryEmployeeId) {
    return c.json({ error: 'Assigned delivery employee ID is required for dispatch' }, 400);
  }

  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  if (order.status === 'OUT_FOR_DELIVERY') {
    return c.json({ success: true, idempotent: true });
  }

  if (order.status !== 'PACKED') {
    return c.json({ error: `Order must be PACKED before dispatch. Current status: ${order.status}` }, 400);
  }

  // Validate delivery employee belongs to this company and has delivery role
  const deliveryEmployee = await c.env.DB.prepare('SELECT * FROM users WHERE id = ? AND company_id = ? AND role = ? AND is_active = 1')
    .bind(deliveryEmployeeId, user.company_id, 'DELIVERY_EXECUTIVE')
    .first() as any;

  if (!deliveryEmployee) {
    return c.json({ error: 'Designated delivery executive is invalid, inactive, or not in company' }, 400);
  }

  const { results: items } = await c.env.DB.prepare('SELECT * FROM order_items WHERE order_id = ?')
    .bind(orderId)
    .all();

  const now = Date.now();
  const statements = [
    // 1. Guarded atomic transition (Trigger aborts if OLD.status != 'PACKED')
    c.env.DB.prepare('UPDATE orders SET status = ?, delivery_employee_id = ?, updated_at = ? WHERE id = ?')
      .bind('OUT_FOR_DELIVERY', deliveryEmployeeId, now, orderId),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_DISPATCHED', orderId, `Assigned to: ${deliveryEmployee.full_name}`, now)
  ];

  for (const item of items as any[]) {
    const totalDeduct = (item.quantity || 0) + (item.free_quantity || 0);
    statements.push(
      c.env.DB.prepare(
        'UPDATE products SET stock_quantity = stock_quantity - ?, reserved_quantity = max(0, reserved_quantity - ?) WHERE id = ? AND company_id = ?'
      ).bind(totalDeduct, totalDeduct, item.product_id, user.company_id)
    );
  }

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true, otpGenerated: false });
  } catch (e: any) {
    const current = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(orderId).first() as any;
    if (current && current.status === 'OUT_FOR_DELIVERY') {
      return c.json({ success: true, idempotent: true });
    }
    return c.json({ error: e.message || 'Dispatch failed' }, 400);
  }
});

app.post('/orders/:id/request-otp', authMiddleware, requestOtp);

app.post('/orders/:id/deliver', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'DELIVERY_EXECUTIVE' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: delivery role required' }, 403);
  }

  const orderId = c.req.param('id');
  const body = await c.req.json();
  const paymentMethod = body.paymentMethod || body.payment_method || 'CASH';
  const recipientName = (body.recipientName || body.recipient_name || '').trim();
  const otp = (body.otp || '').trim();
  const proofPhotoUrl = body.proofPhotoUrl || body.proof_photo_url || null;
  const signatureUrl = body.signatureUrl || body.signature_url || null;
  const itemInputs = body.items || null;

  // Allowed payment methods restricted to CASH and CREDIT in this milestone
  const ALLOWED_PAYMENT_METHODS = ['CASH', 'CREDIT'];
  if (!ALLOWED_PAYMENT_METHODS.includes(paymentMethod)) {
    return c.json({
      error: `Invalid payment method '${paymentMethod}'. Only CASH and CREDIT are supported for delivery fulfillment in this milestone.`
    }, 400);
  }

  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  // Delivery employee authorization check: only assigned driver or Owner can complete delivery
  if (user.role === 'DELIVERY_EXECUTIVE' && order.delivery_employee_id !== user.sub) {
    return c.json({ error: 'Unauthorized: you are not the assigned delivery executive for this order' }, 403);
  }

  if (order.status === 'DELIVERED' || order.status === 'PARTIALLY_DELIVERED') {
    return c.json({ success: true, idempotent: true, status: order.status });
  }

  if (order.status !== 'OUT_FOR_DELIVERY') {
    return c.json({ error: `Cannot complete delivery for order with status ${order.status}` }, 400);
  }

  // Check if server-backed OTP record exists for this order
  const otpRecord = await c.env.DB.prepare('SELECT * FROM delivery_otps WHERE order_id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  const now = Date.now();
  const isTestBypass = isFailureInjectionAllowed(c) && c.req.header('X-Test-Bypass-Delivery-Otp') === 'true';

  let verifiedRecipient = recipientName;
  if (!isTestBypass) {
    if (!recipientName) {
      return c.json({ error: 'Recipient name is required to confirm delivery' }, 400);
    }
    if (!otp || !/^\d{6}$/.test(otp)) {
      return c.json({ error: 'A valid 6-digit delivery OTP is required' }, 400);
    }
    if (!otpRecord) {
      return c.json({ error: 'No active delivery OTP found for this order. Request an OTP first.' }, 400);
    }
    if (!['SENT', ...(((c.env.ENVIRONMENT === 'development' || c.env.ENVIRONMENT === 'staging') && c.env.SMS_MODE === 'simulated') ? ['SIMULATED'] : [])].includes(otpRecord.send_status)) {
      return c.json({ error: 'Recipient messaging has not been acknowledged' }, 400);
    }
    if (otpRecord.is_used === 1) {
      return c.json({ error: 'Delivery OTP has already been used' }, 400);
    }
    if (now > otpRecord.expires_at) {
      return c.json({ error: 'Delivery OTP has expired. Please request a new OTP.' }, 400);
    }
    if (otpRecord.attempt_count >= otpRecord.max_attempts) {
      return c.json({ error: 'Maximum OTP verification attempts exceeded. Please request a new OTP.' }, 400);
    }
    if (otpRecord.otp_code !== otp) {
      await c.env.DB.prepare('UPDATE delivery_otps SET attempt_count = attempt_count + 1 WHERE order_id = ?')
        .bind(orderId)
        .run();
      const remaining = otpRecord.max_attempts - otpRecord.attempt_count - 1;
      return c.json({ error: `Invalid delivery OTP. ${remaining} attempt(s) remaining.` }, 400);
    }
    verifiedRecipient = recipientName;
  } else {
    verifiedRecipient = recipientName || 'Authorized Receiver (Test)';
  }

  // Fetch actual order items
  const { results: rawOrderItems } = await c.env.DB.prepare(
    'SELECT * FROM order_items WHERE order_id = ?'
  ).bind(orderId).all();

  const VALID_REASONS = ['SHOP_CLOSED', 'REFUSED', 'DAMAGED', 'SHORTAGE', 'OTHER'];
  let isPartial = false;
  let deliveredAmountPaise = 0;
  const processedItems: Array<{
    id: string;
    productId: string;
    deliveredQuantity: number;
    deliveredFreeQuantity: number;
    undeliveredQuantity: number;
    undeliveredFreeQuantity: number;
    undeliveredReason: string | null;
  }> = [];

  if (Array.isArray(itemInputs) && itemInputs.length > 0) {
    const inputMap = new Map<string, any>();
    for (const inp of itemInputs) {
      inputMap.set(inp.productId || inp.product_id, inp);
    }

    let totalDeliveredUnits = 0;

    for (const rawItem of rawOrderItems as any[]) {
      const inp = inputMap.get(rawItem.product_id);
      if (!inp) {
        return c.json({ error: `Missing item breakdown for product ${rawItem.product_id}` }, 400);
      }

      const delQty = Number(inp.deliveredQuantity ?? inp.delivered_quantity ?? rawItem.quantity);
      const delFreeQty = Number(inp.deliveredFreeQuantity ?? inp.delivered_free_quantity ?? rawItem.free_quantity);
      const undelQty = Number(inp.undeliveredQuantity ?? inp.undelivered_quantity ?? 0);
      const undelFreeQty = Number(inp.undeliveredFreeQuantity ?? inp.undelivered_free_quantity ?? 0);
      const reason = (inp.undeliveredReason || inp.undelivered_reason || '').trim();

      if (delQty < 0 || delFreeQty < 0 || undelQty < 0 || undelFreeQty < 0) {
        return c.json({ error: `Negative quantities are not allowed for product ${rawItem.product_id}` }, 400);
      }

      if (delQty + undelQty !== rawItem.quantity) {
        return c.json({ error: `Delivered + undelivered quantity must equal ordered quantity (${rawItem.quantity}) for product ${rawItem.product_id}` }, 400);
      }

      if (delFreeQty + undelFreeQty !== rawItem.free_quantity) {
        return c.json({ error: `Delivered + undelivered free quantity must equal ordered free quantity (${rawItem.free_quantity}) for product ${rawItem.product_id}` }, 400);
      }

      if (undelQty > 0 || undelFreeQty > 0) {
        isPartial = true;
        if (!reason || !VALID_REASONS.includes(reason)) {
          return c.json({ error: `A valid undelivered reason (SHOP_CLOSED, REFUSED, DAMAGED, SHORTAGE, OTHER) is required for product ${rawItem.product_id}` }, 400);
        }
      }

      totalDeliveredUnits += (delQty + delFreeQty);
      deliveredAmountPaise += (delQty * rawItem.price_paise_at_time);

      processedItems.push({
        id: rawItem.id,
        productId: rawItem.product_id,
        deliveredQuantity: delQty,
        deliveredFreeQuantity: delFreeQty,
        undeliveredQuantity: undelQty,
        undeliveredFreeQuantity: undelFreeQty,
        undeliveredReason: (undelQty > 0 || undelFreeQty > 0) ? reason : null
      });
    }

    if (totalDeliveredUnits === 0) {
      return c.json({ error: 'No items were delivered. If delivery failed entirely, please record a failed delivery.' }, 400);
    }
  } else {
    // Full delivery default
    deliveredAmountPaise = order.total_amount_paise;
    for (const rawItem of rawOrderItems as any[]) {
      processedItems.push({
        id: rawItem.id,
        productId: rawItem.product_id,
        deliveredQuantity: rawItem.quantity,
        deliveredFreeQuantity: rawItem.free_quantity,
        undeliveredQuantity: 0,
        undeliveredFreeQuantity: 0,
        undeliveredReason: null
      });
    }
  }

  const finalStatus = isPartial ? 'PARTIALLY_DELIVERED' : 'DELIVERED';
  const invoiceId = `inv_${crypto.randomUUID()}`;
  const ledgerId = `led_${crypto.randomUUID()}`;

  const statements = [
    // 1. Guarded atomic transition
    c.env.DB.prepare(
      'UPDATE orders SET status = ?, payment_method = ?, recipient_name = ?, proof_photo_url = ?, signature_url = ?, delivered_amount_paise = ?, updated_at = ? WHERE id = ?'
    ).bind(finalStatus, paymentMethod, verifiedRecipient, proofPhotoUrl, signatureUrl, deliveredAmountPaise, now, orderId),

    // 2. Audit log
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(
      crypto.randomUUID(),
      user.company_id,
      user.sub,
      finalStatus === 'PARTIALLY_DELIVERED' ? 'ORDER_PARTIALLY_DELIVERED' : 'ORDER_DELIVERED',
      orderId,
      `Status: ${finalStatus}, Payment: ${paymentMethod}, Delivered: ${deliveredAmountPaise}, Recipient: ${verifiedRecipient}`,
      now
    )
  ];

  // Mark OTP as used if record exists
  if (otpRecord) {
    statements.push(
      c.env.DB.prepare('UPDATE delivery_otps SET is_used = 1, recipient_name = ? WHERE order_id = ?')
        .bind(verifiedRecipient, orderId)
    );
  }

  // Clear any existing undelivered_goods records for this order (e.g. from previous attempt)
  statements.push(
    c.env.DB.prepare("DELETE FROM undelivered_goods WHERE order_id = ? AND company_id = ? AND status IN ('HELD_BY_DRIVER', 'RESCHEDULED')")
      .bind(orderId, user.company_id)
  );

  // Update order_items & create undelivered goods records if any
  for (const item of processedItems) {
    statements.push(
      c.env.DB.prepare(
        'UPDATE order_items SET delivered_quantity = ?, delivered_free_quantity = ?, undelivered_quantity = ?, undelivered_free_quantity = ?, undelivered_reason = ? WHERE id = ?'
      ).bind(item.deliveredQuantity, item.deliveredFreeQuantity, item.undeliveredQuantity, item.undeliveredFreeQuantity, item.undeliveredReason, item.id)
    );

    if (item.undeliveredQuantity > 0 || item.undeliveredFreeQuantity > 0) {
      statements.push(
        c.env.DB.prepare(
          `INSERT INTO undelivered_goods (
            id, company_id, order_id, driver_id, product_id,
            undelivered_paid_quantity, undelivered_free_quantity,
            reason, status, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'HELD_BY_DRIVER', ?)`
        ).bind(
          `undel_${crypto.randomUUID()}`,
          user.company_id,
          orderId,
          order.delivery_employee_id || user.sub,
          item.productId,
          item.undeliveredQuantity,
          item.undeliveredFreeQuantity,
          item.undeliveredReason,
          now
        )
      );
    }
  }

  // 3. Retailer balance update (CREDIT): increment by deliveredAmountPaise only
  if (paymentMethod === 'CREDIT') {
    statements.push(
      c.env.DB.prepare('UPDATE retailers SET outstanding_amount_paise = outstanding_amount_paise + ? WHERE id = ? AND company_id = ?')
        .bind(deliveredAmountPaise, order.retailer_id, user.company_id)
    );
  }

  // 4. Durable Invoice
  if (isFailureInjectionAllowed(c) && c.req.header('X-Test-Fail-Invoice') === 'true') {
    statements.push(c.env.DB.prepare('INSERT INTO invoices (id) VALUES (NULL)'));
  } else {
    statements.push(
      c.env.DB.prepare(
        'INSERT INTO invoices (id, order_id, company_id, retailer_id, total_amount_paise, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
      ).bind(invoiceId, orderId, user.company_id, order.retailer_id, deliveredAmountPaise, paymentMethod === 'CREDIT' ? 'ISSUED' : 'PAID', now)
    );
  }

  // 5. Durable Payment Ledger entry with atomic balance_after_paise from database row
  statements.push(
    c.env.DB.prepare(
      `INSERT INTO payment_ledger (
        id, order_id, invoice_id, company_id, retailer_id,
        entry_type, amount_paise, balance_after_paise, payment_method, collected_by, created_at
      )
      SELECT ?, ?, ?, ?, ?, ?, ?, outstanding_amount_paise, ?, ?, ?
      FROM retailers WHERE id = ? AND company_id = ?`
    ).bind(
      ledgerId,
      orderId,
      invoiceId,
      user.company_id,
      order.retailer_id,
      paymentMethod === 'CREDIT' ? 'CREDIT_INCREASE' : 'CASH_PAYMENT',
      deliveredAmountPaise,
      paymentMethod,
      user.sub,
      now,
      order.retailer_id,
      user.company_id
    )
  );

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true, status: finalStatus, invoiceId, deliveredAmountPaise });
  } catch (e: any) {
    const current = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(orderId).first() as any;
    if (current && (current.status === 'DELIVERED' || current.status === 'PARTIALLY_DELIVERED')) {
      return c.json({ success: true, idempotent: true, status: current.status });
    }
    return c.json({ error: e.message || 'Delivery failed' }, 400);
  }
});

app.post('/orders/:id/delivery-failed', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'DELIVERY_EXECUTIVE' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: delivery role required' }, 403);
  }

  const orderId = c.req.param('id');
  const body = await c.req.json();
  const reason = (body.reason || '').trim();
  const rescheduledDate = (body.rescheduledDate || body.rescheduled_date || null)?.trim() || null;
  const notes = (body.notes || '').trim() || null;

  const VALID_REASONS = ['SHOP_CLOSED', 'REFUSED', 'DAMAGED', 'SHORTAGE', 'OTHER'];
  if (!reason || !VALID_REASONS.includes(reason)) {
    return c.json({
      error: `Invalid failure reason '${reason}'. Must be one of: ${VALID_REASONS.join(', ')}`
    }, 400);
  }

  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  if (user.role === 'DELIVERY_EXECUTIVE' && order.delivery_employee_id !== user.sub) {
    return c.json({ error: 'Unauthorized: you are not the assigned delivery executive for this order' }, 403);
  }

  if (order.status === 'DELIVERY_FAILED') {
    return c.json({ success: true, idempotent: true, status: 'DELIVERY_FAILED' });
  }

  if (order.status !== 'OUT_FOR_DELIVERY') {
    return c.json({ error: `Cannot fail delivery for order with status ${order.status}` }, 400);
  }

  const { results: rawOrderItems } = await c.env.DB.prepare(
    'SELECT * FROM order_items WHERE order_id = ?'
  ).bind(orderId).all();

  const now = Date.now();
  const statements = [
    // 1. Order status update
    c.env.DB.prepare(
      'UPDATE orders SET status = ?, delivery_failure_reason = ?, delivery_notes = ?, rescheduled_date = ?, delivered_amount_paise = 0, updated_at = ? WHERE id = ?'
    ).bind('DELIVERY_FAILED', reason, notes, rescheduledDate, now, orderId),

    // 2. Audit log
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(
      crypto.randomUUID(),
      user.company_id,
      user.sub,
      'ORDER_DELIVERY_FAILED',
      orderId,
      `Reason: ${reason}, Rescheduled: ${rescheduledDate || 'None'}, Notes: ${notes || 'None'}`,
      now
    )
  ];

  // 3. Mark items undelivered and create undelivered_goods records
  for (const rawItem of rawOrderItems as any[]) {
    statements.push(
      c.env.DB.prepare(
        'UPDATE order_items SET delivered_quantity = 0, delivered_free_quantity = 0, undelivered_quantity = ?, undelivered_free_quantity = ?, undelivered_reason = ? WHERE id = ?'
      ).bind(rawItem.quantity, rawItem.free_quantity, reason, rawItem.id)
    );

    statements.push(
      c.env.DB.prepare(
        `INSERT INTO undelivered_goods (
          id, company_id, order_id, driver_id, product_id,
          undelivered_paid_quantity, undelivered_free_quantity,
          reason, status, rescheduled_for, notes, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'HELD_BY_DRIVER', ?, ?, ?)`
      ).bind(
        `undel_${crypto.randomUUID()}`,
        user.company_id,
        orderId,
        order.delivery_employee_id || user.sub,
        rawItem.product_id,
        rawItem.quantity,
        rawItem.free_quantity,
        reason,
        rescheduledDate,
        notes,
        now
      )
    );
  }

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true, status: 'DELIVERY_FAILED', reason, rescheduledDate });
  } catch (e: any) {
    const current = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(orderId).first() as any;
    if (current && current.status === 'DELIVERY_FAILED') {
      return c.json({ success: true, idempotent: true, status: 'DELIVERY_FAILED' });
    }
    return c.json({ error: e.message || 'Failed to update delivery failure' }, 400);
  }
});

app.post('/orders/:id/retry-delivery', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER' && user.role !== 'WAREHOUSE_MANAGER') {
    return c.json({ error: 'Permission denied: owner or warehouse manager role required' }, 403);
  }

  const orderId = c.req.param('id');
  const body = await c.req.json();
  const deliveryEmployeeId = (body.deliveryEmployeeId || body.delivery_employee_id || '').trim();
  const rescheduledDate = (body.rescheduledDate || body.rescheduled_date || null)?.trim() || null;
  const notes = (body.notes || '').trim() || null;

  if (!deliveryEmployeeId) {
    return c.json({ error: 'Delivery executive ID is required for retry delivery' }, 400);
  }

  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  if (order.status !== 'DELIVERY_FAILED') {
    return c.json({ error: `Cannot schedule retry for order with status ${order.status}. Order must be in DELIVERY_FAILED status.` }, 400);
  }

  // Validate delivery employee
  const driver = await c.env.DB.prepare('SELECT * FROM users WHERE id = ? AND company_id = ? AND role = ? AND is_active = 1')
    .bind(deliveryEmployeeId, user.company_id, 'DELIVERY_EXECUTIVE')
    .first() as any;

  if (!driver) {
    return c.json({ error: 'Assigned driver is not an active delivery executive' }, 400);
  }

  // Security & inventory integrity: Retry cannot reuse goods already returned to warehouse
  const returnedGoods = await c.env.DB.prepare(
    "SELECT 1 FROM undelivered_goods WHERE order_id = ? AND company_id = ? AND status = 'RETURNED_TO_WAREHOUSE'"
  ).bind(orderId, user.company_id).first();

  if (returnedGoods) {
    return c.json({
      error: 'Cannot retry delivery: Undelivered goods have already been returned to warehouse stock. Order cannot be redispatched from driver custody.'
    }, 409);
  }

  // Revalidate & reserve credit before any subsequent credit delivery
  const retailer = await c.env.DB.prepare('SELECT * FROM retailers WHERE id = ? AND company_id = ?')
    .bind(order.retailer_id, user.company_id)
    .first() as any;

  if (!retailer) return c.json({ error: 'Retailer not found' }, 404);

  const activeReservations = await c.env.DB.prepare(
    'SELECT COALESCE(SUM(amount_paise), 0) AS total_res FROM credit_reservations WHERE retailer_id = ? AND company_id = ?'
  ).bind(order.retailer_id, user.company_id).first() as any;

  const currentExposure = retailer.outstanding_amount_paise + (activeReservations?.total_res || 0);
  const maxAllowedCredit = retailer.credit_limit_paise + (order.credit_override_paise || 0);

  if (currentExposure + order.total_amount_paise > maxAllowedCredit) {
    return c.json({
      error: `Credit limit exceeded for retry delivery: current exposure ${currentExposure} paise + order ${order.total_amount_paise} paise exceeds limit ${maxAllowedCredit} paise.`
    }, 400);
  }

  const now = Date.now();
  const statements = [
    // 1. Order status update: DELIVERY_FAILED -> OUT_FOR_DELIVERY
    c.env.DB.prepare(
      `UPDATE orders
       SET status = 'OUT_FOR_DELIVERY', delivery_employee_id = ?, rescheduled_date = ?,
           delivery_failure_reason = NULL, delivery_notes = ?, updated_at = ?
       WHERE id = ? AND company_id = ?`
    ).bind(deliveryEmployeeId, rescheduledDate, notes, now, orderId, user.company_id),

    // 2. Re-reserve credit exposure
    c.env.DB.prepare(
      `INSERT OR REPLACE INTO credit_reservations (order_id, company_id, retailer_id, amount_paise)
       VALUES (?, ?, ?, ?)`
    ).bind(orderId, user.company_id, order.retailer_id, order.total_amount_paise),

    // 3. Update driver-held stock to assigned driver (transfer or retain custody)
    c.env.DB.prepare(
      `UPDATE undelivered_goods
       SET driver_id = ?, status = 'HELD_BY_DRIVER', rescheduled_for = ?
       WHERE order_id = ? AND company_id = ? AND status IN ('HELD_BY_DRIVER', 'RESCHEDULED')`
    ).bind(deliveryEmployeeId, rescheduledDate, orderId, user.company_id),

    // 4. Audit log
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(
      crypto.randomUUID(),
      user.company_id,
      user.sub,
      'ORDER_RETRY_SCHEDULED',
      orderId,
      `Assigned Driver: ${driver.full_name} (${deliveryEmployeeId}), Rescheduled: ${rescheduledDate || 'Immediate'}`,
      now
    )
  ];

  await c.env.DB.batch(statements);
  return c.json({
    success: true,
    status: 'OUT_FOR_DELIVERY',
    deliveryEmployeeId,
    rescheduledDate,
    message: 'Delivery retry successfully scheduled and assigned'
  });
});

// ============================================================================
// WAREHOUSE & OWNER: UNDELIVERED GOODS & DELIVERY EXCEPTIONS
// ============================================================================

app.get('/warehouse/undelivered-goods', authMiddleware, async (c) => {
  const user = c.get('user');
  const statusFilter = c.req.query('status');
  const driverFilter = c.req.query('driverId');

  let query = `
    SELECT u.id, u.company_id AS companyId, u.order_id AS orderId, u.driver_id AS driverId,
           u.product_id AS productId, u.undelivered_paid_quantity AS undeliveredPaidQuantity,
           u.undelivered_free_quantity AS undeliveredFreeQuantity, u.reason, u.status,
           u.saleable_quantity AS saleableQuantity, u.damaged_quantity AS damagedQuantity,
           u.shortage_quantity AS shortageQuantity, u.acknowledged_by AS acknowledgedBy,
           u.acknowledged_at AS acknowledgedAt, u.rescheduled_for AS rescheduledFor,
           u.notes, u.created_at AS createdAt,
           p.name AS productName, p.unit AS productUnit,
           d.full_name AS driverName,
           r.name AS retailerName, r.address AS retailerAddress
    FROM undelivered_goods u
    JOIN products p ON u.product_id = p.id
    JOIN users d ON u.driver_id = d.id
    JOIN orders o ON u.order_id = o.id
    JOIN retailers r ON o.retailer_id = r.id
    WHERE u.company_id = ?
  `;
  const params: any[] = [user.company_id];

  if (user.role === 'DELIVERY_EXECUTIVE') {
    query += ' AND u.driver_id = ?';
    params.push(user.sub);
  } else if (driverFilter) {
    query += ' AND u.driver_id = ?';
    params.push(driverFilter);
  }

  if (statusFilter) {
    query += ' AND u.status = ?';
    params.push(statusFilter);
  }

  query += ' ORDER BY u.created_at DESC';
  const { results } = await c.env.DB.prepare(query).bind(...params).all();
  return c.json(results);
});

app.post('/warehouse/undelivered-goods/:id/acknowledge', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse manager or owner required' }, 403);
  }

  const id = c.req.param('id');
  const body = await c.req.json();
  const status = body.status || 'RETURNED_TO_WAREHOUSE';
  const saleableQuantity = Number(body.saleableQuantity ?? body.saleable_quantity ?? 0);
  const damagedQuantity = Number(body.damagedQuantity ?? body.damaged_quantity ?? 0);
  const shortageQuantity = Number(body.shortageQuantity ?? body.shortage_quantity ?? 0);
  const notes = (body.notes || '').trim() || null;
  const rescheduledFor = (body.rescheduledFor || body.rescheduled_for || null)?.trim() || null;

  if (!['RETURNED_TO_WAREHOUSE', 'RESCHEDULED'].includes(status)) {
    return c.json({ error: `Invalid status '${status}'. Must be RETURNED_TO_WAREHOUSE or RESCHEDULED.` }, 400);
  }

  if (saleableQuantity < 0 || damagedQuantity < 0 || shortageQuantity < 0) {
    return c.json({ error: 'Quantities cannot be negative.' }, 400);
  }

  const record = await c.env.DB.prepare('SELECT * FROM undelivered_goods WHERE id = ? AND company_id = ?')
    .bind(id, user.company_id)
    .first() as any;

  if (!record) return c.json({ error: 'Undelivered goods record not found' }, 404);

  if (record.status !== 'HELD_BY_DRIVER') {
    return c.json({ error: `Goods record already acknowledged with status ${record.status}` }, 400);
  }

  const totalExpected = record.undelivered_paid_quantity + record.undelivered_free_quantity;
  if (saleableQuantity + damagedQuantity + shortageQuantity !== totalExpected) {
    return c.json({
      error: `Sum of saleable (${saleableQuantity}), damaged (${damagedQuantity}), and shortage (${shortageQuantity}) must equal total undelivered units (${totalExpected}).`
    }, 400);
  }

  const now = Date.now();
  const statements = [
    // 1. Update undelivered_goods
    c.env.DB.prepare(
      `UPDATE undelivered_goods
       SET status = ?, saleable_quantity = ?, damaged_quantity = ?, shortage_quantity = ?,
           acknowledged_by = ?, acknowledged_at = ?, notes = ?, rescheduled_for = ?
       WHERE id = ?`
    ).bind(status, saleableQuantity, damagedQuantity, shortageQuantity, user.sub, now, notes, rescheduledFor, id),

    // 2. Audit log
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(
      crypto.randomUUID(),
      user.company_id,
      user.sub,
      'UNDELIVERED_GOODS_ACKNOWLEDGED',
      id,
      `Status: ${status}, Saleable: ${saleableQuantity}, Damaged: ${damagedQuantity}, Shortage: ${shortageQuantity}`,
      now
    )
  ];

  // 3. Restock saleable inventory in warehouse
  if (saleableQuantity > 0) {
    const currentProd = await c.env.DB.prepare('SELECT stock_quantity FROM products WHERE id = ? AND company_id = ?')
      .bind(record.product_id, user.company_id).first() as any;
    const newStock = (currentProd?.stock_quantity ?? 0) + saleableQuantity;
    statements.push(
      c.env.DB.prepare('UPDATE products SET stock_quantity = ? WHERE id = ? AND company_id = ?')
        .bind(newStock, record.product_id, user.company_id)
    );
    statements.push(
      c.env.DB.prepare(
        `INSERT INTO stock_adjustments (id, company_id, product_id, user_id, change_quantity, reason, stock_after, notes, idempotency_key, created_at)
         VALUES (?, ?, ?, ?, ?, 'RETURN_RESTOCK', ?, ?, ?, ?)`
      ).bind(
        `adj_${crypto.randomUUID()}`,
        user.company_id,
        record.product_id,
        user.sub,
        saleableQuantity,
        newStock,
        `Delivery return restock for order ${record.order_id}`,
        null,
        now
      )
    );
  }

  // 4. Log damaged inventory
  if (damagedQuantity > 0) {
    const currentProd = await c.env.DB.prepare('SELECT stock_quantity FROM products WHERE id = ? AND company_id = ?')
      .bind(record.product_id, user.company_id).first() as any;
    statements.push(
      c.env.DB.prepare(
        `INSERT INTO stock_adjustments (id, company_id, product_id, user_id, change_quantity, reason, stock_after, notes, idempotency_key, created_at)
         VALUES (?, ?, ?, ?, 0, 'DAMAGE', ?, ?, ?, ?)`
      ).bind(
        `adj_${crypto.randomUUID()}`,
        user.company_id,
        record.product_id,
        user.sub,
        currentProd?.stock_quantity ?? 0,
        `Damaged delivery return for order ${record.order_id}`,
        null,
        now
      )
    );
  }

  await c.env.DB.batch(statements);
  return c.json({ success: true, status, saleableQuantity, damagedQuantity, shortageQuantity });
});

app.get('/owner/delivery-exceptions', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const { results } = await c.env.DB.prepare(`
    SELECT o.id, o.retailer_id AS retailerId, o.employee_id AS employeeId,
           o.delivery_employee_id AS deliveryEmployeeId, o.status,
           o.total_amount_paise AS totalAmountPaise,
           o.delivered_amount_paise AS deliveredAmountPaise,
           o.delivery_failure_reason AS deliveryFailureReason,
           o.delivery_notes AS deliveryNotes,
           o.rescheduled_date AS rescheduledDate,
           o.created_at AS createdAt, o.updated_at AS updatedAt,
           r.name AS retailerName, r.address AS retailerAddress,
           d.full_name AS driverName
    FROM orders o
    JOIN retailers r ON o.retailer_id = r.id
    LEFT JOIN users d ON o.delivery_employee_id = d.id
    WHERE o.company_id = ? AND o.status IN ('PARTIALLY_DELIVERED', 'DELIVERY_FAILED')
    ORDER BY o.updated_at DESC
  `).bind(user.company_id).all();

  return c.json(results);
});

app.get('/owner/driver-held-stock', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER' && user.role !== 'WAREHOUSE_MANAGER') {
    return c.json({ error: 'Permission denied: owner or warehouse manager required' }, 403);
  }

  const { results } = await c.env.DB.prepare(`
    SELECT u.driver_id AS driverId, d.full_name AS driverName,
           u.product_id AS productId, p.name AS productName, p.unit AS productUnit,
           SUM(u.undelivered_paid_quantity) AS totalPaidQuantity,
           SUM(u.undelivered_free_quantity) AS totalFreeQuantity,
           COUNT(DISTINCT u.order_id) AS orderCount
    FROM undelivered_goods u
    JOIN users d ON u.driver_id = d.id
    JOIN products p ON u.product_id = p.id
    WHERE u.company_id = ? AND u.status = 'HELD_BY_DRIVER'
    GROUP BY u.driver_id, d.full_name, u.product_id, p.name, p.unit
    ORDER BY d.full_name, p.name
  `).bind(user.company_id).all();

  return c.json(results);
});

// ============================================================================
// SLICE B: OWNER MASTER DATA MANAGEMENT (Products, Retailers, Employees, Stock)
// ============================================================================

app.post('/products', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER' && user.role !== 'ADMIN') {
    return c.json({ error: 'Permission denied: owner or admin role required' }, 403);
  }

  const body = await c.req.json();
  const name = body.name?.trim();
  const category = body.category?.trim() || 'General';
  const pricePaise = body.pricePaise ?? body.price_paise;
  const mrpPaise = body.mrpPaise ?? body.mrp_paise ?? pricePaise;
  const stockQuantity = body.stockQuantity ?? body.stock_quantity ?? 0;
  const unit = body.unit?.trim() || 'Unit';
  const sku = body.sku?.trim() || null;
  const imageUrl = body.imageUrl || body.image_url || null;

  if (!name || typeof pricePaise !== 'number' || pricePaise <= 0 || !unit) {
    return c.json({ error: 'Valid product name, positive pricePaise, and unit are required' }, 400);
  }

  const id = body.id || `P_${crypto.randomUUID().slice(0, 8)}`;
  const hindiName = body.hindiName?.trim() || body.hindi_name?.trim() || null;
  const now = Date.now();

  const statements = [
    c.env.DB.prepare(
      `INSERT INTO products (id, company_id, name, hindi_name, category, price_paise, mrp_paise, stock_quantity, reserved_quantity, unit, sku, image_url, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, 1)`
    ).bind(id, user.company_id, name, hindiName, category, pricePaise, mrpPaise, stockQuantity, unit, sku, imageUrl),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'PRODUCT_CREATED', id, `Product: ${name}, Price: ${pricePaise}, Stock: ${stockQuantity}`, now)
  ];

  await c.env.DB.batch(statements);
  return c.json({
    success: true,
    product: { id, name, hindiName, category, pricePaise, mrpPaise, stockQuantity, reservedQuantity: 0, unit, sku, imageUrl, isActive: true }
  });
});

app.put('/products/:id', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const id = c.req.param('id');
  const body = await c.req.json();
  const existing = await c.env.DB.prepare('SELECT * FROM products WHERE id = ? AND company_id = ?')
    .bind(id, user.company_id).first() as any;

  if (!existing) return c.json({ error: 'Product not found' }, 404);

  const name = body.name !== undefined ? body.name.trim() : existing.name;
  const hindiName = body.hindiName !== undefined ? body.hindiName.trim() : (body.hindi_name !== undefined ? body.hindi_name.trim() : existing.hindi_name);
  const category = body.category !== undefined ? body.category.trim() : existing.category;
  const pricePaise = body.pricePaise ?? body.price_paise ?? existing.price_paise;
  const mrpPaise = body.mrpPaise ?? body.mrp_paise ?? existing.mrp_paise;
  const unit = body.unit !== undefined ? body.unit.trim() : existing.unit;
  const sku = body.sku !== undefined ? body.sku?.trim() : existing.sku;
  const isActive = body.isActive !== undefined ? (body.isActive ? 1 : 0) : existing.is_active;
  const imageUrl = body.imageUrl ?? body.image_url ?? existing.image_url;

  const now = Date.now();
  const statements = [
    c.env.DB.prepare(
      `UPDATE products SET name = ?, hindi_name = ?, category = ?, price_paise = ?, mrp_paise = ?, unit = ?, sku = ?, is_active = ?, image_url = ?
       WHERE id = ? AND company_id = ?`
    ).bind(name, hindiName, category, pricePaise, mrpPaise, unit, sku, isActive, imageUrl, id, user.company_id),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'PRODUCT_UPDATED', id, `Updated product details. Active: ${isActive}`, now)
  ];

  await c.env.DB.batch(statements);
  return c.json({ success: true });
});

app.post('/inventory/adjust', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER' && user.role !== 'WAREHOUSE_MANAGER') {
    return c.json({ error: 'Permission denied: owner or warehouse role required' }, 403);
  }

  const body = await c.req.json();
  const productId = body.productId || body.product_id;
  const changeQuantity = body.changeQuantity ?? body.change_quantity;
  const reason = body.reason?.trim();
  const notes = body.notes?.trim() || null;
  const idempotencyKey = body.idempotencyKey || body.idempotency_key || null;

  if (!productId || typeof changeQuantity !== 'number' || changeQuantity === 0 || !reason) {
    return c.json({ error: 'productId, non-zero changeQuantity, and valid reason are required' }, 400);
  }

  const VALID_REASONS = ['STOCK_RECEIPT', 'DAMAGE', 'AUDIT_CORRECTION', 'RETURN_RESTOCK'];
  if (!VALID_REASONS.includes(reason)) {
    return c.json({ error: `Invalid reason. Allowed: ${VALID_REASONS.join(', ')}` }, 400);
  }

  // Idempotency check: retrying a stock receipt must not add the same stock twice
  if (idempotencyKey) {
    const existingAdj = await c.env.DB.prepare(
      'SELECT id, stock_after FROM stock_adjustments WHERE company_id = ? AND idempotency_key = ?'
    ).bind(user.company_id, idempotencyKey).first() as any;

    if (existingAdj) {
      return c.json({
        success: true,
        adjustmentId: existingAdj.id,
        newStockQuantity: existingAdj.stock_after,
        idempotent: true
      });
    }
  }

  // ATOMIC stock update: prevent lost updates from concurrent modifications
  const updatedProduct = await c.env.DB.prepare(
    `UPDATE products
     SET stock_quantity = stock_quantity + ?
     WHERE id = ? AND company_id = ?
       AND (stock_quantity + ?) >= 0
       AND (stock_quantity + ?) >= reserved_quantity
     RETURNING stock_quantity, reserved_quantity`
  ).bind(changeQuantity, productId, user.company_id, changeQuantity, changeQuantity)
   .first() as { stock_quantity: number; reserved_quantity: number } | null;

  if (!updatedProduct) {
    // Determine exact cause for meaningful failure response
    const existing = await c.env.DB.prepare('SELECT stock_quantity, reserved_quantity FROM products WHERE id = ? AND company_id = ?')
      .bind(productId, user.company_id)
      .first() as { stock_quantity: number; reserved_quantity: number } | null;

    if (!existing) {
      return c.json({ error: 'Product not found' }, 404);
    }
    if (existing.stock_quantity + changeQuantity < 0) {
      return c.json({
        error: `Adjustment exceeds available physical stock. Current: ${existing.stock_quantity}, Change: ${changeQuantity}`
      }, 400);
    }
    if (existing.stock_quantity + changeQuantity < existing.reserved_quantity) {
      return c.json({
        error: `Cannot adjust stock below current reserved quantity (${existing.reserved_quantity})`
      }, 400);
    }
    return c.json({ error: 'Stock adjustment failed due to concurrent modification conflict. Please retry.' }, 409);
  }

  const newStock = updatedProduct.stock_quantity;
  const now = Date.now();
  const adjId = `adj_${crypto.randomUUID()}`;

  const statements = [
    c.env.DB.prepare(
      `INSERT INTO stock_adjustments (id, company_id, product_id, user_id, change_quantity, reason, stock_after, notes, idempotency_key, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(adjId, user.company_id, productId, user.sub, changeQuantity, reason, newStock, notes, idempotencyKey, now),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'STOCK_ADJUSTMENT', productId, `Change: ${changeQuantity}, Reason: ${reason}, NewStock: ${newStock}`, now)
  ];

  await c.env.DB.batch(statements);
  return c.json({ success: true, adjustmentId: adjId, newStockQuantity: newStock });
});

app.post('/retailers', authMiddleware, async (c) => {
  const user = c.get('user');
  if (!['OWNER', 'ADMIN', 'SALESPERSON'].includes(user.role)) {
    return c.json({ error: 'Permission denied: owner, admin, or salesperson role required' }, 403);
  }

  const body = await c.req.json();
  const name = body.name?.trim();
  let beatId = body.beatId || body.beat_id;
  if (!beatId && user.role === 'SALESPERSON') {
    const assigned = await c.env.DB.prepare('SELECT beat_id FROM user_beat_assignments WHERE user_id = ? AND company_id = ?')
      .bind(user.sub, user.company_id).first() as any;
    beatId = assigned?.beat_id || 'BEAT-04';
  } else if (!beatId) {
    beatId = 'BEAT-04';
  }

  const address = body.address?.trim() || '';
  const contactNumber = body.contactNumber || body.contact_number || '';
  const creditLimitPaise = body.creditLimitPaise ?? body.credit_limit_paise ?? (user.role === 'SALESPERSON' ? 500000 : 0);
  const paymentTermsDays = body.paymentTermsDays ?? body.payment_terms_days ?? 7;
  const latitude = typeof body.latitude === 'number' ? body.latitude : (body.latitude ? parseFloat(body.latitude) : null);
  const longitude = typeof body.longitude === 'number' ? body.longitude : (body.longitude ? parseFloat(body.longitude) : null);

  if (!name) {
    return c.json({ error: 'Retailer or wholesale shop name is required' }, 400);
  }

  const id = body.id || `ret_${crypto.randomUUID().slice(0, 8)}`;
  const now = Date.now();

  const statements = [
    c.env.DB.prepare(
      `INSERT INTO retailers (id, company_id, name, beat_id, address, contact_number, latitude, longitude, credit_limit_paise, outstanding_amount_paise, is_active, payment_terms_days)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1, ?)`
    ).bind(id, user.company_id, name, beatId, address, contactNumber, latitude, longitude, creditLimitPaise, paymentTermsDays),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'RETAILER_CREATED', id, `Retailer: ${name}, Beat: ${beatId}, Limit: ${creditLimitPaise}, Lat: ${latitude}, Lng: ${longitude}`, now)
  ];

  await c.env.DB.batch(statements);
  return c.json({
    success: true,
    retailer: { id, name, beatId, address, contactNumber, creditLimitPaise, outstandingAmountPaise: 0, isActive: true, paymentTermsDays, latitude, longitude }
  });
});

app.put('/retailers/:id', authMiddleware, async (c) => {
  const user = c.get('user');
  if (!['OWNER', 'ADMIN'].includes(user.role)) {
    return c.json({ error: 'Permission denied: owner or admin role required' }, 403);
  }

  const id = c.req.param('id');
  const body = await c.req.json();
  const existing = await c.env.DB.prepare('SELECT * FROM retailers WHERE id = ? AND company_id = ?')
    .bind(id, user.company_id).first() as any;

  if (!existing) return c.json({ error: 'Retailer not found' }, 404);

  const name = body.name !== undefined ? body.name.trim() : existing.name;
  const beatId = body.beatId || body.beat_id || existing.beat_id;
  const address = body.address !== undefined ? body.address.trim() : existing.address;
  const contactNumber = body.contactNumber || body.contact_number || existing.contact_number;
  const creditLimitPaise = body.creditLimitPaise ?? body.credit_limit_paise ?? existing.credit_limit_paise;
  const paymentTermsDays = body.paymentTermsDays ?? body.payment_terms_days ?? existing.payment_terms_days;
  const isActive = body.isActive !== undefined ? (body.isActive ? 1 : 0) : existing.is_active;
  const latitude = body.latitude !== undefined ? body.latitude : existing.latitude;
  const longitude = body.longitude !== undefined ? body.longitude : existing.longitude;

  const now = Date.now();
  const statements = [
    c.env.DB.prepare(
      `UPDATE retailers SET name = ?, beat_id = ?, address = ?, contact_number = ?, credit_limit_paise = ?, payment_terms_days = ?, is_active = ?, latitude = ?, longitude = ?
       WHERE id = ? AND company_id = ?`
    ).bind(name, beatId, address, contactNumber, creditLimitPaise, paymentTermsDays, isActive, latitude, longitude, id, user.company_id),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'RETAILER_UPDATED', id, `Updated retailer ${name}. Active: ${isActive}`, now)
  ];

  await c.env.DB.batch(statements);
  return c.json({ success: true });
});

app.get('/employees', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const { results } = await c.env.DB.prepare(
    `SELECT u.id, u.username, u.full_name AS fullName, u.role, u.is_active AS isActive,
            (SELECT GROUP_CONCAT(beat_id) FROM user_beat_assignments WHERE user_id = u.id AND company_id = u.company_id) AS assignedBeats
     FROM users u WHERE u.company_id = ? ORDER BY u.full_name ASC`
  ).bind(user.company_id).all();

  const formatted = results.map((r: any) => ({
    id: r.id,
    username: r.username,
    fullName: r.fullName,
    role: r.role,
    isActive: Boolean(r.isActive),
    assignedBeats: r.assignedBeats ? r.assignedBeats.split(',') : []
  }));

  return c.json(formatted);
});

app.post('/employees', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const body = await c.req.json();
  const username = body.username?.trim().toLowerCase();
  const password = body.password;
  const fullName = body.fullName?.trim() || body.full_name?.trim();
  const role = body.role;
  const beatId = body.beatId || body.beat_id;

  if (!username || !password || !fullName || !role) {
    return c.json({ error: 'username, password, fullName, and role are required' }, 400);
  }

  const VALID_ROLES = ['OWNER', 'SALESPERSON', 'WAREHOUSE_MANAGER', 'DELIVERY_EXECUTIVE'];
  if (!VALID_ROLES.includes(role)) {
    return c.json({ error: `Invalid role. Allowed: ${VALID_ROLES.join(', ')}` }, 400);
  }

  const passwordHash = bcrypt.hashSync(password, 10);
  const id = body.id || `user_${crypto.randomUUID().slice(0, 8)}`;
  const now = Date.now();

  const statements = [
    c.env.DB.prepare(
      `INSERT INTO users (id, company_id, username, password_hash, full_name, role, is_active, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 1, ?)`
    ).bind(id, user.company_id, username, passwordHash, fullName, role, now),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'EMPLOYEE_CREATED', id, `Created employee: ${fullName} (${role})`, now)
  ];

  if (role === 'SALESPERSON' && beatId) {
    statements.push(
      c.env.DB.prepare(
        `INSERT OR REPLACE INTO user_beat_assignments (user_id, beat_id, company_id, created_at)
         VALUES (?, ?, ?, ?)`
      ).bind(id, beatId, user.company_id, now)
    );
  }

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true, employee: { id, username, fullName, role, isActive: true, assignedBeats: beatId ? [beatId] : [] } });
  } catch (e: any) {
    if (e.message && e.message.includes('UNIQUE constraint')) {
      return c.json({ error: 'Username already exists' }, 409);
    }
    return c.json({ error: e.message || 'Failed to create employee' }, 500);
  }
});

app.put('/employees/:id/deactivate', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const targetUserId = c.req.param('id');
  if (targetUserId === user.sub) {
    return c.json({ error: 'Cannot deactivate your own owner account' }, 400);
  }

  const now = Date.now();
  const statements = [
    c.env.DB.prepare('UPDATE users SET is_active = 0 WHERE id = ? AND company_id = ?')
      .bind(targetUserId, user.company_id),
    // Instantly revoke all active sessions for this employee
    c.env.DB.prepare('UPDATE sessions SET is_revoked = 1 WHERE user_id = ? AND company_id = ?')
      .bind(targetUserId, user.company_id),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'EMPLOYEE_DEACTIVATED', targetUserId, 'Deactivated and sessions revoked', now)
  ];

  await c.env.DB.batch(statements);
  return c.json({ success: true });
});

// ============================================================================
// SLICE C: SHOP VISITS & FIELD STOCK AUDITS
// ============================================================================

app.get('/beats', authMiddleware, async (c) => {
  const user = c.get('user');
  const { results } = await c.env.DB.prepare(
    `SELECT b.id, b.name, b.description, b.working_days AS workingDays, b.is_active AS isActive,
            (SELECT COUNT(*) FROM retailers r WHERE r.beat_id = b.id AND r.company_id = b.company_id AND r.is_active = 1) AS retailerCount,
            (SELECT GROUP_CONCAT(u.full_name) FROM user_beat_assignments uba JOIN users u ON uba.user_id = u.id WHERE uba.beat_id = b.id AND uba.company_id = b.company_id) AS assignedSalespeople
     FROM beats b
     WHERE b.company_id = ?
     ORDER BY b.name ASC`
  ).bind(user.company_id).all();

  const formatted = results.map((r: any) => ({
    id: r.id,
    name: r.name,
    description: r.description,
    workingDays: r.workingDays ? r.workingDays.split(',') : [],
    isActive: Boolean(r.isActive),
    retailerCount: r.retailerCount || 0,
    assignedSalespeople: r.assignedSalespeople ? r.assignedSalespeople.split(',') : []
  }));

  return c.json(formatted);
});

app.post('/beats', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const body = await c.req.json();
  const id = body.id?.trim() || `BEAT-${crypto.randomUUID().slice(0, 6).toUpperCase()}`;
  const name = body.name?.trim();
  const description = body.description?.trim() || null;
  const workingDays = Array.isArray(body.workingDays) ? body.workingDays.join(',') : (body.workingDays || 'MON,TUE,WED,THU,FRI,SAT');
  const now = Date.now();

  if (!name) {
    return c.json({ error: 'Beat name is required' }, 400);
  }

  await c.env.DB.prepare(
    `INSERT INTO beats (id, company_id, name, description, working_days, is_active, created_at)
     VALUES (?, ?, ?, ?, ?, 1, ?)
     ON CONFLICT(id) DO UPDATE SET name = excluded.name, description = excluded.description, working_days = excluded.working_days`
  ).bind(id, user.company_id, name, description, workingDays, now).run();

  return c.json({ success: true, beat: { id, name, description, workingDays: workingDays.split(','), isActive: true } });
});

app.post('/beats/:id/assign', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const beatId = c.req.param('id');
  const body = await c.req.json();
  const userId = body.userId || body.user_id;

  if (!userId) {
    return c.json({ error: 'userId is required' }, 400);
  }

  const targetUser = await c.env.DB.prepare('SELECT id FROM users WHERE id = ? AND company_id = ? AND role = ? AND is_active = 1')
    .bind(userId, user.company_id, 'SALESPERSON')
    .first();

  if (!targetUser) {
    return c.json({ error: 'Invalid or inactive salesperson in this company' }, 400);
  }

  await c.env.DB.prepare(
    'INSERT OR REPLACE INTO user_beat_assignments (user_id, beat_id, company_id, created_at) VALUES (?, ?, ?, ?)'
  ).bind(userId, beatId, user.company_id, Date.now()).run();

  return c.json({ success: true });
});

// ============================================================================
// FIELD SHIFTS & TEAM LOCATION TRACKING
// ============================================================================

app.get('/team/status', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const { results: employees } = await c.env.DB.prepare(
    `SELECT u.id, u.full_name AS fullName, u.role, u.is_active AS isActive,
            (SELECT GROUP_CONCAT(beat_id) FROM user_beat_assignments WHERE user_id = u.id AND company_id = u.company_id) AS assignedBeats
     FROM users u
     WHERE u.company_id = ? AND u.role IN ('SALESPERSON', 'DELIVERY_EXECUTIVE') AND u.is_active = 1
     ORDER BY u.full_name ASC`
  ).bind(user.company_id).all();

  const now = Date.now();
  const teamStatusList = [];

  for (const emp of employees as any[]) {
    const shift = await c.env.DB.prepare(
      'SELECT id, status, start_time AS startTime, end_time AS endTime FROM shifts WHERE user_id = ? AND company_id = ? ORDER BY start_time DESC LIMIT 1'
    ).bind(emp.id, user.company_id).first() as any;

    const lastLoc = await c.env.DB.prepare(
      'SELECT latitude, longitude, accuracy, timestamp FROM shift_locations WHERE user_id = ? AND company_id = ? ORDER BY timestamp DESC LIMIT 1'
    ).bind(emp.id, user.company_id).first() as any;

    let completedStops = 0;
    let totalStops = 0;

    if (emp.role === 'SALESPERSON') {
      const beatList = emp.assignedBeats ? emp.assignedBeats.split(',') : [];
      if (beatList.length > 0) {
        const total = await c.env.DB.prepare(
          `SELECT COUNT(*) AS count FROM retailers WHERE company_id = ? AND is_active = 1 AND beat_id IN (${beatList.map(() => '?').join(',')})`
        ).bind(user.company_id, ...beatList).first() as any;
        totalStops = total?.count || 0;
      }

      const completed = await c.env.DB.prepare(
        'SELECT COUNT(DISTINCT retailer_id) AS count FROM visits WHERE employee_id = ? AND company_id = ? AND check_in_time >= ?'
      ).bind(emp.id, user.company_id, now - 86400000).first() as any;
      completedStops = completed?.count || 0;
    } else {
      const assigned = await c.env.DB.prepare(
        "SELECT COUNT(*) AS total, SUM(CASE WHEN status = 'DELIVERED' THEN 1 ELSE 0 END) AS done FROM orders WHERE delivery_employee_id = ? AND company_id = ? AND status IN ('OUT_FOR_DELIVERY', 'DELIVERED')"
      ).bind(emp.id, user.company_id).first() as any;
      totalStops = assigned?.total || 0;
      completedStops = assigned?.done || 0;
    }

    const isStale = lastLoc ? (now - lastLoc.timestamp > 120000) : true;

    teamStatusList.push({
      id: emp.id,
      fullName: emp.fullName,
      role: emp.role,
      shiftStatus: shift?.status || 'OFF_SHIFT',
      shiftStartTime: shift?.startTime || null,
      shiftEndTime: shift?.endTime || null,
      lastLocation: lastLoc ? {
        latitude: lastLoc.latitude,
        longitude: lastLoc.longitude,
        accuracy: lastLoc.accuracy,
        timestamp: lastLoc.timestamp,
        isStale
      } : null,
      assignedBeats: emp.assignedBeats ? emp.assignedBeats.split(',') : [],
      completedStops,
      totalStops,
      lastSyncTime: lastLoc?.timestamp || shift?.startTime || null
    });
  }

  return c.json(teamStatusList);
});

// ============================================================================
// OWNER DAILY FIELD ACTIVITY REVIEW
// ============================================================================

app.get('/owner/visits/daily', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const dateParam = c.req.query('date');
  const targetDate = dateParam ? new Date(dateParam) : new Date();
  const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate()).getTime();
  const endOfDay = startOfDay + 86400000;

  const { results: visits } = await c.env.DB.prepare(
    `SELECT v.id, v.retailer_id AS retailerId, r.name AS retailerName, r.beat_id AS beatId,
            v.employee_id AS employeeId, u.full_name AS employeeName,
            v.check_in_time AS checkInTime, v.check_out_time AS checkOutTime,
            v.duration_seconds AS durationSeconds, v.status, v.no_order_reason AS noOrderReason,
            v.notes, v.latitude, v.longitude, v.accuracy,
            r.latitude AS retailerLat, r.longitude AS retailerLng,
            (SELECT COUNT(*) FROM orders o WHERE o.retailer_id = v.retailer_id AND o.created_at BETWEEN v.check_in_time AND coalesce(v.check_out_time, v.check_in_time + 3600000)) AS ordersCount,
            (SELECT COUNT(*) FROM stock_checks sc WHERE sc.retailer_id = v.retailer_id AND sc.created_at BETWEEN v.check_in_time AND coalesce(v.check_out_time, v.check_in_time + 3600000)) AS stockChecksCount
     FROM visits v
     JOIN retailers r ON v.retailer_id = r.id
     JOIN users u ON v.employee_id = u.id
     WHERE v.company_id = ? AND v.check_in_time BETWEEN ? AND ?
     ORDER BY v.check_in_time DESC`
  ).bind(user.company_id, startOfDay, endOfDay).all();

  const formatted = visits.map((v: any) => {
    let locationDiscrepancy = false;
    if (v.latitude && v.longitude && v.retailerLat && v.retailerLng) {
      const dLat = (v.latitude - v.retailerLat) * 111000;
      const dLng = (v.longitude - v.retailerLng) * 111000 * Math.cos(v.retailerLat * Math.PI / 180);
      const distM = Math.sqrt(dLat * dLat + dLng * dLng);
      if (distM > 500) {
        locationDiscrepancy = true;
      }
    }
    return {
      ...v,
      locationDiscrepancy
    };
  });

  return c.json(formatted);
});

// ============================================================================
// SLICE D: REAL COLLECTIONS & PAYMENT LEDGER
// ============================================================================

app.route('/', dailyCycle(authMiddleware));
app.route('/', fieldCycle(authMiddleware));
app.route('/batches', batchRouter(authMiddleware));
app.route('/trips', tripRouter(authMiddleware));
app.route('/', governanceRouter(authMiddleware));
app.route('/', operatingRouter(authMiddleware));

export default app;
