import { Hono } from 'hono';
import { sign, verify } from '@tsndr/cloudflare-worker-jwt';
import bcrypt from 'bcryptjs';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  JWT_ACCESS_EXPIRY: string;
  JWT_REFRESH_EXPIRY: string;
  ENVIRONMENT?: string;
  ENABLE_TEST_FAILURE_INJECTION?: string;
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
  if (payload.exp && payload.exp < nowSec) {
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
  if (!username || !password) {
    return c.json({ error: 'Missing username or password' }, 400);
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

  const isPasswordValid = await verifyPassword(password, user.password_hash);
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
  if (!refresh_token) return c.json({ error: 'Missing refresh token' }, 400);

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

  const updateResult = await c.env.DB.prepare(
    'UPDATE sessions SET refresh_token_hash = ?, last_active_at = ?, expires_at = ? WHERE id = ? AND refresh_token_hash = ? AND is_revoked = 0'
  )
    .bind(newRefreshTokenHash, nowSec, nowSec + refreshExpirySeconds, session.id, refreshTokenHash)
    .run();

  if (!updateResult.meta || updateResult.meta.changes === 0) {
    return c.json({ error: 'Concurrent refresh conflict or session revoked' }, 401);
  }

  // Record old token hash in revoked_refresh_tokens
  await c.env.DB.prepare(
    'INSERT OR REPLACE INTO revoked_refresh_tokens (token_hash, session_id, user_id, revoked_at) VALUES (?, ?, ?, ?)'
  )
    .bind(refreshTokenHash, session.id, session.user_id, nowSec)
    .run();

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
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse or owner role required' }, 403);
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
  const idempotencyKey = body.idempotencyKey || body.idempotency_key || null;

  if (!order || !order.id || !order.retailerId || !items.length) {
    return c.json({ error: 'Invalid order structure or empty items' }, 400);
  }

  // Validate bounded integers
  if (!Number.isInteger(order.totalAmountPaise) || order.totalAmountPaise <= 0 || order.totalAmountPaise > 1000000000) {
    return c.json({ error: 'Invalid total amount: must be positive integer bounded to 1,000,000,000 paise' }, 400);
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

  // Retailer credit limit validation
  const newOutstanding = (retailer.outstanding_amount_paise || 0) + (order.totalAmountPaise || 0);
  if (newOutstanding > retailer.credit_limit_paise) {
    return c.json({
      error: `Credit limit exceeded. Current outstanding: ${retailer.outstanding_amount_paise}, order: ${order.totalAmountPaise}, limit: ${retailer.credit_limit_paise}`
    }, 400);
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
        'INSERT INTO orders (id, company_id, retailer_id, employee_id, status, total_amount_paise, created_at, updated_at, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ).bind(order.id, user.company_id, order.retailerId, user.sub, 'SUBMITTED', order.totalAmountPaise, now, now, idempotencyKey || null),
      c.env.DB.prepare(
        'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
      ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_SUBMITTED', order.id, `Total: ${order.totalAmountPaise} paise`, now)
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
    console.error('Order creation error:', e);
    if (e.message && e.message.includes('UNIQUE constraint failed')) {
      const existing = await c.env.DB.prepare('SELECT id FROM orders WHERE idempotency_key = ? AND company_id = ?')
        .bind(idempotencyKey || '', user.company_id)
        .first() as any;
      return c.json({ success: true, orderId: existing?.id, idempotent: true });
    }
    return c.json({ error: e.message }, 500);
  }
});

app.get('/orders', authMiddleware, async (c) => {
  const user = c.get('user');
  let query = 'SELECT id, retailer_id AS retailerId, employee_id AS employeeId, status, total_amount_paise AS totalAmountPaise, created_at AS createdAt, updated_at AS updatedAt, delivery_employee_id AS deliveryEmployeeId, rejection_reason AS rejectionReason, payment_method AS paymentMethod FROM orders WHERE company_id = ?';
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

app.get('/orders/pending', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: only owner can view pending approvals' }, 403);
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
    'SELECT id, retailer_id AS retailerId, employee_id AS employeeId, status, total_amount_paise AS totalAmountPaise, created_at AS createdAt, updated_at AS updatedAt, delivery_employee_id AS deliveryEmployeeId, rejection_reason AS rejectionReason, payment_method AS paymentMethod FROM orders WHERE id = ? AND company_id = ?'
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
    'SELECT id, order_id AS orderId, product_id AS productId, quantity, free_quantity AS freeQuantity, price_paise_at_time AS pricePaiseAtTime, is_picked AS isPicked FROM order_items WHERE order_id = ?'
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
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: only owner can approve orders' }, 403);
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

  // If order was previously APPROVED, release reserved stock in the same atomic batch
  if (wasApproved) {
    const { results: items } = await c.env.DB.prepare('SELECT * FROM order_items WHERE order_id = ?')
      .bind(orderId)
      .all();
    for (const item of items as any[]) {
      const releaseQty = (item.quantity || 0) + (item.free_quantity || 0);
      statements.push(
        c.env.DB.prepare('UPDATE products SET reserved_quantity = max(0, reserved_quantity - ?) WHERE id = ? AND company_id = ?')
          .bind(releaseQty, item.product_id, user.company_id)
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
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse role required' }, 403);
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
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse role required' }, 403);
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

  // Generate server-backed 6-digit delivery OTP for recipient verification
  const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = now + 86400000; // 24-hour validity
  statements.push(
    c.env.DB.prepare(
      `INSERT OR REPLACE INTO delivery_otps (
        order_id, company_id, otp_code, recipient_name, expires_at, attempt_count, max_attempts, is_used, created_at
      ) VALUES (?, ?, ?, NULL, ?, 0, 5, 0, ?)`
    ).bind(orderId, user.company_id, otpCode, expiresAt, now)
  );

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
    return c.json({ success: true, otpGenerated: true });
  } catch (e: any) {
    const current = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(orderId).first() as any;
    if (current && current.status === 'OUT_FOR_DELIVERY') {
      return c.json({ success: true, idempotent: true });
    }
    return c.json({ error: e.message || 'Dispatch failed' }, 400);
  }
});

app.post('/orders/:id/request-otp', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'DELIVERY_EXECUTIVE' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: delivery or owner role required' }, 403);
  }

  const orderId = c.req.param('id');
  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  if (user.role === 'DELIVERY_EXECUTIVE' && order.delivery_employee_id !== user.sub) {
    return c.json({ error: 'Unauthorized: order not assigned to you' }, 403);
  }

  if (order.status !== 'OUT_FOR_DELIVERY') {
    return c.json({ error: `Cannot request delivery OTP for order with status ${order.status}` }, 400);
  }

  const now = Date.now();
  let existing = await c.env.DB.prepare('SELECT * FROM delivery_otps WHERE order_id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  let activeOtp = existing?.otp_code;
  let expiresAt = existing?.expires_at;

  // If missing, expired, max attempts reached, or previously used: generate fresh OTP
  if (!existing || now > existing.expires_at || existing.attempt_count >= existing.max_attempts || existing.is_used === 1) {
    activeOtp = Math.floor(100000 + Math.random() * 900000).toString();
    expiresAt = now + 86400000;
    await c.env.DB.prepare(
      `INSERT OR REPLACE INTO delivery_otps (
        order_id, company_id, otp_code, recipient_name, expires_at, attempt_count, max_attempts, is_used, created_at
      ) VALUES (?, ?, ?, NULL, ?, 0, 5, 0, ?)`
    ).bind(orderId, user.company_id, activeOtp, expiresAt, now).run();
  }

  const retailer = await c.env.DB.prepare('SELECT name, contact_number FROM retailers WHERE id = ?')
    .bind(order.retailer_id)
    .first() as any;

  const contact = retailer?.contact_number || '';
  const maskedContact = contact.length >= 4
    ? '*'.repeat(Math.max(0, contact.length - 4)) + contact.slice(-4)
    : 'Registered mobile';

  const responseBody: any = {
    success: true,
    message: `Delivery OTP sent via SMS to ${retailer?.name || 'Retailer'} (${maskedContact})`,
    expiresAt
  };

  // Only expose debugOtp to automated test runner when test failure injection is enabled in development
  if (isFailureInjectionAllowed(c) && c.req.header('X-Test-Runner') === 'true') {
    responseBody.debugOtp = activeOtp;
  }

  return c.json(responseBody);
});

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

  if (order.status === 'DELIVERED') {
    return c.json({ success: true, idempotent: true });
  }

  if (order.status !== 'OUT_FOR_DELIVERY') {
    return c.json({ error: `Cannot complete delivery for order with status ${order.status}` }, 400);
  }

  // Delivery employee authorization check: only assigned driver or Owner can complete delivery
  if (user.role === 'DELIVERY_EXECUTIVE' && order.delivery_employee_id !== user.sub) {
    return c.json({ error: 'Unauthorized: you are not the assigned delivery executive for this order' }, 403);
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

  const invoiceId = `inv_${crypto.randomUUID()}`;
  const ledgerId = `led_${crypto.randomUUID()}`;

  const statements = [
    // 1. Guarded atomic transition (Trigger aborts if OLD.status != 'OUT_FOR_DELIVERY')
    c.env.DB.prepare(
      'UPDATE orders SET status = ?, payment_method = ?, recipient_name = ?, proof_photo_url = ?, signature_url = ?, updated_at = ? WHERE id = ?'
    ).bind('DELIVERED', paymentMethod, verifiedRecipient, proofPhotoUrl, signatureUrl, now, orderId),

    // 2. Audit log
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_DELIVERED', orderId, `Payment: ${paymentMethod}, Amount: ${order.total_amount_paise}, Recipient: ${verifiedRecipient}`, now)
  ];

  // Mark OTP as used if record exists
  if (otpRecord) {
    statements.push(
      c.env.DB.prepare('UPDATE delivery_otps SET is_used = 1, recipient_name = ? WHERE order_id = ?')
        .bind(verifiedRecipient, orderId)
    );
  }

  // 3. Retailer balance update: ATOMIC increment directly in database (no application-calculated overwrite)
  if (paymentMethod === 'CREDIT') {
    statements.push(
      c.env.DB.prepare('UPDATE retailers SET outstanding_amount_paise = outstanding_amount_paise + ? WHERE id = ? AND company_id = ?')
        .bind(order.total_amount_paise, order.retailer_id, user.company_id)
    );
  }

  // 4. Durable Invoice
  if (c.req.header('X-Test-Fail-Invoice') === 'true') {
    // Failure injection test: cause deliberate DB error in batch
    statements.push(
      c.env.DB.prepare('INSERT INTO invoices (id) VALUES (NULL)')
    );
  } else {
    statements.push(
      c.env.DB.prepare(
        'INSERT INTO invoices (id, order_id, company_id, retailer_id, total_amount_paise, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
      ).bind(invoiceId, orderId, user.company_id, order.retailer_id, order.total_amount_paise, paymentMethod === 'CREDIT' ? 'ISSUED' : 'PAID', now)
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
      order.total_amount_paise,
      paymentMethod,
      user.sub,
      now,
      order.retailer_id,
      user.company_id
    )
  );

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true, invoiceId });
  } catch (e: any) {
    const current = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ?')
      .bind(orderId).first() as any;
    if (current && current.status === 'DELIVERED') {
      return c.json({ success: true, idempotent: true });
    }
    return c.json({ error: e.message || 'Delivery failed' }, 400);
  }
});

