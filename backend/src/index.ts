import { Hono } from 'hono';
import { sign, verify } from '@tsndr/cloudflare-worker-jwt';
import bcrypt from 'bcryptjs';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  JWT_ACCESS_EXPIRY: string;
  JWT_REFRESH_EXPIRY: string;
};

const app = new Hono<{ Bindings: Bindings }>();

async function verifyPassword(plain: string, hash: string): Promise<boolean> {
  if (hash.startsWith('$2a$') || hash.startsWith('$2b$')) {
    try {
      return bcrypt.compareSync(plain, hash);
    } catch {
      return false;
    }
  }
  return plain === hash;
}

// Authentication Middleware
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
  if (!payload || !payload.sub) {
    return c.json({ error: 'Invalid token payload' }, 401);
  }

  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
    return c.json({ error: 'Invalid or expired token' }, 401);
  }

  // Verify user is still active in DB
  const user = await c.env.DB.prepare('SELECT is_active, company_id, role, full_name FROM users WHERE id = ?')
    .bind(payload.sub)
    .first() as any;

  if (!user || !user.is_active) {
    return c.json({ error: 'User account disabled' }, 403);
  }

  // Cross-tenant verification: payload company must match active user's company
  if (payload.company_id !== user.company_id) {
    return c.json({ error: 'Unauthorized tenant access' }, 403);
  }

  c.set('user', payload);
  await next();
};

// --- AUTH ENDPOINTS ---

app.post('/auth/login', async (c) => {
  const { username, password } = await c.req.json();
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

  const accessExpirySeconds = parseInt(c.env.JWT_ACCESS_EXPIRY || '900', 10);
  const accessToken = await sign({
    sub: user.id,
    company_id: user.company_id,
    role: user.role,
    name: user.full_name,
    exp: Math.floor(Date.now() / 1000) + accessExpirySeconds,
  }, c.env.JWT_SECRET);

  const refreshToken = crypto.randomUUID();
  const refreshTokenHash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(refreshToken))
    .then(b => Array.from(new Uint8Array(b)).map(x => x.toString(16).padStart(2, '0')).join(''));

  const refreshExpirySeconds = parseInt(c.env.JWT_REFRESH_EXPIRY || '2592000', 10);
  await c.env.DB.prepare('INSERT INTO refresh_tokens (token_hash, user_id, company_id, expires_at, created_at, revoked_at) VALUES (?, ?, ?, ?, ?, NULL)')
    .bind(refreshTokenHash, user.id, user.company_id, Math.floor(Date.now() / 1000) + refreshExpirySeconds, Math.floor(Date.now() / 1000))
    .run();

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

  const refreshTokenHash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(refresh_token))
    .then(b => Array.from(new Uint8Array(b)).map(x => x.toString(16).padStart(2, '0')).join(''));

  const storedToken = await c.env.DB.prepare('SELECT * FROM refresh_tokens WHERE token_hash = ?')
    .bind(refreshTokenHash)
    .first() as any;

  if (!storedToken) {
    return c.json({ error: 'Invalid or expired refresh token' }, 401);
  }

  // Token reuse detection: if revoked_at is set, an old rotated token was presented!
  if (storedToken.revoked_at !== null) {
    // Invalidate all tokens for this user
    await c.env.DB.prepare('UPDATE refresh_tokens SET revoked_at = ? WHERE user_id = ?')
      .bind(Math.floor(Date.now() / 1000), storedToken.user_id)
      .run();
    return c.json({ error: 'Refresh token reuse detected. All sessions revoked.' }, 401);
  }

  // Check expiration
  if (storedToken.expires_at <= Math.floor(Date.now() / 1000)) {
    return c.json({ error: 'Refresh token expired' }, 401);
  }

  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?')
    .bind(storedToken.user_id)
    .first() as any;

  if (!user || !user.is_active) {
    return c.json({ error: 'User account disabled or not found' }, 403);
  }

  // Rotate refresh token atomically
  const newRefreshToken = crypto.randomUUID();
  const newRefreshTokenHash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(newRefreshToken))
    .then(b => Array.from(new Uint8Array(b)).map(x => x.toString(16).padStart(2, '0')).join(''));

  const accessExpirySeconds = parseInt(c.env.JWT_ACCESS_EXPIRY || '900', 10);
  const refreshExpirySeconds = parseInt(c.env.JWT_REFRESH_EXPIRY || '2592000', 10);

  const accessToken = await sign({
    sub: user.id,
    company_id: user.company_id,
    role: user.role,
    name: user.full_name,
    exp: Math.floor(Date.now() / 1000) + accessExpirySeconds,
  }, c.env.JWT_SECRET);

  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE refresh_tokens SET revoked_at = ? WHERE token_hash = ?')
      .bind(Math.floor(Date.now() / 1000), refreshTokenHash),
    c.env.DB.prepare('INSERT INTO refresh_tokens (token_hash, user_id, company_id, expires_at, created_at, revoked_at) VALUES (?, ?, ?, ?, ?, NULL)')
      .bind(newRefreshTokenHash, user.id, user.company_id, Math.floor(Date.now() / 1000) + refreshExpirySeconds, Math.floor(Date.now() / 1000))
  ]);

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
  await c.env.DB.prepare('DELETE FROM refresh_tokens WHERE user_id = ?').bind(user.sub).run();
  return c.json({ success: true });
});

