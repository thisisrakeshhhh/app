import { Hono, type Context, type MiddlewareHandler } from 'hono';

export type Actor = { sub: string; company_id: string; role: string; sid: string; name: string };
type WarehouseEnv = { Bindings: { DB: D1Database }; Variables: { user: Actor } };
type Ctx = Context<WarehouseEnv>;

const bad = (c: Ctx, error: string, status: 400 | 403 | 404 | 409 = 400) =>
  c.json({ error }, status);

const warehouseRoles = ['WAREHOUSE_MANAGER', 'OWNER', 'ADMIN'];

const audit = (c: Ctx, action: string, id: string, details: unknown) =>
  c.env.DB.prepare(
    'INSERT INTO audit_logs (id,company_id,user_id,action,entity_id,details,timestamp) VALUES (?,?,?,?,?,?,?)'
  ).bind(
    crypto.randomUUID(), c.get('user').company_id, c.get('user').sub,
    action, id, JSON.stringify(details), Date.now()
  );

export function warehouseRouter(authMiddleware: MiddlewareHandler<WarehouseEnv>) {
  const router = new Hono<WarehouseEnv>();
  router.use('*', authMiddleware);

  // ──────────────────────────────────────────────────────────────
  // 1. GET /warehouse/stock
  // Godown stock list with batch count, low stock, near expiry
  // ──────────────────────────────────────────────────────────────
  router.get('/stock', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const search = c.req.query('search')?.trim().toLowerCase() || '';
    const filter = c.req.query('filter') || 'ALL'; // ALL, LOW_STOCK, OUT_OF_STOCK, NEAR_EXPIRY, DAMAGED

    const nowSec = Math.floor(Date.now() / 1000);
    const warnCutoffSec = nowSec + 30 * 86400; // 30 days near expiry

    const { results } = await c.env.DB.prepare(
      `SELECT p.id, p.name, p.hindi_name AS hindiName, p.category,
              p.price_paise AS pricePaise, p.mrp_paise AS mrpPaise,
              p.stock_quantity AS stockQuantity, p.reserved_quantity AS reservedQuantity,
              p.unit, p.sku, p.barcode, p.image_url AS imageUrl,
              p.product_image_key AS productImageKey, p.tracks_expiry AS tracksExpiry,
              COALESCE((SELECT COUNT(*) FROM product_batches pb WHERE pb.product_id = p.id AND pb.company_id = p.company_id AND pb.status = 'ACTIVE' AND pb.remaining_quantity > 0), 0) AS batchCount,
              COALESCE((SELECT SUM(pb.damaged_quantity) FROM product_batches pb WHERE pb.product_id = p.id AND pb.company_id = p.company_id), 0) AS damagedQuantity,
              COALESCE((SELECT COUNT(*) FROM product_batches pb WHERE pb.product_id = p.id AND pb.company_id = p.company_id AND pb.status = 'ACTIVE' AND pb.expiry_date IS NOT NULL AND pb.expiry_date <= ? AND pb.remaining_quantity > 0), 0) AS nearExpiryBatchCount
       FROM products p
       WHERE p.company_id = ? AND p.is_active = 1
       ORDER BY p.name ASC`
    ).bind(warnCutoffSec, user.company_id).all<Record<string, unknown>>();

    let products = results.map((r: any) => {
      const stock = Number(r.stockQuantity) || 0;
      const reserved = Number(r.reservedQuantity) || 0;
      const available = Math.max(0, stock - reserved);
      const isLowStock = available > 0 && available < 10;
      const isOutOfStock = available <= 0;
      const isNearExpiry = Number(r.nearExpiryBatchCount) > 0;
      const damagedCount = Number(r.damagedQuantity) || 0;

      return {
        ...r,
        availableQuantity: available,
        isLowStock,
        isOutOfStock,
        isNearExpiry,
        damagedQuantity: damagedCount,
      };
    });

    if (search) {
      products = products.filter(
        (p: any) =>
          (p.name as string)?.toLowerCase().includes(search) ||
          (p.hindiName as string)?.toLowerCase().includes(search) ||
          (p.sku as string)?.toLowerCase().includes(search) ||
          (p.barcode as string)?.toLowerCase().includes(search) ||
          (p.category as string)?.toLowerCase().includes(search)
      );
    }


    if (filter === 'LOW_STOCK') {
      products = products.filter((p) => p.isLowStock);
    } else if (filter === 'OUT_OF_STOCK') {
      products = products.filter((p) => p.isOutOfStock);
    } else if (filter === 'NEAR_EXPIRY') {
      products = products.filter((p) => p.isNearExpiry);
    } else if (filter === 'DAMAGED') {
      products = products.filter((p) => p.damagedQuantity > 0);
    }

    return c.json({ products, total: products.length });
  });

  // ──────────────────────────────────────────────────────────────
  // 2. POST /warehouse/stock/adjust
  // Atomic stock adjustments with movement audit ledger
  // ──────────────────────────────────────────────────────────────
  router.post('/stock/adjust', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const body = await c.req.json<{
      productId: string;
      changeQuantity: number;
      reason: string;
      notes?: string;
      batchId?: string;
      idempotencyKey?: string;
    }>();

    const { productId, changeQuantity, reason } = body;
    if (!productId || typeof productId !== 'string') return bad(c, 'productId required');
    if (typeof changeQuantity !== 'number' || changeQuantity === 0 || !Number.isInteger(changeQuantity)) {
      return bad(c, 'changeQuantity must be non-zero integer');
    }

    const validReasons = [
      'INWARD_GRN',
      'AUDIT_CORRECTION',
      'DAMAGED',
      'EXPIRED',
      'RETURNED_TO_GODOWN',
      'MANUAL_CORRECTION',
      'STOCK_RECEIPT'
    ];
    if (!reason || !validReasons.includes(reason)) {
      return bad(c, `Invalid reason. Allowed: ${validReasons.join(', ')}`);
    }

    // Idempotency check if key provided
    const idempotencyKey = body.idempotencyKey;
    if (idempotencyKey) {
      const existingMovement = await c.env.DB.prepare(
        'SELECT id, stock_after FROM stock_movements WHERE company_id = ? AND notes LIKE ?'
      ).bind(user.company_id, `%[idemp:${idempotencyKey}]%`).first<{ id: string; stock_after: number }>();

      if (existingMovement) {
        return c.json({
          success: true,
          movementId: existingMovement.id,
          newStockQuantity: existingMovement.stock_after,
          idempotent: true,
        });
      }
    }

    // Fetch product before modification
    const product = await c.env.DB.prepare(
      'SELECT id, name, stock_quantity, reserved_quantity FROM products WHERE id = ? AND company_id = ?'
    ).bind(productId, user.company_id).first<{
      id: string;
      name: string;
      stock_quantity: number;
      reserved_quantity: number;
    }>();

    if (!product) return bad(c, 'Product not found', 404);

    const stockBefore = product.stock_quantity;
    const stockAfter = stockBefore + changeQuantity;

    if (stockAfter < 0) {
      return bad(c, `Stock cannot be negative. Current: ${stockBefore}, change: ${changeQuantity}`, 400);
    }
    if (stockAfter < product.reserved_quantity) {
      return bad(
        c,
        `Cannot reduce stock below reserved quantity (${product.reserved_quantity}). Available: ${stockBefore - product.reserved_quantity}`,
        400
      );
    }

    const movementId = crypto.randomUUID();
    const now = Date.now();
    const storedNotes = idempotencyKey
      ? `${body.notes || ''} [idemp:${idempotencyKey}]`.trim()
      : (body.notes || null);

    const statements = [
      // Atomic product stock update
      c.env.DB.prepare(
        `UPDATE products
         SET stock_quantity = stock_quantity + ?
         WHERE id = ? AND company_id = ? AND (stock_quantity + ?) >= reserved_quantity AND (stock_quantity + ?) >= 0`
      ).bind(changeQuantity, productId, user.company_id, changeQuantity, changeQuantity),

      // Stock movement audit entry
      c.env.DB.prepare(
        `INSERT INTO stock_movements
         (id, company_id, product_id, batch_id, movement_type, quantity, stock_before, stock_after, reason, notes, created_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(
        movementId,
        user.company_id,
        productId,
        body.batchId ?? null,
        reason,
        changeQuantity,
        stockBefore,
        stockAfter,
        reason,
        storedNotes,
        user.sub,
        now
      ),

      audit(c, 'STOCK_ADJUSTED', productId, {
        movementId,
        changeQuantity,
        stockBefore,
        stockAfter,
        reason,
        batchId: body.batchId
      })
    ];

    // If batchId is specified and marking damaged/expired, update the batch record
    if (body.batchId && (reason === 'DAMAGED' || reason === 'EXPIRED')) {
      const absDeduct = Math.abs(changeQuantity);
      statements.push(
        c.env.DB.prepare(
          `UPDATE product_batches
           SET remaining_quantity = max(0, remaining_quantity - ?),
               damaged_quantity = damaged_quantity + ?,
               updated_at = ?
           WHERE id = ? AND company_id = ?`
        ).bind(absDeduct, absDeduct, now, body.batchId, user.company_id)
      );
    }

    await c.env.DB.batch(statements);

    return c.json({
      success: true,
      movementId,
      productId,
      productName: product.name,
      stockBefore,
      newStockQuantity: stockAfter,
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 3. POST /warehouse/stock/audit
  // Physical audit count correction
  // ──────────────────────────────────────────────────────────────
  router.post('/stock/audit', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const body = await c.req.json<{
      productId: string;
      physicalCount: number;
      notes?: string;
    }>();

    const { productId, physicalCount } = body;
    if (!productId || typeof productId !== 'string') return bad(c, 'productId required');
    if (typeof physicalCount !== 'number' || physicalCount < 0 || !Number.isInteger(physicalCount)) {
      return bad(c, 'physicalCount must be non-negative integer');
    }

    const product = await c.env.DB.prepare(
      'SELECT id, name, stock_quantity, reserved_quantity FROM products WHERE id = ? AND company_id = ?'
    ).bind(productId, user.company_id).first<{
      id: string;
      name: string;
      stock_quantity: number;
      reserved_quantity: number;
    }>();

    if (!product) return bad(c, 'Product not found', 404);

    if (physicalCount < product.reserved_quantity) {
      return bad(
        c,
        `Physical count (${physicalCount}) cannot be lower than reserved order quantity (${product.reserved_quantity})`,
        400
      );
    }

    const difference = physicalCount - product.stock_quantity;
    if (difference === 0) {
      return c.json({
        success: true,
        message: 'Physical count matches recorded stock. No adjustment needed.',
        stockQuantity: physicalCount,
      });
    }

    const movementId = crypto.randomUUID();
    const now = Date.now();

    await c.env.DB.batch([
      c.env.DB.prepare(
        'UPDATE products SET stock_quantity = ? WHERE id = ? AND company_id = ?'
      ).bind(physicalCount, productId, user.company_id),
      c.env.DB.prepare(
        `INSERT INTO stock_movements
         (id, company_id, product_id, batch_id, movement_type, quantity, stock_before, stock_after, reason, notes, created_by, created_at)
         VALUES (?, ?, ?, NULL, 'AUDIT_CORRECTION', ?, ?, ?, 'AUDIT_CORRECTION', ?, ?, ?)`
      ).bind(
        movementId,
        user.company_id,
        productId,
        difference,
        product.stock_quantity,
        physicalCount,
        body.notes || 'Physical audit reconciliation',
        user.sub,
        now
      ),
      audit(c, 'STOCK_PHYSICAL_AUDIT', productId, {
        previousStock: product.stock_quantity,
        physicalCount,
        difference,
      })
    ]);

    return c.json({
      success: true,
      movementId,
      productId,
      previousStock: product.stock_quantity,
      newStockQuantity: physicalCount,
      difference,
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 4. GET /warehouse/stock/movements
  // History of stock movements (audited ledger)
  // ──────────────────────────────────────────────────────────────
  router.get('/stock/movements', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const productId = c.req.query('productId');
    const limit = Math.min(Number(c.req.query('limit')) || 50, 100);

    let query = `
      SELECT sm.id, sm.product_id AS productId, p.name AS productName,
             sm.batch_id AS batchId, sm.movement_type AS movementType,
             sm.quantity, sm.stock_before AS stockBefore, sm.stock_after AS stockAfter,
             sm.reason, sm.notes, sm.created_at AS createdAt,
             u.full_name AS createdByName
      FROM stock_movements sm
      JOIN products p ON p.id = sm.product_id
      LEFT JOIN users u ON u.id = sm.created_by
      WHERE sm.company_id = ?
    `;
    const params: unknown[] = [user.company_id];

    if (productId) {
      query += ' AND sm.product_id = ?';
      params.push(productId);
    }

    query += ' ORDER BY sm.created_at DESC LIMIT ?';
    params.push(limit);

    const { results } = await c.env.DB.prepare(query).bind(...params).all();
    return c.json(results);
  });

  // ──────────────────────────────────────────────────────────────
  // 5. GET /warehouse/picking-queue
  // Orders ready for picking/packing with FEFO batch suggestions
  // ──────────────────────────────────────────────────────────────
  router.get('/picking-queue', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const { results: orders } = await c.env.DB.prepare(
      `SELECT o.id, o.retailer_id AS retailerId, r.name AS retailerName, r.address AS retailerAddress,
              o.status, o.total_amount_paise AS totalAmountPaise, o.created_at AS createdAt,
              o.cartons_count AS cartonsCount, o.packing_notes AS packingNotes
       FROM orders o
       JOIN retailers r ON r.id = o.retailer_id
       WHERE o.company_id = ? AND o.status IN ('APPROVED', 'PICKING', 'PACKED')
       ORDER BY CASE o.status WHEN 'PICKING' THEN 1 WHEN 'APPROVED' THEN 2 WHEN 'PACKED' THEN 3 ELSE 4 END,
                o.created_at ASC`
    ).bind(user.company_id).all<Record<string, unknown>>();

    if (orders.length === 0) {
      return c.json({ orders: [] });
    }

    const orderIds = orders.map((o) => o.id as string);
    const placeholders = orderIds.map(() => '?').join(',');

    const { results: items } = await c.env.DB.prepare(
      `SELECT oi.id, oi.order_id AS orderId, oi.product_id AS productId,
              p.name AS productName, p.hindi_name AS hindiName, p.sku, p.barcode,
              p.image_url AS imageUrl, p.stock_quantity AS availableStock,
              oi.quantity, oi.free_quantity AS freeQuantity, oi.is_picked AS isPicked
       FROM order_items oi
       JOIN products p ON p.id = oi.product_id
       WHERE oi.order_id IN (${placeholders})`
    ).bind(...orderIds).all<Record<string, unknown>>();

    // Fetch FEFO batches for products in these orders
    const productIds = Array.from(new Set(items.map((i) => i.productId as string)));
    let batchesByProduct: Record<string, any[]> = {};

    if (productIds.length > 0) {
      const prodPlaceholders = productIds.map(() => '?').join(',');
      const { results: batches } = await c.env.DB.prepare(
        `SELECT id, product_id AS productId, batch_no AS batchNo, rack_bin AS rackBin,
                expiry_date AS expiryDate, remaining_quantity AS remainingQuantity
         FROM product_batches
         WHERE company_id = ? AND product_id IN (${prodPlaceholders}) AND status = 'ACTIVE' AND remaining_quantity > 0
         ORDER BY expiry_date ASC NULLS LAST, created_at ASC`
      ).bind(user.company_id, ...productIds).all<Record<string, unknown>>();

      for (const b of batches) {
        const pId = b.productId as string;
        if (!batchesByProduct[pId]) batchesByProduct[pId] = [];
        batchesByProduct[pId].push(b);
      }
    }

    const enrichedOrders = orders.map((ord) => {
      const orderItems = items
        .filter((i) => i.orderId === ord.id)
        .map((i) => {
          const suggestedBatch = batchesByProduct[i.productId as string]?.[0] || null;
          return {
            ...i,
            isPicked: Boolean(i.isPicked),
            suggestedBatch: suggestedBatch
              ? {
                  id: suggestedBatch.id,
                  batchNo: suggestedBatch.batchNo,
                  rackBin: suggestedBatch.rackBin,
                  expiryDate: suggestedBatch.expiryDate,
                  remainingQuantity: suggestedBatch.remainingQuantity,
                }
              : null,
          };
        });

      const allPicked = orderItems.length > 0 && orderItems.every((i) => i.isPicked);

      return {
        ...ord,
        items: orderItems,
        allPicked,
      };
    });

    return c.json({ orders: enrichedOrders });
  });

  // ──────────────────────────────────────────────────────────────
  // POST /warehouse/orders/:id/start-picking
  // ──────────────────────────────────────────────────────────────
  router.post('/orders/:id/start-picking', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const orderId = c.req.param('id');
    const order = await c.env.DB.prepare('SELECT status FROM orders WHERE id = ? AND company_id = ?')
      .bind(orderId, user.company_id).first<{ status: string }>();

    if (!order) return bad(c, 'Order not found', 404);
    if (order.status === 'PICKING') return c.json({ success: true, idempotent: true, status: 'PICKING' });
    if (order.status !== 'APPROVED') return bad(c, `Cannot start picking for order with status ${order.status}`, 400);

    const now = Date.now();
    await c.env.DB.batch([
      c.env.DB.prepare('UPDATE orders SET status = ?, updated_at = ? WHERE id = ? AND status = ?')
        .bind('PICKING', now, orderId, 'APPROVED'),
      audit(c, 'ORDER_PICKING_STARTED', orderId, 'Picking started')
    ]);

    return c.json({ success: true, status: 'PICKING' });
  });

  // ──────────────────────────────────────────────────────────────
  // 6. POST /warehouse/orders/:id/scan-pick
  // Scan barcode to verify and pick item in order
  // ──────────────────────────────────────────────────────────────
  router.post('/orders/:id/scan-pick', async (c) => {

    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const orderId = c.req.param('id');
    const body = await c.req.json<{
      barcode?: string;
      productId?: string;
      batchId?: string;
    }>();

    const { barcode, productId } = body;
    if (!barcode && !productId) {
      return bad(c, 'Either barcode or productId is required for scan-pick');
    }

    // Verify order exists and is in APPROVED or PICKING
    const order = await c.env.DB.prepare(
      'SELECT id, status FROM orders WHERE id = ? AND company_id = ?'
    ).bind(orderId, user.company_id).first<{ id: string; status: string }>();

    if (!order) return bad(c, 'Order not found', 404);
    if (order.status !== 'APPROVED' && order.status !== 'PICKING') {
      return bad(c, `Order in status ${order.status} cannot be picked`, 400);
    }

    // Resolve product by barcode or productId
    let matchedProductId = productId;
    if (barcode) {
      const prod = await c.env.DB.prepare(
        'SELECT id, name FROM products WHERE company_id = ? AND (barcode = ? OR sku = ?)'
      ).bind(user.company_id, barcode, barcode).first<{ id: string; name: string }>();

      if (!prod) {
        return bad(c, `No product matches barcode: ${barcode}`, 404);
      }
      matchedProductId = prod.id;
    }

    // Check if matched product belongs to this order
    const orderItem = await c.env.DB.prepare(
      'SELECT id, quantity, is_picked FROM order_items WHERE order_id = ? AND product_id = ?'
    ).bind(orderId, matchedProductId).first<{ id: string; quantity: number; is_picked: number }>();

    if (!orderItem) {
      return bad(c, 'Scanned product does not belong to this order!', 400);
    }

    const now = Date.now();
    const statements = [
      c.env.DB.prepare(
        'UPDATE order_items SET is_picked = 1, batch_id = COALESCE(?, batch_id) WHERE order_id = ? AND product_id = ?'
      ).bind(body.batchId ?? null, orderId, matchedProductId),
    ];

    if (order.status === 'APPROVED') {
      statements.push(
        c.env.DB.prepare('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?')
          .bind('PICKING', now, orderId)
      );
    }

    await c.env.DB.batch(statements);

    return c.json({
      success: true,
      orderId,
      productId: matchedProductId,
      isPicked: true,
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 7. POST /warehouse/orders/:id/mark-packed
  // Pack order with cartons count and notes
  // ──────────────────────────────────────────────────────────────
  router.post('/orders/:id/mark-packed', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const orderId = c.req.param('id');
    const body = await c.req.json<{
      cartonsCount?: number;
      packagePhotoUrl?: string;
      packageWeightGrams?: number;
      packingNotes?: string;
    }>();

    const order = await c.env.DB.prepare(
      'SELECT id, status FROM orders WHERE id = ? AND company_id = ?'
    ).bind(orderId, user.company_id).first<{ id: string; status: string }>();

    if (!order) return bad(c, 'Order not found', 404);
    if (order.status === 'PACKED') {
      return c.json({ success: true, idempotent: true });
    }
    if (order.status !== 'PICKING' && order.status !== 'APPROVED') {
      return bad(c, `Order in status ${order.status} cannot be packed`, 400);
    }

    // Verify all items are picked
    const unpicked = await c.env.DB.prepare(
      'SELECT count(*) AS count FROM order_items WHERE order_id = ? AND is_picked = 0'
    ).bind(orderId).first<{ count: number }>();

    if (unpicked && unpicked.count > 0) {
      return bad(c, `Cannot pack order: ${unpicked.count} item(s) not yet picked`, 400);
    }

    const cartonsCount = Math.max(1, body.cartonsCount || 1);
    const now = Date.now();

    const statements = [
      c.env.DB.prepare(
        `UPDATE orders
         SET status = 'PACKED',
             cartons_count = ?,
             package_photo_url = ?,
             package_weight_grams = ?,
             packing_notes = ?,
             updated_at = ?
         WHERE id = ?`
      ).bind(
        cartonsCount,
        body.packagePhotoUrl ?? null,
        body.packageWeightGrams ?? null,
        body.packingNotes ?? null,
        now,
        orderId
      ),
      audit(c, 'ORDER_PACKED', orderId, {
        cartonsCount,
        weightGrams: body.packageWeightGrams,
        notes: body.packingNotes,
      })
    ];

    await c.env.DB.batch(statements);

    return c.json({
      success: true,
      orderId,
      status: 'PACKED',
      cartonsCount,
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 8. POST /warehouse/dispatch-batches
  // Group packed orders into a dispatch batch
  // ──────────────────────────────────────────────────────────────
  router.post('/dispatch-batches', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse role required', 403);
    }

    const body = await c.req.json<{
      orderIds: string[];
      deliveryExecutiveId?: string;
      routeId?: string;
      notes?: string;
    }>();

    const { orderIds } = body;
    if (!Array.isArray(orderIds) || orderIds.length === 0) {
      return bad(c, 'orderIds array required with at least 1 order');
    }

    // Verify orders are in PACKED status
    const placeholders = orderIds.map(() => '?').join(',');
    const { results: orders } = await c.env.DB.prepare(
      `SELECT id, status, cartons_count FROM orders WHERE company_id = ? AND id IN (${placeholders})`
    ).bind(user.company_id, ...orderIds).all<{ id: string; status: string; cartons_count: number }>();

    if (orders.length !== orderIds.length) {
      return bad(c, 'One or more order IDs are invalid or belong to another company', 400);
    }

    const notPacked = orders.filter((o) => o.status !== 'PACKED');
    if (notPacked.length > 0) {
      return bad(c, `All orders must be PACKED before batching. Invalid: ${notPacked.map((o) => o.id).join(', ')}`, 400);
    }

    // Calculate total cartons
    let totalCartons = 0;
    for (const ord of orders) {
      totalCartons += ord.cartons_count || 1;
    }

    const batchId = crypto.randomUUID();
    const batchYear = new Date().getFullYear();
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const batchCode = `DSP-${batchYear}-${randomSuffix}`;
    const now = Date.now();

    const statements = [
      c.env.DB.prepare(
        `INSERT INTO dispatch_batches
         (id, company_id, batch_code, delivery_executive_id, route_id, status, total_orders, total_cartons, created_by, notes, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(
        batchId,
        user.company_id,
        batchCode,
        body.deliveryExecutiveId ?? null,
        body.routeId ?? null,
        body.deliveryExecutiveId ? 'ASSIGNED' : 'CREATED',
        orderIds.length,
        totalCartons,
        user.sub,
        body.notes ?? null,
        now,
        now
      )
    ];

    for (const ord of orders) {
      statements.push(
        c.env.DB.prepare(
          `INSERT INTO dispatch_batch_orders (dispatch_batch_id, order_id, cartons_count, created_at)
           VALUES (?, ?, ?, ?)`
        ).bind(batchId, ord.id, ord.cartons_count || 1, now),
        c.env.DB.prepare(
          'UPDATE orders SET dispatch_batch_id = ? WHERE id = ?'
        ).bind(batchId, ord.id)
      );
    }

    statements.push(
      audit(c, 'DISPATCH_BATCH_CREATED', batchId, {
        batchCode,
        orderCount: orderIds.length,
        totalCartons,
        deliveryExecutiveId: body.deliveryExecutiveId,
      })
    );

    await c.env.DB.batch(statements);

    return c.json({
      id: batchId,
      batchCode,
      totalOrders: orderIds.length,
      totalCartons,
      deliveryExecutiveId: body.deliveryExecutiveId ?? null,
      status: body.deliveryExecutiveId ? 'ASSIGNED' : 'CREATED',
    }, 201);
  });

  // ──────────────────────────────────────────────────────────────
  // 9. GET /warehouse/dispatch-batches
  // List dispatch batches
  // ──────────────────────────────────────────────────────────────
  router.get('/dispatch-batches', async (c) => {
    const user = c.get('user');
    // Allow delivery executives to see batches assigned to them
    const isWarehouseOrAdmin = warehouseRoles.includes(user.role);
    const isDelivery = user.role === 'DELIVERY_EXECUTIVE';

    if (!isWarehouseOrAdmin && !isDelivery) {
      return bad(c, 'Permission denied', 403);
    }

    let query = `
      SELECT db.id, db.batch_code AS batchCode, db.delivery_executive_id AS deliveryExecutiveId,
             u.full_name AS deliveryExecutiveName, db.route_id AS routeId, db.status,
             db.total_orders AS totalOrders, db.total_cartons AS totalCartons,
             db.notes, db.handed_over_at AS handedOverAt, db.created_at AS createdAt
      FROM dispatch_batches db
      LEFT JOIN users u ON u.id = db.delivery_executive_id
      WHERE db.company_id = ?
    `;
    const params: unknown[] = [user.company_id];

    if (isDelivery) {
      query += ' AND db.delivery_executive_id = ?';
      params.push(user.sub);
    }

    query += ' ORDER BY db.created_at DESC LIMIT 50';

    const { results } = await c.env.DB.prepare(query).bind(...params).all<Record<string, unknown>>();
    return c.json(results);
  });

  // ──────────────────────────────────────────────────────────────
  // 10. POST /warehouse/dispatch-batches/:id/assign-driver
  // ──────────────────────────────────────────────────────────────
  router.post('/dispatch-batches/:id/assign-driver', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied', 403);
    }

    const batchId = c.req.param('id');
    const body = await c.req.json<{ deliveryExecutiveId: string }>();

    if (!body.deliveryExecutiveId) return bad(c, 'deliveryExecutiveId required');

    // Verify driver exists
    const driver = await c.env.DB.prepare(
      "SELECT id, full_name FROM users WHERE id = ? AND company_id = ? AND role = 'DELIVERY_EXECUTIVE' AND is_active = 1"
    ).bind(body.deliveryExecutiveId, user.company_id).first<{ id: string; full_name: string }>();

    if (!driver) return bad(c, 'Delivery executive invalid or inactive', 400);

    const now = Date.now();
    await c.env.DB.batch([
      c.env.DB.prepare(
        "UPDATE dispatch_batches SET delivery_executive_id = ?, status = 'ASSIGNED', updated_at = ? WHERE id = ? AND company_id = ?"
      ).bind(body.deliveryExecutiveId, now, batchId, user.company_id),
      audit(c, 'DISPATCH_BATCH_DRIVER_ASSIGNED', batchId, {
        driverId: driver.id,
        driverName: driver.full_name,
      })
    ]);

    return c.json({ success: true, batchId, driverName: driver.full_name });
  });

  // ──────────────────────────────────────────────────────────────
  // 11. POST /warehouse/dispatch-batches/:id/handover
  // Handover batch to delivery executive -> marks orders OUT_FOR_DELIVERY
  // ──────────────────────────────────────────────────────────────
  router.post('/dispatch-batches/:id/handover', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied', 403);
    }

    const batchId = c.req.param('id');
    const batch = await c.env.DB.prepare(
      'SELECT id, batch_code, delivery_executive_id, status FROM dispatch_batches WHERE id = ? AND company_id = ?'
    ).bind(batchId, user.company_id).first<{
      id: string;
      batch_code: string;
      delivery_executive_id: string | null;
      status: string;
    }>();

    if (!batch) return bad(c, 'Dispatch batch not found', 404);
    if (!batch.delivery_executive_id) {
      return bad(c, 'Cannot handover: No delivery executive assigned to this batch', 400);
    }

    const { results: batchOrders } = await c.env.DB.prepare(
      'SELECT order_id FROM dispatch_batch_orders WHERE dispatch_batch_id = ?'
    ).bind(batchId).all<{ order_id: string }>();

    const now = Date.now();
    const statements = [
      c.env.DB.prepare(
        "UPDATE dispatch_batches SET status = 'HANDED_OVER', handed_over_at = ?, updated_at = ? WHERE id = ?"
      ).bind(now, now, batchId),
    ];

    for (const bo of batchOrders) {
      statements.push(
        c.env.DB.prepare(
          "UPDATE orders SET status = 'OUT_FOR_DELIVERY', delivery_employee_id = ?, updated_at = ? WHERE id = ? AND status = 'PACKED'"
        ).bind(batch.delivery_executive_id, now, bo.order_id)
      );
    }

    statements.push(
      audit(c, 'DISPATCH_BATCH_HANDOVER', batchId, {
        batchCode: batch.batch_code,
        deliveryExecutiveId: batch.delivery_executive_id,
        orderCount: batchOrders.length,
      })
    );

    await c.env.DB.batch(statements);

    return c.json({
      success: true,
      batchId,
      status: 'HANDED_OVER',
      handedOverOrdersCount: batchOrders.length,
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 12. GET /warehouse/returns
  // List return items awaiting godown inspection
  // ──────────────────────────────────────────────────────────────
  router.get('/returns', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied', 403);
    }

    // Fetch undelivered items and customer return requests
    const { results: undelivered } = await c.env.DB.prepare(
      `SELECT u.id, u.order_id AS orderId, u.product_id AS productId, p.name AS productName,
              u.quantity, u.driver_id AS driverId, usr.full_name AS driverName,
              u.status, u.reason, u.created_at AS createdAt
       FROM undelivered_goods u
       JOIN products p ON p.id = u.product_id
       JOIN users usr ON usr.id = u.driver_id
       WHERE u.company_id = ? AND u.status IN ('HELD_BY_DRIVER', 'RETURNED_TO_WAREHOUSE')
       ORDER BY u.created_at DESC LIMIT 50`
    ).bind(user.company_id).all<Record<string, unknown>>();

    const { results: inspections } = await c.env.DB.prepare(
      `SELECT wri.id, wri.order_id AS orderId, wri.product_id AS productId,
              p.name AS productName, wri.quantity, wri.condition,
              wri.action_taken AS actionTaken, wri.photo_url AS photoUrl,
              wri.notes, wri.created_at AS createdAt, u.full_name AS inspectedByName
       FROM warehouse_return_inspections wri
       JOIN products p ON p.id = wri.product_id
       LEFT JOIN users u ON u.id = wri.inspected_by
       WHERE wri.company_id = ?
       ORDER BY wri.created_at DESC LIMIT 50`
    ).bind(user.company_id).all<Record<string, unknown>>();

    return c.json({
      pendingUndelivered: undelivered,
      inspectionsHistory: inspections,
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 13. POST /warehouse/returns/inspect
  // Inspect returned goods: Restock if saleable, block if damaged/expired
  // ──────────────────────────────────────────────────────────────
  router.post('/returns/inspect', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied', 403);
    }

    const body = await c.req.json<{
      returnId?: string;
      orderId?: string;
      retailerId?: string;
      productId: string;
      quantity: number;
      condition: 'SALEABLE' | 'DAMAGED' | 'EXPIRED' | 'MISSING';
      photoUrl?: string;
      notes?: string;
    }>();

    const { productId, quantity, condition } = body;
    if (!productId) return bad(c, 'productId required');
    if (!Number.isInteger(quantity) || quantity <= 0) return bad(c, 'quantity must be positive integer');

    const validConditions = ['SALEABLE', 'DAMAGED', 'EXPIRED', 'MISSING'];
    if (!validConditions.includes(condition)) {
      return bad(c, `condition must be one of: ${validConditions.join(', ')}`);
    }

    const product = await c.env.DB.prepare(
      'SELECT id, name, stock_quantity FROM products WHERE id = ? AND company_id = ?'
    ).bind(productId, user.company_id).first<{ id: string; name: string; stock_quantity: number }>();

    if (!product) return bad(c, 'Product not found', 404);

    const inspectionId = crypto.randomUUID();
    const movementId = crypto.randomUUID();
    const now = Date.now();

    const isSaleable = condition === 'SALEABLE';
    const actionTaken = isSaleable
      ? 'RESTOCKED_TO_GODOWN'
      : (condition === 'MISSING' ? 'DISCARDED' : 'BLOCKED_DAMAGED');

    const statements = [
      c.env.DB.prepare(
        `INSERT INTO warehouse_return_inspections
         (id, company_id, return_id, order_id, retailer_id, product_id, quantity, condition, photo_url, action_taken, notes, inspected_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(
        inspectionId,
        user.company_id,
        body.returnId ?? null,
        body.orderId ?? null,
        body.retailerId ?? null,
        productId,
        quantity,
        condition,
        body.photoUrl ?? null,
        actionTaken,
        body.notes ?? null,
        user.sub,
        now
      )
    ];

    if (isSaleable) {
      // Restock to available physical stock
      statements.push(
        c.env.DB.prepare(
          'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?'
        ).bind(quantity, productId, user.company_id),
        c.env.DB.prepare(
          `INSERT INTO stock_movements
           (id, company_id, product_id, batch_id, movement_type, quantity, stock_before, stock_after, reason, notes, created_by, created_at)
           VALUES (?, ?, ?, NULL, 'RETURNED_TO_GODOWN', ?, ?, ?, 'RETURNED_TO_GODOWN', ?, ?, ?)`
        ).bind(
          movementId,
          user.company_id,
          productId,
          quantity,
          product.stock_quantity,
          product.stock_quantity + quantity,
          body.notes || 'Saleable return restocked to godown',
          user.sub,
          now
        )
      );
    } else {
      // Record damage in stock movements for audit
      statements.push(
        c.env.DB.prepare(
          `INSERT INTO stock_movements
           (id, company_id, product_id, batch_id, movement_type, quantity, stock_before, stock_after, reason, notes, created_by, created_at)
           VALUES (?, ?, ?, NULL, ?, 0, ?, ?, ?, ?, ?, ?)`
        ).bind(
          movementId,
          user.company_id,
          productId,
          condition,
          product.stock_quantity,
          product.stock_quantity,
          `Return inspected as ${condition}. Not added to saleable stock.`,
          body.notes || null,
          user.sub,
          now
        )
      );
    }

    statements.push(
      audit(c, 'RETURN_INSPECTED', inspectionId, {
        productId,
        productName: product.name,
        quantity,
        condition,
        actionTaken,
      })
    );

    await c.env.DB.batch(statements);

    return c.json({
      success: true,
      inspectionId,
      actionTaken,
      condition,
      restocked: isSaleable,
      newStockQuantity: isSaleable ? product.stock_quantity + quantity : product.stock_quantity,
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 14. GET /warehouse/batches
  // List batches with FEFO sorting
  // ──────────────────────────────────────────────────────────────
  router.get('/batches', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied', 403);
    }

    const productId = c.req.query('productId');
    let query = `
      SELECT pb.id, pb.company_id AS companyId, pb.product_id AS productId,
             p.name AS productName, pb.batch_no AS batchNo, pb.batch_no AS batchNumber,
             pb.mfg_date AS mfgDate, pb.expiry_date AS expiryDate,
             pb.rack_bin AS rackBin, pb.received_quantity AS receivedQuantity,
             pb.remaining_quantity AS remainingQuantity, pb.remaining_quantity AS quantity,
             pb.committed_quantity AS committedQuantity, pb.committed_quantity AS reservedQuantity,
             pb.damaged_quantity AS damagedQuantity, pb.purchase_price_paise AS purchasePricePaise,
             pb.supplier_name AS supplierName, pb.status, pb.created_at AS createdAt
      FROM product_batches pb
      JOIN products p ON p.id = pb.product_id
      WHERE pb.company_id = ?
    `;
    const params: unknown[] = [user.company_id];

    if (productId) {
      query += ' AND pb.product_id = ?';
      params.push(productId);
    }

    query += ' ORDER BY pb.expiry_date ASC NULLS LAST, pb.created_at ASC';

    const { results } = await c.env.DB.prepare(query).bind(...params).all();
    return c.json(results);
  });

  // ──────────────────────────────────────────────────────────────
  // 15. POST /warehouse/batches
  // Create inward batch (GRN)
  // ──────────────────────────────────────────────────────────────
  router.post('/batches', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied', 403);
    }

    const body = await c.req.json<{
      productId: string;
      batchNo?: string;
      batchNumber?: string;
      expiryDate?: number;
      mfgDate?: number;
      rackBin?: string;
      receivedQuantity?: number;
      quantity?: number;
      purchasePricePaise?: number;
      supplierName?: string;
    }>();

    const productId = body.productId;
    const batchNo = body.batchNo || body.batchNumber;
    const quantity = body.receivedQuantity ?? body.quantity;

    if (!productId || typeof productId !== 'string') return bad(c, 'productId required');
    if (!batchNo || typeof batchNo !== 'string') return bad(c, 'batchNo required');
    if (!Number.isInteger(quantity) || !quantity || quantity < 1) {
      return bad(c, 'quantity must be positive integer');
    }

    const product = await c.env.DB.prepare(
      'SELECT id, name, stock_quantity FROM products WHERE id = ? AND company_id = ?'
    ).bind(productId, user.company_id).first<{ id: string; name: string; stock_quantity: number }>();

    if (!product) return bad(c, 'Product not found', 404);

    const batchId = crypto.randomUUID();
    const movementId = crypto.randomUUID();
    const now = Date.now();

    const statements = [
      c.env.DB.prepare(
        `INSERT INTO product_batches
         (id, company_id, product_id, batch_no, mfg_date, expiry_date, rack_bin,
          received_quantity, remaining_quantity, committed_quantity, damaged_quantity,
          purchase_price_paise, supplier_name, status, received_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, 'ACTIVE', ?, ?, ?)`
      ).bind(
        batchId,
        user.company_id,
        productId,
        batchNo,
        body.mfgDate ?? null,
        body.expiryDate ?? null,
        body.rackBin ?? null,
        quantity,
        quantity,
        body.purchasePricePaise ?? null,
        body.supplierName ?? null,
        user.sub,
        now,
        now
      ),
      c.env.DB.prepare(
        'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?'
      ).bind(quantity, productId, user.company_id),
      c.env.DB.prepare(
        `INSERT INTO stock_movements
         (id, company_id, product_id, batch_id, movement_type, quantity, stock_before, stock_after, reason, notes, created_by, created_at)
         VALUES (?, ?, ?, ?, 'INWARD_GRN', ?, ?, ?, 'INWARD_GRN', ?, ?, ?)`
      ).bind(
        movementId,
        user.company_id,
        productId,
        batchId,
        quantity,
        product.stock_quantity,
        product.stock_quantity + quantity,
        `Batch ${batchNo} received`,
        user.sub,
        now
      ),
      audit(c, 'BATCH_GRN_CREATED', batchId, {
        productId,
        batchNo,
        quantity,
        expiryDate: body.expiryDate,
        supplier: body.supplierName,
      })
    ];

    await c.env.DB.batch(statements);

    return c.json({
      id: batchId,
      productId,
      productName: product.name,
      batchNo,
      quantity,
      newStockQuantity: product.stock_quantity + quantity,
      status: 'ACTIVE',
    }, 201);
  });

  // ──────────────────────────────────────────────────────────────
  // 16. PUT /warehouse/batches/:id
  // ──────────────────────────────────────────────────────────────
  router.put('/batches/:id', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied', 403);
    }

    const batchId = c.req.param('id');
    const body = await c.req.json<{
      rackBin?: string;
      status?: string;
      damagedQuantity?: number;
    }>();

    const existing = await c.env.DB.prepare(
      'SELECT id, status FROM product_batches WHERE id = ? AND company_id = ?'
    ).bind(batchId, user.company_id).first<{ id: string; status: string }>();

    if (!existing) return bad(c, 'Batch not found', 404);

    const now = Date.now();
    await c.env.DB.batch([
      c.env.DB.prepare(
        `UPDATE product_batches
         SET rack_bin = COALESCE(?, rack_bin),
             status = COALESCE(?, status),
             damaged_quantity = COALESCE(?, damaged_quantity),
             updated_at = ?
         WHERE id = ? AND company_id = ?`
      ).bind(
        body.rackBin ?? null,
        body.status ?? null,
        body.damagedQuantity ?? null,
        now,
        batchId,
        user.company_id
      ),
      audit(c, 'BATCH_UPDATED', batchId, body)
    ]);

    return c.json({ success: true, id: batchId });
  });

  // ──────────────────────────────────────────────────────────────
  // 17. GET /warehouse/batches/near-expiry
  // ──────────────────────────────────────────────────────────────
  router.get('/batches/near-expiry', async (c) => {
    const user = c.get('user');
    if (!warehouseRoles.includes(user.role)) {
      return bad(c, 'Permission denied', 403);
    }

    const nowSec = Math.floor(Date.now() / 1000);
    const warnCutoffSec = nowSec + 30 * 86400;

    const { results } = await c.env.DB.prepare(
      `SELECT pb.id, pb.product_id AS productId, p.name AS productName,
              pb.batch_no AS batchNo, pb.expiry_date AS expiryDate,
              pb.remaining_quantity AS remainingQuantity, pb.rack_bin AS rackBin,
              pb.status
       FROM product_batches pb
       JOIN products p ON p.id = pb.product_id
       WHERE pb.company_id = ? AND pb.status = 'ACTIVE'
         AND pb.expiry_date IS NOT NULL AND pb.expiry_date <= ?
         AND pb.remaining_quantity > 0
       ORDER BY pb.expiry_date ASC`
    ).bind(user.company_id, warnCutoffSec).all();

    return c.json(results);
  });

  return router;
}