// ============================================================================
// SLICE B: OWNER MASTER DATA MANAGEMENT (Products, Retailers, Employees, Stock)
// ============================================================================

app.post('/products', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
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
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const body = await c.req.json();
  const name = body.name?.trim();
  const beatId = body.beatId || body.beat_id;
  const address = body.address?.trim() || '';
  const contactNumber = body.contactNumber || body.contact_number || '';
  const creditLimitPaise = body.creditLimitPaise ?? body.credit_limit_paise ?? 0;
  const paymentTermsDays = body.paymentTermsDays ?? body.payment_terms_days ?? 7;
  const latitude = body.latitude ?? null;
  const longitude = body.longitude ?? null;

  if (!name || !beatId || !contactNumber || typeof creditLimitPaise !== 'number') {
    return c.json({ error: 'name, beatId, contactNumber, and numeric creditLimitPaise are required' }, 400);
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
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'RETAILER_CREATED', id, `Retailer: ${name}, Beat: ${beatId}, Limit: ${creditLimitPaise}`, now)
  ];

  await c.env.DB.batch(statements);
  return c.json({
    success: true,
    retailer: { id, name, beatId, address, contactNumber, creditLimitPaise, outstandingAmountPaise: 0, isActive: true, paymentTermsDays }
  });
});