app.get('/me', authMiddleware, async (c) => {
  const user = c.get('user');
  return c.json(user);
});

// --- CATALOG & RETAILERS ---

app.get('/retailers', authMiddleware, async (c) => {
  const user = c.get('user');
  const { results } = await c.env.DB.prepare(
    'SELECT id, name, beat_id AS beatId, address, contact_number AS contactNumber, latitude, longitude, credit_limit_paise AS creditLimitPaise, outstanding_amount_paise AS outstandingAmountPaise FROM retailers WHERE company_id = ?'
  )
    .bind(user.company_id)
    .all();

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

// --- ORDER LIFECYCLE ---

app.post('/orders', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'SALESPERSON' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: only salesperson or owner can submit orders' }, 403);
  }

  const body = await c.req.json();
  const order = body.order;
  const items = body.items || [];
  const idempotencyKey = body.idempotencyKey || body.idempotency_key;

  if (!order || !order.id || !order.retailerId || !items.length) {
    return c.json({ error: 'Invalid order structure or empty items' }, 400);
  }

  // Idempotency check: if already processed, return existing order
  if (idempotencyKey) {
    const existing = await c.env.DB.prepare('SELECT id, status, total_amount_paise FROM orders WHERE idempotency_key = ? AND company_id = ?')
      .bind(idempotencyKey, user.company_id)
      .first() as any;
    if (existing) {
      return c.json({ success: true, orderId: existing.id, idempotent: true });
    }
  }

  // Validate retailer and tenant isolation
  const retailer = await c.env.DB.prepare('SELECT * FROM retailers WHERE id = ? AND company_id = ?')
    .bind(order.retailerId, user.company_id)
    .first() as any;

  if (!retailer) {
    return c.json({ error: 'Retailer not found in this company' }, 400);
  }

  // Retailer credit limit validation
  const newOutstanding = (retailer.outstanding_amount_paise || 0) + (order.totalAmountPaise || 0);
  if (newOutstanding > retailer.credit_limit_paise) {
    return c.json({
      error: `Credit limit exceeded. Current outstanding: ${retailer.outstanding_amount_paise}, order: ${order.totalAmountPaise}, limit: ${retailer.credit_limit_paise}`
    }, 400);
  }

  // Validate items, quantities, prices, and promotions
  let computedTotalPaise = 0;
  for (const item of items) {
    const quantity = item.quantity;
    const freeQuantity = item.freeQuantity || 0;

    if (!quantity || quantity <= 0) {
      return c.json({ error: `Invalid item quantity ${quantity} for product ${item.productId}` }, 400);
    }
    if (freeQuantity < 0) {
      return c.json({ error: `Invalid free quantity ${freeQuantity} for product ${item.productId}` }, 400);
    }

    const product = await c.env.DB.prepare('SELECT * FROM products WHERE id = ? AND company_id = ?')
      .bind(item.productId, user.company_id)
      .first() as any;

    if (!product) {
      return c.json({ error: `Product ${item.productId} not found in this company` }, 400);
    }

    // Verify price match
    if (item.pricePaiseAtTime !== product.price_paise) {
      return c.json({
        error: `Price mismatch for product ${product.name}. Expected: ${product.price_paise}, Provided: ${item.pricePaiseAtTime}`
      }, 400);
    }

    computedTotalPaise += (quantity * product.price_paise);
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
      ).bind(order.id, user.company_id, order.retailerId, user.sub, 'SUBMITTED', order.totalAmountPaise, now, now, idempotencyKey),
      c.env.DB.prepare(
        'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
      ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_SUBMITTED', order.id, `Total: ${order.totalAmountPaise} paise`, now)
    ];

    items.forEach((item: any) => {
      statements.push(
        c.env.DB.prepare(
          'INSERT INTO order_items (id, order_id, product_id, quantity, free_quantity, price_paise_at_time, is_picked) VALUES (?, ?, ?, ?, ?, ?, 0)'
        ).bind(item.id, order.id, item.productId, item.quantity, item.freeQuantity || 0, item.pricePaiseAtTime)
      );
    });

    await c.env.DB.batch(statements);
    return c.json({ success: true, orderId: order.id });
  } catch (e: any) {
    if (e.message && e.message.includes('UNIQUE constraint failed')) {
      const existing = await c.env.DB.prepare('SELECT id FROM orders WHERE idempotency_key = ? AND company_id = ?')
        .bind(idempotencyKey, user.company_id)
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
    query += ' AND (delivery_employee_id = ? OR status = ?)';
    params.push(user.sub, 'OUT_FOR_DELIVERY');
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

  // Idempotency: repeated approval does not duplicate side effects
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
    c.env.DB.prepare('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?')
      .bind('APPROVED', now, orderId),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_APPROVED', orderId, 'Stock reserved', now)
  ];

  for (const item of items as any[]) {
    const required = (item.quantity || 0) + (item.free_quantity || 0);
    statements.push(
      c.env.DB.prepare('UPDATE products SET reserved_quantity = reserved_quantity + ? WHERE id = ? AND company_id = ?')
        .bind(required, item.product_id, user.company_id)
    );
  }

  try {
    await c.env.DB.batch(statements);
    return c.json({ success: true });
  } catch (e: any) {
    if (e.message && (e.message.includes('Insufficient stock') || e.message.includes('SQLITE_CONSTRAINT'))) {
      return c.json({ error: 'Insufficient stock available to reserve' }, 400);
    }
    return c.json({ error: e.message || 'Approval failed' }, 500);
  }
});

