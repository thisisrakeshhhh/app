import { Hono, type Context, type MiddlewareHandler } from 'hono';

// Types reused from daily-cycle conventions
export type Actor = { sub: string; company_id: string; role: string; sid: string; name: string };
type BatchEnv = { Bindings: { DB: D1Database }; Variables: { user: Actor } };
type Ctx = Context<BatchEnv>;

const bad = (c: Ctx, error: string, status: 400 | 403 | 404 | 409 = 400) =>
  c.json({ error }, status);

const warehouseRoles = ['WAREHOUSE_MANAGER', 'OWNER'];

// Audit helper
const audit = (c: Ctx, action: string, id: string, details: unknown) =>
  c.env.DB.prepare(
    'INSERT INTO audit_logs (id,company_id,user_id,action,entity_id,details,timestamp) VALUES (?,?,?,?,?,?,?)'
  ).bind(
    crypto.randomUUID(), c.get('user').company_id, c.get('user').sub,
    action, id, JSON.stringify(details), Date.now()
  );

// ─────────────────────────────────────────────────────────────────
// Factory export – same pattern as onboardingRouter / dailyCycle
// ─────────────────────────────────────────────────────────────────
export function batchRouter(authMiddleware: MiddlewareHandler<BatchEnv>) {
  const router = new Hono<BatchEnv>();
  router.use('*', authMiddleware);

  // ──────────────────────────────────────────────────────────────
  // POST /batches
  // Create a GRN (Goods Receipt Note) – record a new product batch.
  // Body: { productId, batchNo, expiryDate?, mfgDate?, rackBin?, receivedQuantity }
  // ──────────────────────────────────────────────────────────────
  router.post('/', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role))
      return bad(c, 'Permission denied: warehouse role required', 403);

    const body = await c.req.json<{
      productId: string;
      batchNo: string;
      expiryDate?: number;
      mfgDate?: number;
      rackBin?: string;
      receivedQuantity: number;
    }>();

    const { productId, batchNo, receivedQuantity } = body;
    if (!productId || typeof productId !== 'string') return bad(c, 'productId required');
    if (!batchNo || typeof batchNo !== 'string' || batchNo.length > 100)
      return bad(c, 'batchNo required (max 100 chars)');
    if (!Number.isInteger(receivedQuantity) || receivedQuantity < 1 || receivedQuantity > 100_000)
      return bad(c, 'receivedQuantity must be integer 1–100000');
    if (body.expiryDate !== undefined && !Number.isInteger(body.expiryDate))
      return bad(c, 'expiryDate must be Unix epoch integer');
    if (body.mfgDate !== undefined && !Number.isInteger(body.mfgDate))
      return bad(c, 'mfgDate must be Unix epoch integer');
    if (body.expiryDate && body.mfgDate && body.expiryDate < body.mfgDate)
      return bad(c, 'expiryDate must be after mfgDate');

    // Verify product belongs to this company
    const product = await c.env.DB.prepare(
      'SELECT id, name, stock_quantity, tracks_expiry FROM products WHERE id = ? AND company_id = ?'
    ).bind(productId, user.company_id).first<{ id: string; name: string; stock_quantity: number; tracks_expiry: number }>();
    if (!product) return bad(c, 'Product not found', 404);

    const batchId = crypto.randomUUID();
    const now = Date.now();

    // Atomically: create batch + increment product stock + audit
    const statements = [
      c.env.DB.prepare(
        `INSERT INTO product_batches
         (id, company_id, product_id, batch_no, mfg_date, expiry_date, rack_bin,
          received_quantity, remaining_quantity, committed_quantity, status,
          received_by, created_at, updated_at)
         VALUES (?,?,?,?,?,?,?,?,?,0,'ACTIVE',?,?,?)`
      ).bind(
        batchId, user.company_id, productId, batchNo,
        body.mfgDate ?? null, body.expiryDate ?? null, body.rackBin ?? null,
        receivedQuantity, receivedQuantity,
        user.sub, now, now
      ),
      // Update product total stock
      c.env.DB.prepare(
        'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?'
      ).bind(receivedQuantity, productId, user.company_id),
      // Audit the GRN
      audit(c, 'BATCH_GRN_CREATED', batchId, {
        productId, batchNo, receivedQuantity,
        expiryDate: body.expiryDate, rackBin: body.rackBin
      }),
    ];

    await c.env.DB.batch(statements);

    return c.json({
      id: batchId,
      productId,
      productName: product.name,
      batchNo,
      receivedQuantity,
      expiryDate: body.expiryDate ?? null,
      mfgDate: body.mfgDate ?? null,
      rackBin: body.rackBin ?? null,
      status: 'ACTIVE',
    }, 201);
  });

  // ──────────────────────────────────────────────────────────────
  // GET /batches?productId=<id>
  // List all ACTIVE batches for a product, sorted FEFO.
  // Also returns nearExpiry and blocked flags per company config.
  // ──────────────────────────────────────────────────────────────
  router.get('/', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role))
      return bad(c, 'Permission denied: warehouse role required', 403);

    const productId = c.req.query('productId');
    if (!productId) return bad(c, 'productId query param required');

    // Verify product is in company
    const product = await c.env.DB.prepare(
      'SELECT id, name, stock_quantity FROM products WHERE id = ? AND company_id = ?'
    ).bind(productId, user.company_id).first<{ id: string; name: string; stock_quantity: number }>();
    if (!product) return bad(c, 'Product not found', 404);

    // Fetch expiry alert thresholds (defaults if no row)
    const config = await c.env.DB.prepare(
      'SELECT warn_days, block_days FROM expiry_alert_config WHERE company_id = ?'
    ).bind(user.company_id).first<{ warn_days: number; block_days: number }>();
    const warnDays = config?.warn_days ?? 30;
    const blockDays = config?.block_days ?? 7;
    const nowSec = Math.floor(Date.now() / 1000);
    const warnCutoff = nowSec + warnDays * 86400;
    const blockCutoff = nowSec + blockDays * 86400;

    const { results } = await c.env.DB.prepare(
      `SELECT id, batch_no AS batchNo, mfg_date AS mfgDate, expiry_date AS expiryDate,
              rack_bin AS rackBin, received_quantity AS receivedQuantity,
              remaining_quantity AS remainingQuantity, committed_quantity AS committedQuantity,
              status, created_at AS createdAt
       FROM product_batches
       WHERE product_id = ? AND company_id = ? AND status = 'ACTIVE'
       ORDER BY expiry_date ASC NULLS LAST, created_at ASC`
    ).bind(productId, user.company_id).all<Record<string, unknown>>();

    const batches = results.map((b) => ({
      ...b,
      nearExpiry: b.expiryDate != null && (b.expiryDate as number) < warnCutoff,
      blocked: b.expiryDate != null && (b.expiryDate as number) < blockCutoff,
      available: (b.remainingQuantity as number) - (b.committedQuantity as number),
    }));

    return c.json({ product, batches, warnDays, blockDays });
  });

  // ──────────────────────────────────────────────────────────────
  // GET /batches/expiry-alerts
  // All batches expiring within warn_days across the whole company.
  // Used by owner/admin dashboard expiry widget.
  // ──────────────────────────────────────────────────────────────
  router.get('/expiry-alerts', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role) && user.role !== 'ADMIN')
      return bad(c, 'Permission denied', 403);

    const config = await c.env.DB.prepare(
      'SELECT warn_days, block_days FROM expiry_alert_config WHERE company_id = ?'
    ).bind(user.company_id).first<{ warn_days: number; block_days: number }>();
    const warnDays = config?.warn_days ?? 30;
    const blockDays = config?.block_days ?? 7;
    const nowSec = Math.floor(Date.now() / 1000);
    const warnCutoff = nowSec + warnDays * 86400;
    const blockCutoff = nowSec + blockDays * 86400;

    const { results } = await c.env.DB.prepare(
      `SELECT pb.id, pb.batch_no AS batchNo, pb.expiry_date AS expiryDate,
              pb.rack_bin AS rackBin, pb.remaining_quantity AS remainingQuantity,
              p.id AS productId, p.name AS productName
       FROM product_batches pb
       JOIN products p ON p.id = pb.product_id
       WHERE pb.company_id = ? AND pb.status = 'ACTIVE'
         AND pb.expiry_date IS NOT NULL AND pb.expiry_date < ?
       ORDER BY pb.expiry_date ASC`
    ).bind(user.company_id, warnCutoff).all<Record<string, unknown>>();

    const alerts = results.map((b) => ({
      ...b,
      blocked: (b.expiryDate as number) < blockCutoff,
    }));

    return c.json({ alerts, warnDays, blockDays, asOf: nowSec });
  });

  // ──────────────────────────────────────────────────────────────
  // PATCH /batches/:id
  // Update rack_bin or mark status RECALLED/EXPIRED manually.
  // ──────────────────────────────────────────────────────────────
  router.patch('/:id', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role))
      return bad(c, 'Permission denied: warehouse role required', 403);

    const batchId = c.req.param('id');
    const batch = await c.env.DB.prepare(
      'SELECT id, status, product_id FROM product_batches WHERE id = ? AND company_id = ?'
    ).bind(batchId, user.company_id).first<{ id: string; status: string; product_id: string }>();
    if (!batch) return bad(c, 'Batch not found', 404);

    const body = await c.req.json<{ rackBin?: string; status?: string }>();
    const validStatuses = ['ACTIVE', 'RECALLED', 'EXPIRED'];
    if (body.status && !validStatuses.includes(body.status))
      return bad(c, `status must be one of: ${validStatuses.join(', ')}`);

    const now = Date.now();
    await c.env.DB.batch([
      c.env.DB.prepare(
        'UPDATE product_batches SET rack_bin = COALESCE(?, rack_bin), status = COALESCE(?, status), updated_at = ? WHERE id = ? AND company_id = ?'
      ).bind(body.rackBin ?? null, body.status ?? null, now, batchId, user.company_id),
      audit(c, 'BATCH_UPDATED', batchId, body),
    ]);

    return c.json({ success: true, id: batchId });
  });

  // ──────────────────────────────────────────────────────────────
  // PUT /batches/alert-config
  // Set company expiry warning and block thresholds.
  // ──────────────────────────────────────────────────────────────
  router.put('/alert-config', async (c) => {
    const user = c.get('user');
    if (user.role !== 'OWNER' && user.role !== 'ADMIN')
      return bad(c, 'Permission denied: owner or admin role required', 403);

    const body = await c.req.json<{ warnDays?: number; blockDays?: number }>();
    const warnDays = body.warnDays ?? 30;
    const blockDays = body.blockDays ?? 7;
    if (!Number.isInteger(warnDays) || warnDays < 1 || warnDays > 365)
      return bad(c, 'warnDays must be integer 1–365');
    if (!Number.isInteger(blockDays) || blockDays < 0 || blockDays > warnDays)
      return bad(c, 'blockDays must be integer 0–warnDays');

    await c.env.DB.prepare(
      `INSERT INTO expiry_alert_config (company_id, warn_days, block_days)
       VALUES (?, ?, ?)
       ON CONFLICT(company_id) DO UPDATE SET warn_days = excluded.warn_days, block_days = excluded.block_days`
    ).bind(user.company_id, warnDays, blockDays).run();

    return c.json({ success: true, warnDays, blockDays });
  });

  return router;
}