app.put('/retailers/:id', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
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

app.post('/visits', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'SALESPERSON' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: salesperson or owner role required' }, 403);
  }

  const body = await c.req.json();
  const id = body.id || `vis_${crypto.randomUUID()}`;
  const retailerId = body.retailerId || body.retailer_id;
  const checkInTime = body.checkInTime || body.check_in_time;
  const checkOutTime = body.checkOutTime || body.check_out_time || null;
  const latitude = body.latitude ?? null;
  const longitude = body.longitude ?? null;
  const accuracy = body.accuracy ?? null;
  const durationSeconds = body.durationSeconds ?? body.duration_seconds ?? 0;
  const status = body.status || 'COMPLETED';
  const noOrderReason = body.noOrderReason || body.no_order_reason || null;
  const notes = body.notes?.trim() || null;
  const idempotencyKey = body.idempotencyKey || body.idempotency_key || null;

  if (!retailerId || !checkInTime) {
    return c.json({ error: 'retailerId and checkInTime are required' }, 400);
  }

  // Tenant isolation & retailer verification
  const retailer = await c.env.DB.prepare('SELECT * FROM retailers WHERE id = ? AND company_id = ?')
    .bind(retailerId, user.company_id)
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

    // Prevent second active visit until current visit is resolved
    if (status === 'ACTIVE') {
      const activeVisit = await c.env.DB.prepare(
        "SELECT v.id, r.name AS retailerName FROM visits v JOIN retailers r ON v.retailer_id = r.id WHERE v.employee_id = ? AND v.company_id = ? AND v.status = 'ACTIVE' AND v.id != ?"
      ).bind(user.sub, user.company_id, id).first() as any;

      if (activeVisit) {
        return c.json({
          error: `Active visit already in progress at '${activeVisit.retailerName}'. Please check out before starting a new visit.`
        }, 400);
      }
    }
  }

  const now = Date.now();
  try {
    await c.env.DB.prepare(
      `INSERT INTO visits (id, company_id, retailer_id, employee_id, check_in_time, check_out_time, latitude, longitude, accuracy, duration_seconds, status, no_order_reason, notes, idempotency_key, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      id, user.company_id, retailerId, user.sub, checkInTime, checkOutTime,
      latitude, longitude, accuracy, durationSeconds, status, noOrderReason, notes, idempotencyKey, now
    ).run();

    return c.json({ success: true, visitId: id });
  } catch (e: any) {
    if (e.message && e.message.includes('UNIQUE constraint')) {
      return c.json({ success: true, visitId: id, idempotent: true });
    }
    return c.json({ error: e.message || 'Failed to record shop visit' }, 500);
  }
});

app.get('/visits', authMiddleware, async (c) => {
  const user = c.get('user');
  let query = 'SELECT id, retailer_id AS retailerId, employee_id AS employeeId, check_in_time AS checkInTime, check_out_time AS checkOutTime, latitude, longitude, accuracy, duration_seconds AS durationSeconds, status, no_order_reason AS noOrderReason, notes, created_at AS createdAt FROM visits WHERE company_id = ?';
  const params: any[] = [user.company_id];

  if (user.role === 'SALESPERSON') {
    query += ' AND employee_id = ?';
    params.push(user.sub);
  }

  query += ' ORDER BY check_in_time DESC LIMIT 100';
  const { results } = await c.env.DB.prepare(query).bind(...params).all();
  return c.json(results);
});

app.post('/stock-checks', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'SALESPERSON' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: salesperson or owner role required' }, 403);
  }

  const body = await c.req.json();
  const retailerId = body.retailerId || body.retailer_id;
  const productId = body.productId || body.product_id;
  const quantity = body.quantity;

  if (!retailerId || !productId || typeof quantity !== 'number' || quantity < 0) {
    return c.json({ error: 'retailerId, productId, and non-negative quantity are required' }, 400);
  }

  // Tenant isolation & retailer verification
  const retailer = await c.env.DB.prepare('SELECT * FROM retailers WHERE id = ? AND company_id = ?')
    .bind(retailerId, user.company_id)
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

  // Tenant isolation & product verification
  const product = await c.env.DB.prepare('SELECT 1 FROM products WHERE id = ? AND company_id = ?')
    .bind(productId, user.company_id)
    .first();

  if (!product) {
    return c.json({ error: 'Product not found in this company' }, 400);
  }

  const id = `sc_${crypto.randomUUID()}`;
  const now = Date.now();

  await c.env.DB.prepare(
    `INSERT INTO stock_checks (id, company_id, retailer_id, employee_id, product_id, quantity, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).bind(id, user.company_id, retailerId, user.sub, productId, quantity, now).run();

  return c.json({ success: true, stockCheckId: id });
});