app.post('/orders/:id/reject', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: only owner can reject orders' }, 403);
  }

  const orderId = c.req.param('id');
  const { reason } = await c.req.json();
  if (!reason || !reason.trim()) {
    return c.json({ error: 'Rejection reason is required' }, 400);
  }

  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  // Idempotency
  if (order.status === 'REJECTED') {
    return c.json({ success: true, idempotent: true });
  }

  if (order.status !== 'SUBMITTED' && order.status !== 'APPROVED') {
    return c.json({ error: `Cannot reject order with status ${order.status}` }, 400);
  }

  const now = Date.now();
  const statements = [
    c.env.DB.prepare('UPDATE orders SET status = ?, rejection_reason = ?, updated_at = ? WHERE id = ?')
      .bind('REJECTED', reason, now, orderId),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_REJECTED', orderId, `Reason: ${reason}`, now)
  ];

  // If order was previously APPROVED, release reserved stock
  if (order.status === 'APPROVED') {
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

  await c.env.DB.batch(statements);
  return c.json({ success: true });
});

app.post('/orders/:id/pick-item', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'WAREHOUSE_MANAGER' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: warehouse role required' }, 403);
  }

  const orderId = c.req.param('id');
  const { productId, isPicked } = await c.req.json();

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

  // Idempotency
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
  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?')
      .bind('PACKED', now, orderId),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_PACKED', orderId, 'All items picked and packed', now)
  ]);

  return c.json({ success: true });
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

  // Idempotency: repeated dispatch does not re-deduct stock
  if (order.status === 'OUT_FOR_DELIVERY') {
    return c.json({ success: true, idempotent: true });
  }

  // Strict transition check: order must be PACKED
  if (order.status !== 'PACKED') {
    return c.json({ error: `Order must be PACKED before dispatch. Current status: ${order.status}` }, 400);
  }

  // Validate delivery employee
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
    return c.json({ success: true });
  } catch (e: any) {
    if (e.message && (e.message.includes('Stock cannot be negative') || e.message.includes('SQLITE_CONSTRAINT'))) {
      return c.json({ error: 'Stock cannot be negative' }, 400);
    }
    return c.json({ error: e.message || 'Dispatch failed' }, 500);
  }
});

app.post('/orders/:id/deliver', authMiddleware, async (c) => {
  const user = c.get('user');
  if (user.role !== 'DELIVERY_EXECUTIVE' && user.role !== 'OWNER') {
    return c.json({ error: 'Permission denied: delivery role required' }, 403);
  }

  const orderId = c.req.param('id');
  const body = await c.req.json();
  const paymentMethod = body.paymentMethod || body.payment_method || 'CASH';

  const order = await c.env.DB.prepare('SELECT * FROM orders WHERE id = ? AND company_id = ?')
    .bind(orderId, user.company_id)
    .first() as any;

  if (!order) return c.json({ error: 'Order not found' }, 404);

  // Idempotency: repeated delivery does not double-post payment or credit
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

  const now = Date.now();
  const statements = [
    c.env.DB.prepare('UPDATE orders SET status = ?, payment_method = ?, updated_at = ? WHERE id = ?')
      .bind('DELIVERED', paymentMethod, now, orderId),
    c.env.DB.prepare(
      'INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), user.company_id, user.sub, 'ORDER_DELIVERED', orderId, `Payment: ${paymentMethod}, Amount: ${order.total_amount_paise}`, now)
  ];

  // If payment method is CREDIT, post to retailer outstanding balance
  if (paymentMethod === 'CREDIT') {
    statements.push(
      c.env.DB.prepare('UPDATE retailers SET outstanding_amount_paise = outstanding_amount_paise + ? WHERE id = ? AND company_id = ?')
        .bind(order.total_amount_paise, order.retailer_id, user.company_id)
    );
  }

  await c.env.DB.batch(statements);
  return c.json({ success: true });
});

export default app;
