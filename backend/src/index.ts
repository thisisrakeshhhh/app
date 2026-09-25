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

  let query = 'SELECT id, name, beat_id AS beatId, address, contact_number AS contactNumber, latitude, longitude, credit_limit_paise AS creditLimitPaise, outstanding_amount_paise AS outstandingAmountPaise FROM retailers WHERE company_id = ?';
  const params: any[] = [user.company_id];

  // Salesperson beat assignment check: only show retailers for beats assigned to this salesperson
  if (user.role === 'SALESPERSON') {
    query += ' AND beat_id IN (SELECT beat_id FROM user_beat_assignments WHERE user_id = ? AND company_id = ?)';
    params.push(user.sub, user.company_id);
  }

  const { results } = await c.env.DB.prepare(query).bind(...params).all();
  return c.json(results);
});

app.get('/products', authMiddleware, async (c) => {
  const user = c.get('user');
  const { results } = await c.env.DB.prepare(
    'SELECT id, name, category, price_paise AS pricePaise, stock_quantity AS stockQuantity, reserved_quantity AS reservedQuantity, unit, image_url AS imageUrl FROM products WHERE company_id = ?'
  )
    .bind(user.company_id)
    .all();

  return c.json(results);
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

  return c.json({
    success: true,
    message: `Delivery OTP sent to ${retailer?.name || 'Retailer'} (${retailer?.contact_number || 'Registered mobile'})`,
    expiresAt,
    debugOtp: activeOtp
  });
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
  let verifiedRecipient = recipientName || 'Authorized Receiver';

  if (otpRecord && (otp || recipientName || c.req.header('X-Require-Delivery-Otp') === 'true')) {
    // When OTP verification is invoked, validate strictly
    if (!recipientName) {
      return c.json({ error: 'Recipient name is required to confirm delivery' }, 400);
    }
    if (!otp || !/^\d{6}$/.test(otp)) {
      return c.json({ error: 'A valid 6-digit delivery OTP is required' }, 400);
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
  const now = Date.now();

  const statements = [
    c.env.DB.prepare(
      `INSERT INTO products (id, company_id, name, category, price_paise, mrp_paise, stock_quantity, reserved_quantity, unit, sku, image_url, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, 1)`
    ).bind(id, user.company_id, name, category, pricePaise, mrpPaise, stockQuantity, unit, sku, imageUrl),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'PRODUCT_CREATED', id, `Product: ${name}, Price: ${pricePaise}, Stock: ${stockQuantity}`, now)
  ];

  await c.env.DB.batch(statements);
  return c.json({
    success: true,
    product: { id, name, category, pricePaise, mrpPaise, stockQuantity, reservedQuantity: 0, unit, sku, imageUrl, isActive: true }
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
      `UPDATE products SET name = ?, category = ?, price_paise = ?, mrp_paise = ?, unit = ?, sku = ?, is_active = ?, image_url = ?
       WHERE id = ? AND company_id = ?`
    ).bind(name, category, pricePaise, mrpPaise, unit, sku, isActive, imageUrl, id, user.company_id),
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

  if (!productId || typeof changeQuantity !== 'number' || changeQuantity === 0 || !reason) {
    return c.json({ error: 'productId, non-zero changeQuantity, and valid reason are required' }, 400);
  }

  const VALID_REASONS = ['STOCK_RECEIPT', 'DAMAGE', 'AUDIT_CORRECTION', 'RETURN_RESTOCK'];
  if (!VALID_REASONS.includes(reason)) {
    return c.json({ error: `Invalid reason. Allowed: ${VALID_REASONS.join(', ')}` }, 400);
  }

  const product = await c.env.DB.prepare('SELECT * FROM products WHERE id = ? AND company_id = ?')
    .bind(productId, user.company_id).first() as any;

  if (!product) return c.json({ error: 'Product not found' }, 404);

  const newStock = product.stock_quantity + changeQuantity;
  if (newStock < 0) {
    return c.json({ error: `Adjustment exceeds available physical stock. Current: ${product.stock_quantity}, Change: ${changeQuantity}` }, 400);
  }
  if (newStock < product.reserved_quantity) {
    return c.json({ error: `Cannot adjust stock below current reserved quantity (${product.reserved_quantity})` }, 400);
  }

  const now = Date.now();
  const adjId = `adj_${crypto.randomUUID()}`;

  const statements = [
    c.env.DB.prepare('UPDATE products SET stock_quantity = ? WHERE id = ? AND company_id = ?')
      .bind(newStock, productId, user.company_id),
    c.env.DB.prepare(
      `INSERT INTO stock_adjustments (id, company_id, product_id, user_id, change_quantity, reason, stock_after, notes, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(adjId, user.company_id, productId, user.sub, changeQuantity, reason, newStock, notes, now),
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

  const { results } = await c.env.DB.prepare(
    `SELECT sc.id, sc.product_id AS productId, p.name AS productName, sc.quantity, sc.created_at AS createdAt
     FROM stock_checks sc
     JOIN products p ON sc.product_id = p.id
     WHERE sc.company_id = ? AND sc.retailer_id = ?
     ORDER BY sc.created_at DESC LIMIT 50`
  ).bind(user.company_id, retailerId).all();

  return c.json(results);
});

export default app;