app.get('/stock-checks/:retailerId', authMiddleware, async (c) => {
  const user = c.get('user');
  const retailerId = c.req.param('retailerId');

  // Tenant isolation & retailer verification
  const retailer = await c.env.DB.prepare('SELECT * FROM retailers WHERE id = ? AND company_id = ?')
    .bind(retailerId, user.company_id)
    .first() as any;

  if (!retailer) {
    return c.json({ error: 'Retailer not found in this company' }, 404);
  }

  // Salesperson beat assignment check
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

  const { results } = await c.env.DB.prepare(
    `SELECT sc.id, sc.product_id AS productId, p.name AS productName, sc.quantity, sc.created_at AS createdAt
     FROM stock_checks sc
     JOIN products p ON sc.product_id = p.id
     WHERE sc.company_id = ? AND sc.retailer_id = ?
     ORDER BY sc.created_at DESC LIMIT 50`
  ).bind(user.company_id, retailerId).all();

  return c.json(results);
});

app.put('/visits/:id/checkout', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'SALESPERSON' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: salesperson or owner role required' }, 403);
  }

  const visitId = c.req.param('id');
  const body = await c.req.json();
  const checkOutTime = body.checkOutTime || body.check_out_time || Date.now();
  const durationSeconds = body.durationSeconds ?? body.duration_seconds ?? 0;
  const noOrderReason = body.noOrderReason || body.no_order_reason || null;
  const notes = body.notes?.trim() || null;

  const visit = await c.env.DB.prepare('SELECT * FROM visits WHERE id = ? AND company_id = ?')
    .bind(visitId, user.company_id).first() as any;

  if (!visit) {
    return c.json({ error: 'Visit not found' }, 404);
  }

  if (user.role === 'SALESPERSON' && visit.employee_id !== user.sub) {
    return c.json({ error: 'Unauthorized: cannot checkout another salesperson visit' }, 403);
  }

  await c.env.DB.prepare(
    `UPDATE visits
     SET check_out_time = ?, duration_seconds = ?, status = 'COMPLETED', no_order_reason = ?, notes = ?
     WHERE id = ? AND company_id = ?`
  ).bind(checkOutTime, durationSeconds, noOrderReason, notes, visitId, user.company_id).run();

  return c.json({ success: true });
});

// ============================================================================
// BEATS & TERRITORY MANAGEMENT
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

app.post('/shifts/start', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'SALESPERSON' && user.role !== 'DELIVERY_EXECUTIVE') {
    return c.json({ error: 'Permission denied: field role required' }, 403);
  }

  const body = await c.req.json().catch(() => ({}));
  const lat = body.latitude ?? null;
  const lng = body.longitude ?? null;
  const now = Date.now();

  const activeShift = await c.env.DB.prepare(
    'SELECT * FROM shifts WHERE user_id = ? AND company_id = ? AND status = ? ORDER BY start_time DESC LIMIT 1'
  ).bind(user.sub, user.company_id, 'ON_SHIFT').first() as any;

  if (activeShift) {
    return c.json({
      success: true,
      idempotent: true,
      shift: {
        id: activeShift.id,
        status: activeShift.status,
        startTime: activeShift.start_time
      }
    });
  }

  const shiftId = `shift_${crypto.randomUUID()}`;
  await c.env.DB.prepare(
    `INSERT INTO shifts (id, company_id, user_id, status, start_time, start_latitude, start_longitude, created_at)
     VALUES (?, ?, ?, 'ON_SHIFT', ?, ?, ?, ?)`
  ).bind(shiftId, user.company_id, user.sub, now, lat, lng, now).run();

  return c.json({
    success: true,
    shift: {
      id: shiftId,
      status: 'ON_SHIFT',
      startTime: now
    }
  });
});

app.post('/shifts/end', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'SALESPERSON' && user.role !== 'DELIVERY_EXECUTIVE') {
    return c.json({ error: 'Permission denied: field role required' }, 403);
  }

  const body = await c.req.json().catch(() => ({}));
  const lat = body.latitude ?? null;
  const lng = body.longitude ?? null;
  const now = Date.now();

  const activeShift = await c.env.DB.prepare(
    'SELECT * FROM shifts WHERE user_id = ? AND company_id = ? AND status = ? ORDER BY start_time DESC LIMIT 1'
  ).bind(user.sub, user.company_id, 'ON_SHIFT').first() as any;

  if (!activeShift) {
    return c.json({ error: 'No active shift found to end' }, 400);
  }

  await c.env.DB.prepare(
    'UPDATE shifts SET status = ?, end_time = ?, end_latitude = ?, end_longitude = ? WHERE id = ?'
  ).bind('OFF_SHIFT', now, lat, lng, activeShift.id).run();

  return c.json({
    success: true,
    shift: {
      id: activeShift.id,
      status: 'OFF_SHIFT',
      startTime: activeShift.start_time,
      endTime: now
    }
  });
});

