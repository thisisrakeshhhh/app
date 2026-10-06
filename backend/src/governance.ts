import { Hono, type MiddlewareHandler } from 'hono';
import { requestIp } from './security';
import bcrypt from 'bcryptjs';

type GovEnv = {
  Bindings: {
    DB: D1Database;
    JWT_SECRET: string;
    ENVIRONMENT?: string;
  };
  Variables: {
    user: {
      sub: string;
      sid: string;
      company_id: string;
      role: string;
      name: string;
    };
  };
};

export function governanceRouter(auth: MiddlewareHandler<GovEnv>) {
  const router = new Hono<GovEnv>();

  // ── Helper: Record detailed audit log ──────────────────────────────────────
  const recordAudit = async (
    c: any,
    action: string,
    entityId: string | null,
    details: string,
    companyId?: string,
    userId?: string,
    role?: string
  ) => {
    const db = c.env.DB as D1Database;
    const u = c.get('user');
    const compId = companyId || u?.company_id || 'UNKNOWN';
    const usrId = userId || u?.sub || 'SYSTEM';
    const r = role || u?.role || 'UNKNOWN';
    const ip = requestIp(c);
    const deviceId = c.req.header('X-Device-Id') || c.req.header('User-Agent') || 'UNKNOWN';
    const now = Date.now();

    await db.prepare(
      `INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp, role, device_id, ip_address)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(crypto.randomUUID(), compId, usrId, action, entityId, details, now, r, deviceId, ip).run().catch((e) => {
      console.error('Failed to write audit log:', e);
    });
  };

  // ── 1. Company Onboarding Wizard (Multi-entity atomic setup) ─────────────
  router.post('/onboarding/wizard-setup', auth, async (c) => {
    const user = c.get('user');
    if (!user || user.role !== 'OWNER') {
      return c.json({ error: 'Permission denied: Only business Owner can run onboarding wizard' }, 403);
    }

    const body = await c.req.json().catch(() => ({}));
    const { company, warehouse, employees, beats, products, retailers } = body;

    const db = c.env.DB as D1Database;
    const now = Date.now();
    const statements: any[] = [];

    // 1.1 Update Company Profile
    if (company && company.name) {
      statements.push(
        db.prepare('UPDATE companies SET name = ? WHERE id = ?').bind(company.name.trim(), user.company_id)
      );
    }

    // 1.2 Setup Beats
    if (Array.isArray(beats)) {
      for (const beat of beats) {
        if (!beat.name) continue;
        const beatId = beat.id || `beat_${crypto.randomUUID().replace(/-/g, '').slice(0, 8)}`;
        statements.push(
          db.prepare(
            'INSERT OR REPLACE INTO beats (id, company_id, name, description, is_active, created_at) VALUES (?, ?, ?, ?, 1, ?)'
          ).bind(beatId, user.company_id, beat.name.trim(), beat.area || beat.description || null, now)
        );
      }
    }

    // 1.3 Setup Employees
    if (Array.isArray(employees)) {
      for (const emp of employees) {
        if (!emp.username || !emp.fullName || !emp.role) continue;
        const empId = `user_${crypto.randomUUID().replace(/-/g, '').slice(0, 8)}`;
        const salt = bcrypt.genSaltSync(10);
        const passHash = bcrypt.hashSync(emp.password || 'RouteFlow@2026!', salt);
        statements.push(
          db.prepare(
            `INSERT OR IGNORE INTO users (id, company_id, username, password_hash, full_name, role, is_active, status, phone_number, created_at)
             VALUES (?, ?, ?, ?, ?, ?, 1, 'ACTIVE', ?, ?)`
          ).bind(empId, user.company_id, emp.username.trim().toLowerCase(), passHash, emp.fullName.trim(), emp.role, emp.phone || null, now)
        );
      }
    }

    // 1.4 Setup Products & Opening Stock
    if (Array.isArray(products)) {
      for (const prod of products) {
        if (!prod.name || !prod.pricePaise) continue;
        const prodId = prod.id || `prod_${crypto.randomUUID().replace(/-/g, '').slice(0, 8)}`;
        const openingStock = parseInt(prod.openingStock || 0, 10);
        statements.push(
          db.prepare(
            `INSERT OR REPLACE INTO products (id, company_id, name, sku, price_paise, stock_quantity, unit, category, is_active, tracks_expiry)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)`
          ).bind(
            prodId,
            user.company_id,
            prod.name.trim(),
            prod.sku || `SKU-${prod.name.slice(0, 4).toUpperCase()}`,
            Math.round(prod.pricePaise),
            openingStock,
            prod.unit || 'Pack',
            prod.category || 'General',
            prod.tracksExpiry ? 1 : 0
          )
        );
      }
    }

    // 1.5 Setup Retailers & Opening Balances
    if (Array.isArray(retailers)) {
      for (const ret of retailers) {
        if (!ret.name) continue;
        const retId = ret.id || `ret_${crypto.randomUUID().replace(/-/g, '').slice(0, 8)}`;
        const openingBalance = Math.round(ret.openingBalancePaise || 0);
        statements.push(
          db.prepare(
            `INSERT OR REPLACE INTO retailers (id, company_id, name, contact_number, address, beat_id, credit_limit_paise, outstanding_amount_paise, is_active)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)`
          ).bind(
            retId,
            user.company_id,
            ret.name.trim(),
            ret.contactNumber || null,
            ret.address || '',
            ret.beatId || 'BEAT-04',
            Math.round(ret.creditLimitPaise || 500000),
            openingBalance
          )
        );
      }
    }

    // Initialize default Role Permissions
    const defaultRoles = [
      { role: 'OWNER', canApprove: 1, canEditStock: 1, canDiscount: 1, canReverse: 1, maxDiscount: 100 },
      { role: 'ADMIN', canApprove: 1, canEditStock: 1, canDiscount: 1, canReverse: 1, maxDiscount: 15 },
      { role: 'WAREHOUSE_MANAGER', canApprove: 0, canEditStock: 1, canDiscount: 0, canReverse: 0, maxDiscount: 0 },
      { role: 'SALESPERSON', canApprove: 0, canEditStock: 0, canDiscount: 1, canReverse: 0, maxDiscount: 5 },
      { role: 'DELIVERY_EXECUTIVE', canApprove: 0, canEditStock: 0, canDiscount: 0, canReverse: 0, maxDiscount: 0 },
    ];
    for (const r of defaultRoles) {
      statements.push(
        db.prepare(
          `INSERT OR IGNORE INTO role_permissions (company_id, role, can_approve_orders, can_edit_stock, can_give_discount, can_reverse_payment, max_discount_pct, updated_at, updated_by)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
        ).bind(user.company_id, r.role, r.canApprove, r.canEditStock, r.canDiscount, r.canReverse, r.maxDiscount, now, user.sub)
      );
    }

    try {
      if (statements.length > 0) {
        await db.batch(statements);
      }
      await recordAudit(c, 'ONBOARDING_WIZARD_COMPLETED', user.company_id, 'Owner completed full business setup wizard');
      return c.json({
        success: true,
        message: 'Business onboarding completed successfully. All records are initialized.'
      });
    } catch (err: any) {
      console.error('Wizard setup failed:', err);
      return c.json({ error: err.message || 'Onboarding setup failed' }, 500);
    }
  });

  // ── 2. Role Permissions Management ─────────────────────────────────────────
  router.get('/permissions', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const { results } = await db.prepare(
      `SELECT role, can_approve_orders AS canApproveOrders, can_edit_stock AS canEditStock,
              can_give_discount AS canGiveDiscount, can_reverse_payment AS canReversePayment,
              max_discount_pct AS maxDiscountPct, updated_at AS updatedAt
       FROM role_permissions WHERE company_id = ?`
    ).bind(user.company_id).all();

    return c.json({ permissions: results });
  });

  router.put('/permissions', auth, async (c) => {
    const user = c.get('user');
    if (!user || user.role !== 'OWNER') {
      return c.json({ error: 'Permission denied: Only business Owner can edit role permissions' }, 403);
    }

    const body = await c.req.json().catch(() => ({}));
    const { role, canApproveOrders, canEditStock, canGiveDiscount, canReversePayment, maxDiscountPct } = body;

    if (!role) return c.json({ error: 'Role is required' }, 400);

    const db = c.env.DB as D1Database;
    const now = Date.now();

    await db.prepare(
      `INSERT INTO role_permissions (company_id, role, can_approve_orders, can_edit_stock, can_give_discount, can_reverse_payment, max_discount_pct, updated_at, updated_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(company_id, role) DO UPDATE SET
         can_approve_orders = excluded.can_approve_orders,
         can_edit_stock = excluded.can_edit_stock,
         can_give_discount = excluded.can_give_discount,
         can_reverse_payment = excluded.can_reverse_payment,
         max_discount_pct = excluded.max_discount_pct,
         updated_at = excluded.updated_at,
         updated_by = excluded.updated_by`
    ).bind(
      user.company_id,
      role,
      canApproveOrders ? 1 : 0,
      canEditStock ? 1 : 0,
      canGiveDiscount ? 1 : 0,
      canReversePayment ? 1 : 0,
      Number(maxDiscountPct ?? 0),
      now,
      user.sub
    ).run();

    await recordAudit(c, 'PERMISSIONS_UPDATED', role, `Updated permissions for ${role}: max discount ${maxDiscountPct}%`);

    return c.json({ success: true, message: `Permissions for ${role} updated successfully` });
  });

  // ── 3. Full Audit Logs API ────────────────────────────────────────────────
  router.get('/audit-logs', auth, async (c) => {
    const user = c.get('user');
    if (!user || !['OWNER', 'ADMIN'].includes(user.role)) {
      return c.json({ error: 'Permission denied: Owner or Admin role required' }, 403);
    }

    const db = c.env.DB as D1Database;
    const action = c.req.query('action');
    const limit = Math.min(parseInt(c.req.query('limit') || '50', 10), 200);
    const offset = parseInt(c.req.query('offset') || '0', 10);

    let query = `
      SELECT a.id, a.user_id AS userId, u.full_name AS userName, u.username,
             COALESCE(a.role, u.role) AS role, a.action, a.entity_id AS entityId,
             a.details, a.timestamp, a.device_id AS deviceId, a.ip_address AS ipAddress
      FROM audit_logs a
      LEFT JOIN users u ON u.id = a.user_id
      WHERE a.company_id = ?
    `;
    const params: any[] = [user.company_id];

    if (action) {
      query += ' AND a.action = ?';
      params.push(action);
    }

    query += ' ORDER BY a.timestamp DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const { results } = await db.prepare(query).bind(...params).all();

    return c.json({ auditLogs: results, count: results.length });
  });

  // ── 4. CSV Export & Backup API ────────────────────────────────────────────
  router.get('/export/backup-json', auth, async (c) => {
    const user = c.get('user');
    if (!user || user.role !== 'OWNER') {
      return c.json({ error: 'Permission denied: Only business Owner can download full JSON backup' }, 403);
    }

    const db = c.env.DB as D1Database;
    const [products, retailers, orders, collections, employees, beats] = await Promise.all([
      db.prepare('SELECT * FROM products WHERE company_id = ?').bind(user.company_id).all(),
      db.prepare('SELECT * FROM retailers WHERE company_id = ?').bind(user.company_id).all(),
      db.prepare('SELECT * FROM orders WHERE company_id = ?').bind(user.company_id).all(),
      db.prepare('SELECT * FROM collections WHERE company_id = ?').bind(user.company_id).all(),
      db.prepare('SELECT id, username, full_name, role, is_active, phone_number FROM users WHERE company_id = ?').bind(user.company_id).all(),
      db.prepare('SELECT * FROM beats WHERE company_id = ?').bind(user.company_id).all(),
    ]);

    await recordAudit(c, 'FULL_BACKUP_EXPORTED', user.company_id, 'Downloaded complete business JSON backup archive');

    return c.json({
      exportedAt: new Date().toISOString(),
      companyId: user.company_id,
      products: products.results,
      retailers: retailers.results,
      orders: orders.results,
      payments: collections.results,
      employees: employees.results,
      beats: beats.results
    });
  });

  router.get('/export/:entity', auth, async (c) => {
    const user = c.get('user');
    if (!user || !['OWNER', 'ADMIN'].includes(user.role)) {
      return c.json({ error: 'Permission denied: Owner or Admin role required' }, 403);
    }

    const entity = c.req.param('entity');
    const db = c.env.DB as D1Database;

    const toCsv = (rows: any[], headers: string[], keys: string[]) => {
      const escape = (val: any) => {
        if (val === null || val === undefined) return '""';
        const str = String(val).replace(/"/g, '""');
        return `"${str}"`;
      };
      const headerLine = headers.map(escape).join(',');
      const rowLines = rows.map(row => keys.map(k => escape(row[k])).join(','));
      return [headerLine, ...rowLines].join('\r\n');
    };

    if (entity === 'products') {
      const { results } = await db.prepare(
        'SELECT id, name, sku, category, price_paise, stock_quantity, unit, is_active FROM products WHERE company_id = ? ORDER BY name ASC'
      ).bind(user.company_id).all<any>();

      const rows = results.map(r => ({ ...r, price_rupees: (r.price_paise / 100).toFixed(2) }));
      const csv = toCsv(rows, ['ID', 'Product Name', 'SKU', 'Category', 'Price (INR)', 'Stock Quantity', 'Unit', 'Active'],
        ['id', 'name', 'sku', 'category', 'price_rupees', 'stock_quantity', 'unit', 'is_active']);

      return new Response(csv, {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': 'attachment; filename="routeflow_products.csv"'
        }
      });
    }

    if (entity === 'retailers') {
      const { results } = await db.prepare(
        'SELECT id, name, contact_number, address, beat_id, credit_limit_paise, outstanding_amount_paise, is_active FROM retailers WHERE company_id = ? ORDER BY name ASC'
      ).bind(user.company_id).all<any>();

      const rows = results.map(r => ({
        ...r,
        credit_limit_rupees: (r.credit_limit_paise / 100).toFixed(2),
        outstanding_rupees: (r.outstanding_amount_paise / 100).toFixed(2)
      }));
      const csv = toCsv(rows, ['ID', 'Shop Name', 'Contact', 'Address', 'Beat ID', 'Credit Limit (INR)', 'Outstanding (INR)', 'Active'],
        ['id', 'name', 'contact_number', 'address', 'beat_id', 'credit_limit_rupees', 'outstanding_rupees', 'is_active']);

      return new Response(csv, {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': 'attachment; filename="routeflow_retailers.csv"'
        }
      });
    }

    if (entity === 'orders') {
      const { results } = await db.prepare(
        `SELECT o.id, r.name AS retailer_name, o.status, o.total_amount_paise, u.full_name AS salesperson_name, o.created_at
         FROM orders o
         LEFT JOIN retailers r ON r.id = o.retailer_id
         LEFT JOIN users u ON u.id = o.salesperson_user_id
         WHERE o.company_id = ? ORDER BY o.created_at DESC`
      ).bind(user.company_id).all<any>();

      const rows = results.map(r => ({
        ...r,
        amount_rupees: (r.total_amount_paise / 100).toFixed(2),
        date: new Date(r.created_at).toISOString()
      }));
      const csv = toCsv(rows, ['Order ID', 'Retailer', 'Status', 'Amount (INR)', 'Booked By', 'Created At'],
        ['id', 'retailer_name', 'status', 'amount_rupees', 'salesperson_name', 'date']);

      return new Response(csv, {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': 'attachment; filename="routeflow_orders.csv"'
        }
      });
    }

    if (entity === 'payments' || entity === 'collections') {
      const { results } = await db.prepare(
        `SELECT c.id, r.name AS retailer_name, c.amount_paise, c.payment_method AS payment_mode, c.status, c.receipt_id AS reference_number, u.full_name AS collected_by_name, c.created_at
         FROM collections c
         LEFT JOIN retailers r ON r.id = c.retailer_id
         LEFT JOIN users u ON u.id = c.collected_by
         WHERE c.company_id = ? ORDER BY c.created_at DESC`
      ).bind(user.company_id).all<any>();

      const rows = results.map(r => ({
        ...r,
        amount_rupees: (r.amount_paise / 100).toFixed(2),
        date: new Date(r.created_at).toISOString()
      }));
      const csv = toCsv(rows, ['Payment ID', 'Retailer', 'Amount (INR)', 'Mode', 'Status', 'Reference', 'Collected By', 'Date'],
        ['id', 'retailer_name', 'amount_rupees', 'payment_mode', 'status', 'reference_number', 'collected_by_name', 'date']);

      return new Response(csv, {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': 'attachment; filename="routeflow_payments.csv"'
        }
      });
    }

    return c.json({ error: `Unknown export entity: ${entity}. Allowed: products, retailers, orders, payments` }, 400);
  });

  // ── 5. Payment Verification Lifecycle (ENTERED, VERIFIED, CLEARED, REJECTED) ──
  router.get('/payments/verification-queue', auth, async (c) => {
    const user = c.get('user');
    if (!user || !['OWNER', 'ADMIN'].includes(user.role)) {
      return c.json({ error: 'Permission denied' }, 403);
    }

    const db = c.env.DB as D1Database;
    const { results } = await db.prepare(
      `SELECT c.id, c.retailer_id AS retailerId, r.name AS retailerName,
              c.amount_paise AS amountPaise, c.payment_method AS paymentMode,
              c.receipt_id AS referenceNumber, c.status, c.notes,
              u.full_name AS collectedByName, c.created_at AS createdAt
       FROM collections c
       LEFT JOIN retailers r ON r.id = c.retailer_id
       LEFT JOIN users u ON u.id = c.collected_by
       WHERE c.company_id = ? AND c.status IN ('ENTERED', 'VERIFIED')
       ORDER BY c.created_at DESC`
    ).bind(user.company_id).all();

    return c.json({ payments: results });
  });

  router.post('/payments/:id/verify', auth, async (c) => {
    const user = c.get('user');
    if (!user || !['OWNER', 'ADMIN'].includes(user.role)) {
      return c.json({ error: 'Permission denied: Owner or Admin role required' }, 403);
    }

    const paymentId = c.req.param('id');
    const db = c.env.DB as D1Database;
    const now = Date.now();

    const payment = await db.prepare(
      'SELECT * FROM collections WHERE id = ? AND company_id = ?'
    ).bind(paymentId, user.company_id).first<any>();

    if (!payment) return c.json({ error: 'Payment record not found' }, 404);

    await db.prepare(
      'UPDATE collections SET status = ?, verified_by = ?, verified_at = ? WHERE id = ?'
    ).bind('VERIFIED', user.sub, now, paymentId).run();

    await recordAudit(c, 'PAYMENT_VERIFIED', paymentId, `Verified ${payment.payment_method} payment of ₹${payment.amount_paise / 100}`);

    return c.json({ success: true, message: 'Payment marked as verified' });
  });

  router.post('/payments/:id/clear', auth, async (c) => {
    const user = c.get('user');
    if (!user || user.role !== 'OWNER') {
      return c.json({ error: 'Permission denied: Only business Owner can clear payments' }, 403);
    }

    const paymentId = c.req.param('id');
    const db = c.env.DB as D1Database;
    const now = Date.now();

    const payment = await db.prepare(
      'SELECT * FROM collections WHERE id = ? AND company_id = ?'
    ).bind(paymentId, user.company_id).first<any>();

    if (!payment) return c.json({ error: 'Payment not found' }, 404);

    await db.prepare(
      'UPDATE collections SET status = ?, cleared_at = ? WHERE id = ?'
    ).bind('CLEARED', now, paymentId).run();

    await recordAudit(c, 'PAYMENT_CLEARED', paymentId, `Payment of ₹${payment.amount_paise / 100} cleared and credited to bank`);

    return c.json({ success: true, message: 'Payment cleared successfully' });
  });

  // ── 6. Suppliers & Goods Receipt Notes (GRN) Inward Stock ──────────────────
  router.get('/suppliers', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const { results } = await db.prepare(
      'SELECT id, name, contact_number AS contactNumber, email, gstin, address, city, created_at AS createdAt FROM suppliers WHERE company_id = ? ORDER BY name ASC'
    ).bind(user.company_id).all();

    return c.json({ suppliers: results });
  });

  router.post('/suppliers', auth, async (c) => {
    const user = c.get('user');
    if (!user || !['OWNER', 'ADMIN', 'WAREHOUSE_MANAGER'].includes(user.role)) {
      return c.json({ error: 'Permission denied' }, 403);
    }

    const body = await c.req.json().catch(() => ({}));
    const { name, contactNumber, email, gstin, address, city } = body;

    if (!name || typeof name !== 'string' || name.trim().length < 2) {
      return c.json({ error: 'Supplier name is required' }, 400);
    }

    const db = c.env.DB as D1Database;
    const supplierId = `sup_${crypto.randomUUID().replace(/-/g, '').slice(0, 10)}`;
    const now = Date.now();

    await db.prepare(
      `INSERT INTO suppliers (id, company_id, name, contact_number, email, gstin, address, city, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(supplierId, user.company_id, name.trim(), contactNumber || null, email || null, gstin || null, address || null, city || null, now).run();

    await recordAudit(c, 'SUPPLIER_CREATED', supplierId, `Created supplier ${name}`);

    return c.json({ success: true, supplier: { id: supplierId, name: name.trim() } }, 201);
  });

  router.get('/grn', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const { results } = await db.prepare(
      `SELECT g.id, g.supplier_id AS supplierId, s.name AS supplierName,
              g.invoice_number AS invoiceNumber, g.status, g.total_amount_paise AS totalAmountPaise,
              g.notes, u.full_name AS receivedByName, g.created_at AS createdAt, g.approved_at AS approvedAt
       FROM goods_receipt_notes g
       LEFT JOIN suppliers s ON s.id = g.supplier_id
       LEFT JOIN users u ON u.id = g.received_by
       WHERE g.company_id = ? ORDER BY g.created_at DESC`
    ).bind(user.company_id).all();

    return c.json({ grns: results });
  });

  router.post('/grn', auth, async (c) => {
    const user = c.get('user');
    if (!user || !['OWNER', 'WAREHOUSE_MANAGER'].includes(user.role)) {
      return c.json({ error: 'Permission denied: Warehouse Manager or Owner role required' }, 403);
    }

    const body = await c.req.json().catch(() => ({}));
    const { supplierId, invoiceNumber, notes, items } = body;

    if (!supplierId) return c.json({ error: 'Supplier ID is required' }, 400);
    if (!Array.isArray(items) || items.length === 0) {
      return c.json({ error: 'GRN must contain at least 1 line item' }, 400);
    }

    const db = c.env.DB as D1Database;
    const grnId = `grn_${crypto.randomUUID().replace(/-/g, '').slice(0, 10)}`;
    const now = Date.now();

    let totalAmountPaise = 0;
    const statements: any[] = [];

    for (const item of items) {
      const qty = parseInt(item.quantityReceived || 0, 10);
      const unitCost = Math.round(item.unitCostPaise || 0);
      if (!item.productId || qty <= 0) continue;

      totalAmountPaise += qty * unitCost;
      const itemId = `grni_${crypto.randomUUID().replace(/-/g, '').slice(0, 10)}`;

      statements.push(
        db.prepare(
          `INSERT INTO grn_items (id, grn_id, product_id, batch_no, quantity_received, unit_cost_paise, mfg_date, expiry_date, rack_bin)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
        ).bind(itemId, grnId, item.productId, item.batchNo || null, qty, unitCost, item.mfgDate || null, item.expiryDate || null, item.rackBin || null)
      );
    }

    statements.unshift(
      db.prepare(
        `INSERT INTO goods_receipt_notes (id, company_id, supplier_id, invoice_number, status, total_amount_paise, notes, received_by, created_at)
         VALUES (?, ?, ?, ?, 'PENDING_APPROVAL', ?, ?, ?, ?)`
      ).bind(grnId, user.company_id, supplierId, invoiceNumber || null, totalAmountPaise, notes || null, user.sub, now)
    );

    await db.batch(statements);
    await recordAudit(c, 'GRN_CREATED', grnId, `Created GRN with ${items.length} items totaling ₹${totalAmountPaise / 100}`);

    return c.json({ success: true, grn: { id: grnId, totalAmountPaise, status: 'PENDING_APPROVAL' } }, 201);
  });

  router.post('/grn/:id/approve', auth, async (c) => {
    const user = c.get('user');
    if (!user || user.role !== 'OWNER') {
      return c.json({ error: 'Permission denied: Only business Owner can approve inward stock GRN' }, 403);
    }

    const grnId = c.req.param('id');
    const db = c.env.DB as D1Database;
    const now = Date.now();

    const grn = await db.prepare(
      'SELECT * FROM goods_receipt_notes WHERE id = ? AND company_id = ?'
    ).bind(grnId, user.company_id).first<any>();

    if (!grn) return c.json({ error: 'GRN not found' }, 404);
    if (grn.status !== 'PENDING_APPROVAL') {
      return c.json({ error: `GRN is already in status: ${grn.status}` }, 400);
    }

    const { results: items } = await db.prepare(
      'SELECT * FROM grn_items WHERE grn_id = ?'
    ).bind(grnId).all<any>();

    const statements: any[] = [
      db.prepare("UPDATE goods_receipt_notes SET status = 'APPROVED', approved_by = ?, approved_at = ? WHERE id = ?")
        .bind(user.sub, now, grnId)
    ];

    for (const item of items) {
      // 1. Atomically increase physical stock in products table
      statements.push(
        db.prepare('UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?')
          .bind(item.quantity_received, item.product_id, user.company_id)
      );

      // 2. Create batch entry if batch_no exists
      if (item.batch_no) {
        const batchId = `batch_${crypto.randomUUID().replace(/-/g, '').slice(0, 10)}`;
        statements.push(
          db.prepare(
            `INSERT INTO product_batches (id, company_id, product_id, batch_no, mfg_date, expiry_date, rack_bin, received_quantity, remaining_quantity, committed_quantity, status, received_by, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 'ACTIVE', ?, ?, ?)`
          ).bind(batchId, user.company_id, item.product_id, item.batch_no, item.mfg_date, item.expiry_date, item.rack_bin, item.quantity_received, item.quantity_received, user.sub, now, now)
        );
      }
    }

    await db.batch(statements);
    await recordAudit(c, 'GRN_APPROVED', grnId, `Approved GRN inward stock: ${items.length} line items added to godown`);

    return c.json({ success: true, message: 'GRN approved and godown inventory updated' });
  });

  return router;
}