app.post('/shifts/locations', authMiddleware, async (c) => {
  const user = c.get('user');
  const body = await c.req.json();
  const shiftId = body.shiftId || body.shift_id;
  const points = body.points || [];

  if (!shiftId || !Array.isArray(points) || points.length === 0) {
    return c.json({ error: 'shiftId and points array required' }, 400);
  }

  const statements = points.map((p: any) =>
    c.env.DB.prepare(
      `INSERT OR IGNORE INTO shift_locations (id, shift_id, company_id, user_id, latitude, longitude, accuracy, timestamp)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      p.id || `loc_${crypto.randomUUID()}`,
      shiftId,
      user.company_id,
      user.sub,
      p.latitude,
      p.longitude,
      p.accuracy ?? 10.0,
      p.timestamp || Date.now()
    )
  );

  await c.env.DB.batch(statements);
  return c.json({ success: true, count: points.length });
});

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

    const isStale = lastLoc ? (now - lastLoc.timestamp > 1800000) : true;

    teamStatusList.push({
      id: emp.id,
      fullName: emp.fullName,
      role: emp.role,
      shiftStatus: shift?.status === 'ON_SHIFT' ? 'ON_SHIFT' : 'OFF_SHIFT',
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

app.post('/collections', authMiddleware, async (c) => {
  const user = c.get('user');
  const body = await c.req.json();
  const { retailerId, amountPaise, paymentMethod, receiptId, notes, idempotencyKey } = body;

  if (!retailerId || !amountPaise || amountPaise <= 0 || !paymentMethod) {
    return c.json({ error: 'retailerId, valid amountPaise, and paymentMethod required' }, 400);
  }

  if (!['CASH', 'UPI', 'CHEQUE'].includes(paymentMethod)) {
    return c.json({ error: 'paymentMethod must be CASH, UPI, or CHEQUE' }, 400);
  }

  // Multi-tenant check
  const retailer = await c.env.DB.prepare(
    'SELECT * FROM retailers WHERE id = ? AND company_id = ?'
  ).bind(retailerId, user.company_id).first() as any;

  if (!retailer) {
    return c.json({ error: 'Retailer not found in company' }, 404);
  }

  // Idempotency check
  if (idempotencyKey) {
    const existing = await c.env.DB.prepare(
      'SELECT * FROM collections WHERE idempotency_key = ? AND company_id = ?'
    ).bind(idempotencyKey, user.company_id).first() as any;

    if (existing) {
      return c.json({
        success: true,
        collectionId: existing.id,
        receiptId: existing.receipt_id,
        balanceAfterPaise: retailer.outstanding_amount_paise,
        idempotent: true
      });
    }
  }

  const collectionId = `col_${crypto.randomUUID()}`;
  const finalReceiptId = receiptId || `REC-${Date.now().toString(36).toUpperCase()}-${Math.floor(1000 + Math.random() * 9000)}`;
  const ledgerId = `led_${crypto.randomUUID()}`;
  const now = Date.now();
  const entryType = paymentMethod === 'CASH' ? 'CASH_PAYMENT' : (paymentMethod === 'UPI' ? 'UPI_PAYMENT' : 'CHEQUE_PAYMENT');

  const statements = [
    // 1. Insert collection record
    c.env.DB.prepare(
      `INSERT INTO collections (id, company_id, retailer_id, collected_by, amount_paise, payment_method, receipt_id, notes, idempotency_key, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(collectionId, user.company_id, retailerId, user.sub, amountPaise, paymentMethod, finalReceiptId, notes || null, idempotencyKey || null, now),

    // 2. Atomically reduce retailer outstanding balance
    c.env.DB.prepare(
      'UPDATE retailers SET outstanding_amount_paise = outstanding_amount_paise - ? WHERE id = ? AND company_id = ?'
    ).bind(amountPaise, retailerId, user.company_id),

    // 3. Insert into payment_ledger with updated balance
    c.env.DB.prepare(
      `INSERT INTO payment_ledger (
        id, order_id, invoice_id, collection_id, company_id, retailer_id,
        entry_type, amount_paise, balance_after_paise, payment_method, collected_by, created_at, idempotency_key
      )
      SELECT ?, NULL, NULL, ?, ?, ?, ?, ?, outstanding_amount_paise, ?, ?, ?, ?
      FROM retailers WHERE id = ? AND company_id = ?`
    ).bind(
      ledgerId,
      collectionId,
      user.company_id,
      retailerId,
      entryType,
      amountPaise,
      paymentMethod,
      user.sub,
      now,
      idempotencyKey || null,
      retailerId,
      user.company_id
    ),

    // 4. Audit log
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'COLLECTION_RECORDED', collectionId, `Amount: ${amountPaise}, Method: ${paymentMethod}, Receipt: ${finalReceiptId}`, now)
  ];

  await c.env.DB.batch(statements);

  const updatedRetailer = await c.env.DB.prepare(
    'SELECT outstanding_amount_paise FROM retailers WHERE id = ? AND company_id = ?'
  ).bind(retailerId, user.company_id).first() as any;

  return c.json({
    success: true,
    collectionId,
    receiptId: finalReceiptId,
    balanceAfterPaise: updatedRetailer ? updatedRetailer.outstanding_amount_paise : 0
  });
});

app.get('/collections', authMiddleware, async (c) => {
  const user = c.get('user');
  const retailerId = c.req.query('retailerId');
  let query = `SELECT c.*, r.name as retailer_name, u.full_name as collected_by_name 
               FROM collections c 
               JOIN retailers r ON c.retailer_id = r.id 
               JOIN users u ON c.collected_by = u.id 
               WHERE c.company_id = ?`;
  const params: any[] = [user.company_id];

  if (retailerId) {
    query += ' AND c.retailer_id = ?';
    params.push(retailerId);
  }
  query += ' ORDER BY c.created_at DESC LIMIT 50';

  const results = await c.env.DB.prepare(query).bind(...params).all();
  return c.json({ collections: results.results || [] });
});

// ============================================================================
// SLICE E: CASH HANDOVER & RECONCILIATION
// ============================================================================

app.get('/handovers/summary', authMiddleware, async (c) => {
  const user = c.get('user');

  // Sum of cash collected by this user in this company
  const collectedRow = await c.env.DB.prepare(
    `SELECT COALESCE(SUM(amount_paise), 0) as total_cash_collected
     FROM payment_ledger
     WHERE company_id = ? AND collected_by = ? AND payment_method = 'CASH' AND entry_type = 'CASH_PAYMENT'`
  ).bind(user.company_id, user.sub).first() as any;

  // Sum of accepted handovers for this user in this company
  const settledRow = await c.env.DB.prepare(
    `SELECT COALESCE(SUM(received_amount_paise), 0) as total_cash_settled
     FROM cash_handovers
     WHERE company_id = ? AND user_id = ? AND status = 'ACCEPTED'`
  ).bind(user.company_id, user.sub).first() as any;

  const totalCollected = collectedRow?.total_cash_collected || 0;
  const totalSettled = settledRow?.total_cash_settled || 0;
  const cashHeldPaise = Math.max(0, totalCollected - totalSettled);

  // Check for any pending handover
  const pendingHandover = await c.env.DB.prepare(
    `SELECT * FROM cash_handovers
     WHERE company_id = ? AND user_id = ? AND status = 'PENDING'
     ORDER BY submitted_at DESC LIMIT 1`
  ).bind(user.company_id, user.sub).first() as any;

  // Get recent history
  const recentHandovers = await c.env.DB.prepare(
    `SELECT * FROM cash_handovers
     WHERE company_id = ? AND user_id = ?
     ORDER BY submitted_at DESC LIMIT 5`
  ).bind(user.company_id, user.sub).all();

  return c.json({
    cashHeldPaise,
    totalCollectedPaise: totalCollected,
    totalSettledPaise: totalSettled,
    pendingHandover: pendingHandover || null,
    recentHandovers: recentHandovers.results || []
  });
});

app.post('/handovers/request', authMiddleware, async (c) => {
  const user = c.get('user');
  const body = await c.req.json();
  const amountPaise = body.amountPaise;
  const notes = body.notes;

  if (!amountPaise || amountPaise <= 0) {
    return c.json({ error: 'amountPaise must be greater than 0' }, 400);
  }

  // Check if a PENDING handover already exists
  const existingPending = await c.env.DB.prepare(
    `SELECT id FROM cash_handovers WHERE company_id = ? AND user_id = ? AND status = 'PENDING'`
  ).bind(user.company_id, user.sub).first() as any;

  if (existingPending) {
    return c.json({ error: 'Active pending handover already exists. Please wait for reconciliation.' }, 400);
  }

  // Calculate actual cash held
  const collectedRow = await c.env.DB.prepare(
    `SELECT COALESCE(SUM(amount_paise), 0) as total_cash_collected
     FROM payment_ledger
     WHERE company_id = ? AND collected_by = ? AND payment_method = 'CASH' AND entry_type = 'CASH_PAYMENT'`
  ).bind(user.company_id, user.sub).first() as any;

  const settledRow = await c.env.DB.prepare(
    `SELECT COALESCE(SUM(received_amount_paise), 0) as total_cash_settled
     FROM cash_handovers
     WHERE company_id = ? AND user_id = ? AND status = 'ACCEPTED'`
  ).bind(user.company_id, user.sub).first() as any;

  const cashHeld = Math.max(0, (collectedRow?.total_cash_collected || 0) - (settledRow?.total_cash_settled || 0));

  if (amountPaise > cashHeld) {
    return c.json({ error: `Requested handover (₹${amountPaise / 100}) exceeds available cash held (₹${cashHeld / 100})` }, 400);
  }

  const handoverId = `hnd_${crypto.randomUUID()}`;
  const now = Date.now();

  await c.env.DB.prepare(
    `INSERT INTO cash_handovers (id, company_id, user_id, amount_paise, status, submitted_at, notes)
     VALUES (?, ?, ?, ?, 'PENDING', ?, ?)`
  ).bind(handoverId, user.company_id, user.sub, amountPaise, now, notes || null).run();

  return c.json({ success: true, handoverId, status: 'PENDING', amountPaise });
});

app.get('/owner/handovers', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const results = await c.env.DB.prepare(
    `SELECT h.*, u.full_name as employee_name, u.role as employee_role
     FROM cash_handovers h
     JOIN users u ON h.user_id = u.id
     WHERE h.company_id = ?
     ORDER BY h.submitted_at DESC`
  ).bind(user.company_id).all();

  return c.json({ handovers: results.results || [] });
});

app.post('/owner/handovers/:id/acknowledge', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: owner role required' }, 403);
  }

  const handoverId = c.req.param('id');
  const body = await c.req.json();
  const { action, receivedAmountPaise, notes } = body;

  if (!['ACCEPT', 'REJECT'].includes(action)) {
    return c.json({ error: 'action must be ACCEPT or REJECT' }, 400);
  }

  const handover = await c.env.DB.prepare(
    `SELECT * FROM cash_handovers WHERE id = ? AND company_id = ?`
  ).bind(handoverId, user.company_id).first() as any;

  if (!handover) {
    return c.json({ error: 'Handover request not found' }, 404);
  }

  if (handover.status !== 'PENDING') {
    return c.json({ error: `Handover has already been ${handover.status.toLowerCase()}` }, 400);
  }

  const now = Date.now();
  if (action === 'ACCEPT') {
    const finalReceived = receivedAmountPaise !== undefined ? receivedAmountPaise : handover.amount_paise;
    const discrepancy = finalReceived - handover.amount_paise;

    await c.env.DB.prepare(
      `UPDATE cash_handovers
       SET status = 'ACCEPTED', acknowledged_at = ?, acknowledged_by = ?, received_amount_paise = ?, discrepancy_paise = ?, notes = ?
       WHERE id = ? AND company_id = ?`
    ).bind(now, user.sub, finalReceived, discrepancy, notes || handover.notes, handoverId, user.company_id).run();

    await c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'HANDOVER_ACCEPTED', handoverId, `Amount: ${handover.amount_paise}, Received: ${finalReceived}, Discrepancy: ${discrepancy}`, now).run();

    return c.json({ success: true, status: 'ACCEPTED', receivedAmountPaise: finalReceived, discrepancyPaise: discrepancy });
  } else {
    await c.env.DB.prepare(
      `UPDATE cash_handovers
       SET status = 'REJECTED', acknowledged_at = ?, acknowledged_by = ?, notes = ?
       WHERE id = ? AND company_id = ?`
    ).bind(now, user.sub, notes || handover.notes, handoverId, user.company_id).run();

    await c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'HANDOVER_REJECTED', handoverId, notes || 'Rejected by cashier', now).run();

    return c.json({ success: true, status: 'REJECTED' });
  }
});

// ============================================================================
// SLICE F: RETURNS WORKFLOW & RESTOCK DISPOSITION
// ============================================================================

app.post('/returns', authMiddleware, async (c) => {
  const user = c.get('user');
  const body = await c.req.json();
  const { orderId, items, notes } = body;

  if (!orderId || !Array.isArray(items) || items.length === 0) {
    return c.json({ error: 'orderId and non-empty items array required' }, 400);
  }

  // Verify order exists, is DELIVERED, and belongs to company
  const order = await c.env.DB.prepare(
    'SELECT * FROM orders WHERE id = ? AND company_id = ?'
  ).bind(orderId, user.company_id).first() as any;

  if (!order) {
    return c.json({ error: 'Order not found in company' }, 404);
  }
  if (order.status !== 'DELIVERED') {
    return c.json({ error: 'Returns can only be requested for DELIVERED orders' }, 400);
  }

  // Get delivered order items
  const orderItems = await c.env.DB.prepare(
    'SELECT * FROM order_items WHERE order_id = ?'
  ).bind(orderId).all();

  const itemMap = new Map<string, any>();
  for (const item of (orderItems.results || []) as any[]) {
    itemMap.set(item.product_id, item);
  }

  // Validate items
  for (const item of items) {
    const deliveredItem = itemMap.get(item.productId);
    if (!deliveredItem) {
      return c.json({ error: `Product ${item.productId} was not part of order ${orderId}` }, 400);
    }
    if (item.requestedQuantity <= 0 || item.requestedQuantity > deliveredItem.quantity) {
      return c.json({ error: `Requested quantity for ${item.productId} exceeds delivered quantity (${deliveredItem.quantity})` }, 400);
    }
  }

  const returnId = `ret_${crypto.randomUUID()}`;
  const now = Date.now();

  const statements = [
    c.env.DB.prepare(
      `INSERT INTO return_requests (id, company_id, order_id, retailer_id, created_by, status, created_at, notes)
       VALUES (?, ?, ?, ?, ?, 'PENDING_INSPECTION', ?, ?)`
    ).bind(returnId, user.company_id, orderId, order.retailer_id, user.sub, now, notes || null)
  ];

  for (const item of items) {
    const deliveredItem = itemMap.get(item.productId);
    statements.push(
      c.env.DB.prepare(
        `INSERT INTO return_items (id, return_id, product_id, requested_quantity, unit_price_paise)
         VALUES (?, ?, ?, ?, ?)`
      ).bind(`ri_${crypto.randomUUID()}`, returnId, item.productId, item.requestedQuantity, deliveredItem.price_paise_at_time || deliveredItem.price_paise || 0)
    );
  }

  statements.push(
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'RETURN_REQUESTED', returnId, `Order: ${orderId}, Items: ${items.length}`, now)
  );

  await c.env.DB.batch(statements);

  return c.json({ success: true, returnId, status: 'PENDING_INSPECTION' });
});

app.get('/returns/pending', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse or owner role required' }, 403);
  }

  const returns = await c.env.DB.prepare(
    `SELECT r.*, ret.name as retailer_name, u.full_name as created_by_name
     FROM return_requests r
     JOIN retailers ret ON r.retailer_id = ret.id
     JOIN users u ON r.created_by = u.id
     WHERE r.company_id = ? AND r.status = 'PENDING_INSPECTION'
     ORDER BY r.created_at ASC`
  ).bind(user.company_id).all();

  const returnList = (returns.results || []) as any[];
  for (const r of returnList) {
    const items = await c.env.DB.prepare(
      `SELECT ri.*, p.name as product_name, p.hindi_name as product_hindi_name, p.sku
       FROM return_items ri
       JOIN products p ON ri.product_id = p.id
       WHERE ri.return_id = ?`
    ).bind(r.id).all();
    r.items = items.results || [];
  }

  return c.json({ returns: returnList });
});

app.post('/returns/:id/inspect', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse or owner role required' }, 403);
  }

  const returnId = c.req.param('id');
  const body = await c.req.json();
  const { action, items, notes } = body;

  if (!['APPROVE', 'REJECT'].includes(action)) {
    return c.json({ error: 'action must be APPROVE or REJECT' }, 400);
  }

  const returnReq = await c.env.DB.prepare(
    'SELECT * FROM return_requests WHERE id = ? AND company_id = ?'
  ).bind(returnId, user.company_id).first() as any;

  if (!returnReq) {
    return c.json({ error: 'Return request not found' }, 404);
  }
  if (returnReq.status !== 'PENDING_INSPECTION') {
    return c.json({ error: `Return has already been ${returnReq.status.toLowerCase()}` }, 400);
  }

  const now = Date.now();

  if (action === 'REJECT') {
    await c.env.DB.prepare(
      `UPDATE return_requests SET status = 'REJECTED', inspected_at = ?, inspected_by = ?, notes = ? WHERE id = ?`
    ).bind(now, user.sub, notes || returnReq.notes, returnId).run();

    await c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'RETURN_REJECTED', returnId, notes || 'Rejected by warehouse inspector', now).run();

    return c.json({ success: true, status: 'REJECTED' });
  }

  // APPROVE branch
  if (!Array.isArray(items) || items.length === 0) {
    return c.json({ error: 'Inspected items array required for approval' }, 400);
  }

  const existingItems = await c.env.DB.prepare(
    'SELECT * FROM return_items WHERE return_id = ?'
  ).bind(returnId).all();

  const itemMap = new Map<string, any>();
  for (const item of (existingItems.results || []) as any[]) {
    itemMap.set(item.product_id, item);
  }

  let totalCreditNotePaise = 0;
  const statements = [
    c.env.DB.prepare(
      `UPDATE return_requests SET status = 'APPROVED', inspected_at = ?, inspected_by = ?, notes = ? WHERE id = ?`
    ).bind(now, user.sub, notes || returnReq.notes, returnId)
  ];

  for (const item of items) {
    const existing = itemMap.get(item.productId);
    if (!existing) {
      return c.json({ error: `Product ${item.productId} was not in this return request` }, 400);
    }
    const saleable = item.saleableQuantity || 0;
    const damaged = item.damagedQuantity || 0;

    if (saleable + damaged > existing.requested_quantity) {
      return c.json({ error: `Inspected quantity (${saleable + damaged}) exceeds requested quantity (${existing.requested_quantity}) for product ${item.productId}` }, 400);
    }

    const itemTotalPaise = (saleable + damaged) * existing.unit_price_paise;
    totalCreditNotePaise += itemTotalPaise;

    statements.push(
      c.env.DB.prepare(
        'UPDATE return_items SET saleable_quantity = ?, damaged_quantity = ? WHERE return_id = ? AND product_id = ?'
      ).bind(saleable, damaged, returnId, item.productId)
    );

    if (saleable > 0) {
      statements.push(
        c.env.DB.prepare(
          'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?'
        ).bind(saleable, item.productId, user.company_id)
      );

      statements.push(
        c.env.DB.prepare(
          `INSERT INTO stock_adjustments (
            id, company_id, product_id, user_id, change_quantity, reason,
            stock_after, notes, idempotency_key, created_at
          )
          SELECT ?, ?, ?, ?, ?, 'RETURN_RESTOCK', stock_quantity, ?, ?, ?
          FROM products WHERE id = ? AND company_id = ?`
        ).bind(
          `adj_${crypto.randomUUID()}`,
          user.company_id,
          item.productId,
          user.sub,
          saleable,
          `Restock from return ${returnId}`,
          `adj_ret_${returnId}_${item.productId}`,
          now,
          item.productId,
          user.company_id
        )
      );
    }
  }

  if (totalCreditNotePaise > 0) {
    statements.push(
      c.env.DB.prepare(
        'UPDATE retailers SET outstanding_amount_paise = outstanding_amount_paise - ? WHERE id = ? AND company_id = ?'
      ).bind(totalCreditNotePaise, returnReq.retailer_id, user.company_id)
    );

    statements.push(
      c.env.DB.prepare(
        `INSERT INTO payment_ledger (
          id, order_id, invoice_id, collection_id, company_id, retailer_id,
          entry_type, amount_paise, balance_after_paise, payment_method, collected_by, created_at
        )
        SELECT ?, ?, NULL, NULL, ?, ?, 'RETURN_CREDIT_NOTE', ?, outstanding_amount_paise, 'CREDIT_NOTE', ?, ?
        FROM retailers WHERE id = ? AND company_id = ?`
      ).bind(
        `led_${crypto.randomUUID()}`,
        returnReq.order_id,
        user.company_id,
        returnReq.retailer_id,
        totalCreditNotePaise,
        user.sub,
        now,
        returnReq.retailer_id,
        user.company_id
      )
    );
  }

  statements.push(
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'RETURN_APPROVED', returnId, `CreditNote: ${totalCreditNotePaise}`, now)
  );

  try {
    await c.env.DB.batch(statements);
    return c.json({
      success: true,
      status: 'APPROVED',
      totalCreditNotePaise
    });
  } catch (e: any) {
    return c.json({ error: e.message || 'Inspection batch failed' }, 400);
  }
});

export default app;
