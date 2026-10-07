import { Hono, type MiddlewareHandler } from 'hono';
import { requestIp } from './security';

type OpEnv = {
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

export function operatingRouter(auth: MiddlewareHandler<OpEnv>) {
  const router = new Hono<OpEnv>();

  // Helper: record audit log
  const recordAudit = async (c: any, action: string, entityId: string | null, details: string) => {
    const db = c.env.DB as D1Database;
    const u = c.get('user');
    const ip = requestIp(c);
    const deviceId = c.req.header('X-Device-Id') || c.req.header('User-Agent') || 'UNKNOWN';
    await db.prepare(
      `INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp, role, device_id, ip_address)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(crypto.randomUUID(), u?.company_id || 'UNKNOWN', u?.sub || 'SYSTEM', action, entityId, details, Date.now(), u?.role || 'UNKNOWN', deviceId, ip)
    .run().catch(() => {});
  };

  // ── 1. OWNER CONTROL ROOM: Live Real-Time Pulse ────────────────────────────
  // Single endpoint aggregating all 10 critical operational dimensions
  router.get('/control-room/pulse', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const companyId = user.company_id;
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayStartMs = todayStart.getTime();

    // 1.1 Sales & Orders today
    const salesPromise = db.prepare(`
      SELECT 
        COUNT(id) AS total_orders,
        COALESCE(SUM(CASE WHEN status NOT IN ('REJECTED', 'CANCELLED') THEN total_amount_paise ELSE 0 END), 0) AS total_sales_paise,
        COALESCE(SUM(CASE WHEN status = 'DELIVERED' THEN total_amount_paise ELSE 0 END), 0) AS delivered_sales_paise,
        COALESCE(SUM(CASE WHEN status = 'PENDING_APPROVAL' THEN 1 ELSE 0 END), 0) AS pending_approvals,
        COALESCE(SUM(CASE WHEN status IN ('PICKING', 'PACKED') THEN 1 ELSE 0 END), 0) AS in_warehouse,
        COALESCE(SUM(CASE WHEN status = 'OUT_FOR_DELIVERY' THEN 1 ELSE 0 END), 0) AS out_for_delivery,
        COALESCE(SUM(CASE WHEN status = 'DELIVERY_FAILED' THEN 1 ELSE 0 END), 0) AS failed_deliveries
      FROM orders
      WHERE company_id = ? AND created_at >= ?
    `).bind(companyId, todayStartMs).first<any>();

    // 1.2 Collections Today
    const collectionsPromise = db.prepare(`
      SELECT 
        COALESCE(SUM(CASE WHEN payment_method = 'CASH' AND status = 'SETTLED' THEN amount_paise ELSE 0 END), 0) AS cash_collected_paise,
        COALESCE(SUM(CASE WHEN payment_method = 'UPI' THEN amount_paise ELSE 0 END), 0) AS upi_total_paise,
        COALESCE(SUM(CASE WHEN payment_method = 'UPI' AND status IN ('ENTERED', 'LEGACY_REVIEW') THEN 1 ELSE 0 END), 0) AS upi_unverified_count,
        COALESCE(SUM(CASE WHEN payment_method = 'CHEQUE' THEN amount_paise ELSE 0 END), 0) AS cheque_total_paise,
        COALESCE(SUM(CASE WHEN payment_method = 'CHEQUE' AND status IN ('ENTERED', 'LEGACY_REVIEW') THEN 1 ELSE 0 END), 0) AS cheque_unverified_count
      FROM collections
      WHERE company_id = ? AND created_at >= ?
    `).bind(companyId, todayStartMs).first<any>();

    // 1.3 Cash Handovers (Pending acknowledgement)
    const handoversPromise = db.prepare(`
      SELECT 
        COUNT(id) AS pending_handovers_count,
        COALESCE(SUM(amount_paise), 0) AS pending_handovers_paise
      FROM cash_handovers
      WHERE company_id = ? AND status = 'PENDING'
    `).bind(companyId).first<any>();

    // 1.4 Low Stock & Out of Stock SKUs
    const stockPromise = db.prepare(`
      SELECT 
        COUNT(id) AS low_stock_count,
        COALESCE(SUM(CASE WHEN stock_quantity = 0 THEN 1 ELSE 0 END), 0) AS out_of_stock_count
      FROM products
      WHERE company_id = ? AND stock_quantity <= 15 AND is_active = 1
    `).bind(companyId).first<any>();

    // 1.5 Active Field Staff (Salesmen & Drivers on shift today)
    const staffPromise = db.prepare(`
      SELECT 
        COALESCE(SUM(CASE WHEN u.role = 'SALESPERSON' THEN 1 ELSE 0 END), 0) AS active_salesmen,
        COALESCE(SUM(CASE WHEN u.role = 'DELIVERY_EXECUTIVE' THEN 1 ELSE 0 END), 0) AS active_deliveries
      FROM shifts s
      JOIN users u ON u.id = s.user_id
      WHERE s.company_id = ? AND s.status = 'ON_SHIFT'
    `).bind(companyId).first<any>();

    // 1.6 Top Overdue Retailers
    const overduePromise = db.prepare(`
      SELECT id, name, contact_number, beat_id, credit_limit_paise, outstanding_amount_paise
      FROM retailers
      WHERE company_id = ? AND outstanding_amount_paise > 0 AND is_active = 1
      ORDER BY outstanding_amount_paise DESC
      LIMIT 5
    `).bind(companyId).all<any>();

    // 1.7 Today's Expenses Total
    const expensesPromise = db.prepare(`
      SELECT COALESCE(SUM(amount_paise), 0) AS today_expenses_paise
      FROM business_expenses
      WHERE company_id = ? AND created_at >= ?
    `).bind(companyId, todayStartMs).first<any>();

    // 1.8 Tomorrow Purchase Suggestions (Products below threshold with high sales velocity)
    const purchaseSugPromise = db.prepare(`
      SELECT p.id, p.name, p.sku, p.stock_quantity, p.price_paise, p.unit,
             COALESCE(SUM(oi.quantity), 0) AS units_sold_recent
      FROM products p
      LEFT JOIN order_items oi ON oi.product_id = p.id
      WHERE p.company_id = ? AND p.stock_quantity <= 25 AND p.is_active = 1
      GROUP BY p.id
      ORDER BY p.stock_quantity ASC, units_sold_recent DESC
      LIMIT 6
    `).bind(companyId).all<any>();

    const [sales, collections, handovers, stock, staff, overdue, expenses, purchase] = await Promise.all([
      salesPromise,
      collectionsPromise,
      handoversPromise,
      stockPromise,
      staffPromise,
      overduePromise,
      expensesPromise,
      purchaseSugPromise
    ]);

    const cashCollected = collections?.cash_collected_paise || 0;
    const expensesPaid = expenses?.today_expenses_paise || 0;
    const netCashInHand = Math.max(0, cashCollected - expensesPaid);

    return c.json({
      timestamp: Date.now(),
      todaySales: {
        totalOrders: sales?.total_orders || 0,
        bookedPaise: sales?.total_sales_paise || 0,
        deliveredPaise: sales?.delivered_sales_paise || 0,
        pendingApprovals: sales?.pending_approvals || 0,
        inWarehouse: sales?.in_warehouse || 0,
        outForDelivery: sales?.out_for_delivery || 0,
        failedDeliveries: sales?.failed_deliveries || 0,
      },
      todayCollections: {
        cashCollectedPaise: cashCollected,
        upiTotalPaise: collections?.upi_total_paise || 0,
        upiUnverifiedCount: collections?.upi_unverified_count || 0,
        chequeTotalPaise: collections?.cheque_total_paise || 0,
        chequeUnverifiedCount: collections?.cheque_unverified_count || 0,
        todayExpensesPaise: expensesPaid,
        netCashInHandPaise: netCashInHand
      },
      handovers: {
        pendingCount: handovers?.pending_handovers_count || 0,
        pendingPaise: handovers?.pending_handovers_paise || 0
      },
      inventory: {
        lowStockCount: stock?.low_stock_count || 0,
        outOfStockCount: stock?.out_of_stock_count || 0
      },
      activeStaff: {
        salesmen: staff?.active_salesmen || 0,
        delivery: staff?.active_deliveries || 0
      },
      topOverdueRetailers: overdue.results || [],
      tomorrowPurchaseSuggestions: purchase.results || []
    });
  });

  // ── 2. DAILY OPENING & CLOSING CHECKLIST (Day Book Lifecycle) ─────────────
  router.get('/day-book/today', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const todayStr = new Date().toISOString().split('T')[0];

    const { results } = await db.prepare(`
      SELECT * FROM day_book_checklists
      WHERE company_id = ? AND business_date = ?
    `).bind(user.company_id, todayStr).all<any>();

    const morning = results.find(r => r.type === 'MORNING_OPENING');
    const night = results.find(r => r.type === 'NIGHT_CLOSING');

    return c.json({
      businessDate: todayStr,
      morningOpening: morning ? { ...morning, checklist: JSON.parse(morning.checklist_data || '{}') } : null,
      nightClosing: night ? { ...night, checklist: JSON.parse(night.checklist_data || '{}') } : null
    });
  });

  router.post('/day-book/checklist', auth, async (c) => {
    const user = c.get('user');
    if (!user || !['OWNER', 'ADMIN'].includes(user.role)) {
      return c.json({ error: 'Permission denied: Owner or Admin role required' }, 403);
    }

    const body = await c.req.json().catch(() => ({}));
    const { type, checklist, notes, snapshot } = body;

    if (!type || !['MORNING_OPENING', 'NIGHT_CLOSING'].includes(type)) {
      return c.json({ error: "Type must be 'MORNING_OPENING' or 'NIGHT_CLOSING'" }, 400);
    }

    const db = c.env.DB as D1Database;
    const todayStr = new Date().toISOString().split('T')[0];
    const now = Date.now();
    const id = `chk_${type.toLowerCase()}_${todayStr}_${crypto.randomUUID().slice(0, 6)}`;

    const snap = snapshot || {};

    await db.prepare(`
      INSERT INTO day_book_checklists (
        id, company_id, business_date, type, status, checklist_data,
        sales_total_paise, collections_cash_paise, collections_upi_paise, collections_cheque_paise,
        expenses_total_paise, cash_in_hand_paise, orders_count, pending_approvals_count,
        failed_deliveries_count, returns_count, low_stock_count, active_staff_count,
        notes, completed_by, created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?, 'COMPLETED', ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?
      )
      ON CONFLICT(company_id, business_date, type) DO UPDATE SET
        checklist_data = excluded.checklist_data,
        sales_total_paise = excluded.sales_total_paise,
        collections_cash_paise = excluded.collections_cash_paise,
        expenses_total_paise = excluded.expenses_total_paise,
        cash_in_hand_paise = excluded.cash_in_hand_paise,
        notes = excluded.notes,
        completed_by = excluded.completed_by,
        updated_at = excluded.updated_at
    `).bind(
      id, user.company_id, todayStr, type, JSON.stringify(checklist || {}),
      Math.round(snap.salesTotalPaise || 0),
      Math.round(snap.cashCollectedPaise || 0),
      Math.round(snap.upiCollectedPaise || 0),
      Math.round(snap.chequeCollectedPaise || 0),
      Math.round(snap.expensesTotalPaise || 0),
      Math.round(snap.cashInHandPaise || 0),
      snap.ordersCount || 0,
      snap.pendingApprovalsCount || 0,
      snap.failedDeliveriesCount || 0,
      snap.returnsCount || 0,
      snap.lowStockCount || 0,
      snap.activeStaffCount || 0,
      notes || null,
      user.sub,
      now,
      now
    ).run();

    await recordAudit(c, `DAY_BOOK_${type}`, id, `Completed ${type} checklist for date ${todayStr}`);

    return c.json({ success: true, message: `${type} checklist saved successfully`, id });
  });

  // ── 3. EXCEPTION CENTER: The Central Emergency Feed ─────────────────────────
  router.get('/exceptions/feed', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const companyId = user.company_id;
    const nowSec = Math.floor(Date.now() / 1000);

    const [failedDelivs, lowStock, unverifiedPayments, pendingHandovers, nearExpiry, overdueRetailers] = await Promise.all([
      // Failed deliveries
      db.prepare(`
        SELECT id, retailer_id, total_amount_paise, status, updated_at
        FROM orders
        WHERE company_id = ? AND status = 'DELIVERY_FAILED'
        ORDER BY updated_at DESC LIMIT 10
      `).bind(companyId).all<any>(),

      // Critical low stock
      db.prepare(`
        SELECT id, name, sku, stock_quantity
        FROM products
        WHERE company_id = ? AND stock_quantity <= 10 AND is_active = 1
        ORDER BY stock_quantity ASC LIMIT 10
      `).bind(companyId).all<any>(),

      // Unverified non-cash payments
      db.prepare(`
        SELECT id, retailer_id, amount_paise, payment_method, receipt_id, created_at
        FROM collections
        WHERE company_id = ? AND status IN ('ENTERED', 'LEGACY_REVIEW')
        ORDER BY created_at DESC LIMIT 10
      `).bind(companyId).all<any>(),

      // Driver cash pending handover
      db.prepare(`
        SELECT ch.id, ch.user_id, u.full_name AS driver_name, ch.amount_paise, ch.submitted_at
        FROM cash_handovers ch
        LEFT JOIN users u ON u.id = ch.user_id
        WHERE ch.company_id = ? AND ch.status = 'PENDING'
        ORDER BY ch.submitted_at DESC LIMIT 10
      `).bind(companyId).all<any>(),

      // Batches expiring within 30 days
      db.prepare(`
        SELECT pb.id, p.name AS product_name, pb.batch_no, pb.expiry_date, pb.remaining_quantity
        FROM product_batches pb
        JOIN products p ON p.id = pb.product_id
        WHERE pb.company_id = ? AND pb.status = 'ACTIVE' AND pb.expiry_date IS NOT NULL 
          AND pb.expiry_date <= ? AND pb.remaining_quantity > 0
        ORDER BY pb.expiry_date ASC LIMIT 10
      `).bind(companyId, nowSec + 30 * 86400).all<any>(),

      // Retailers crossing 80% credit limit
      db.prepare(`
        SELECT id, name, contact_number, credit_limit_paise, outstanding_amount_paise
        FROM retailers
        WHERE company_id = ? AND is_active = 1 AND outstanding_amount_paise >= (credit_limit_paise * 0.8)
        ORDER BY outstanding_amount_paise DESC LIMIT 10
      `).bind(companyId).all<any>()
    ]);

    const exceptions = [
      ...failedDelivs.results.map(f => ({
        type: 'FAILED_DELIVERY',
        severity: 'HIGH',
        id: f.id,
        title: `Failed Delivery: Order #${f.id}`,
        description: `Goods retained in driver custody. Amount: ₹${f.total_amount_paise / 100}`,
        timestamp: f.updated_at
      })),
      ...unverifiedPayments.results.map(p => ({
        type: 'UNVERIFIED_PAYMENT',
        severity: 'HIGH',
        id: p.id,
        title: `Unverified ${p.payment_method}: ₹${p.amount_paise / 100}`,
        description: `Receipt #${p.receipt_id}. Requires bank verification before settlement.`,
        timestamp: p.created_at
      })),
      ...pendingHandovers.results.map(h => ({
        type: 'PENDING_CASH_HANDOVER',
        severity: 'MEDIUM',
        id: h.id,
        title: `Cash Handover Pending: ₹${h.amount_paise / 100}`,
        description: `Driver ${h.driver_name || 'Driver'} submitted cash for owner verification`,
        timestamp: h.submitted_at
      })),
      ...lowStock.results.map(s => ({
        type: 'LOW_STOCK',
        severity: s.stock_quantity === 0 ? 'HIGH' : 'MEDIUM',
        id: s.id,
        title: `${s.stock_quantity === 0 ? 'OUT OF STOCK' : 'Low Stock'}: ${s.name}`,
        description: `Only ${s.stock_quantity} units left in warehouse (SKU: ${s.sku})`,
        timestamp: Date.now()
      })),
      ...nearExpiry.results.map(e => ({
        type: 'EXPIRY_ALERT',
        severity: 'HIGH',
        id: e.id,
        title: `Near Expiry Batch: ${e.product_name}`,
        description: `Batch ${e.batch_no}: ${e.remaining_quantity} units expire on ${new Date(e.expiry_date * 1000).toLocaleDateString()}`,
        timestamp: Date.now()
      })),
      ...overdueRetailers.results.map(r => ({
        type: 'OVERDUE_RETAILER',
        severity: 'MEDIUM',
        id: r.id,
        title: `Credit Exposure: ${r.name}`,
        description: `Outstanding ₹${r.outstanding_amount_paise / 100} of ₹${r.credit_limit_paise / 100} limit`,
        timestamp: Date.now()
      }))
    ];

    return c.json({
      exceptionsCount: exceptions.length,
      exceptions
    });
  });

  // ── 4. RETAILER 360 PROFILE VIEW ──────────────────────────────────────────
  router.get('/retailers/:id/360', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const retailerId = c.req.param('id');
    const db = c.env.DB as D1Database;
    const companyId = user.company_id;

    // 4.1 Shop master details
    const retailer = await db.prepare(`
      SELECT r.*, b.name AS beat_name
      FROM retailers r
      LEFT JOIN beats b ON b.id = r.beat_id
      WHERE r.id = ? AND r.company_id = ?
    `).bind(retailerId, companyId).first<any>();

    if (!retailer) return c.json({ error: 'Retailer not found' }, 404);

    // 4.2 Order history (last 5)
    const orders = await db.prepare(`
      SELECT o.id, o.status, o.total_amount_paise, o.created_at, u.full_name AS booked_by_name
      FROM orders o
      LEFT JOIN users u ON u.id = o.employee_id
      WHERE o.retailer_id = ? AND o.company_id = ?
      ORDER BY o.created_at DESC LIMIT 5
    `).bind(retailerId, companyId).all<any>();

    // 4.3 Last ordered line items (for repeat order)
    let lastOrderItems: any[] = [];
    if (orders.results.length > 0) {
      const lastOrderId = orders.results[0].id;
      const itemsRes = await db.prepare(`
        SELECT oi.product_id, p.name AS product_name, p.price_paise, oi.quantity, oi.free_quantity, p.stock_quantity
        FROM order_items oi
        JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
      `).bind(lastOrderId).all<any>();
      lastOrderItems = itemsRes.results;
    }

    // 4.4 Payments & Ledger entries (last 5)
    const payments = await db.prepare(`
      SELECT id, amount_paise, payment_method, status, receipt_id, created_at
      FROM collections
      WHERE retailer_id = ? AND company_id = ?
      ORDER BY created_at DESC LIMIT 5
    `).bind(retailerId, companyId).all<any>();

    // 4.5 Visit notes (last 3)
    const visits = await db.prepare(`
      SELECT v.id, v.check_in_time, v.check_out_time, v.notes, u.full_name AS sales_person_name
      FROM visits v
      LEFT JOIN users u ON u.id = v.employee_id
      WHERE v.retailer_id = ? AND v.company_id = ?
      ORDER BY v.check_in_time DESC LIMIT 3
    `).bind(retailerId, companyId).all<any>();

    // WhatsApp Statement Share Link Generator
    const outstandingRupees = (retailer.outstanding_amount_paise / 100).toFixed(2);
    const waText = encodeURIComponent(
      `Namaste ${retailer.name},\nThis is a statement from your distributor.\nYour current balance due is ₹${outstandingRupees}.\nPlease clear the outstanding at your earliest convenience.\nThank you!`
    );
    const waShareUrl = retailer.contact_number ? `https://wa.me/91${retailer.contact_number.replace(/\D/g, '')}?text=${waText}` : null;

    return c.json({
      retailer: {
        ...retailer,
        creditLimitRupees: (retailer.credit_limit_paise / 100).toFixed(2),
        outstandingRupees,
        availableCreditRupees: Math.max(0, (retailer.credit_limit_paise - retailer.outstanding_amount_paise) / 100).toFixed(2)
      },
      recentOrders: orders.results,
      lastOrderItems,
      recentPayments: payments.results,
      recentVisits: visits.results,
      whatsappShareUrl: waShareUrl
    });
  });

  // ── 5. GODOWN CONTROL: Stock Ledger & Movement ─────────────────────────────
  router.get('/godown/movement-ledger', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const companyId = user.company_id;

    // Movement: GRN inflows, Order picks, Returns
    const [grns, adjustments] = await Promise.all([
      db.prepare(`
        SELECT g.id, g.invoice_number, g.status, g.created_at, s.name AS supplier_name,
               gi.product_id, p.name AS product_name, gi.quantity_received, gi.batch_no
        FROM goods_receipt_notes g
        JOIN grn_items gi ON gi.grn_id = g.id
        JOIN products p ON p.id = gi.product_id
        LEFT JOIN suppliers s ON s.id = g.supplier_id
        WHERE g.company_id = ? AND g.status = 'APPROVED'
        ORDER BY g.created_at DESC LIMIT 20
      `).bind(companyId).all<any>(),

      db.prepare(`
        SELECT sa.id, p.name AS product_name, sa.quantity_delta, sa.reason, sa.created_at, u.full_name AS adjusted_by_name
        FROM stock_adjustments sa
        JOIN products p ON p.id = sa.product_id
        LEFT JOIN users u ON u.id = sa.adjusted_by
        WHERE sa.company_id = ?
        ORDER BY sa.created_at DESC LIMIT 20
      `).bind(companyId).all<any>()
    ]);

    const movements = [
      ...grns.results.map(g => ({
        type: 'INWARD_GRN',
        id: g.id,
        productName: g.product_name,
        quantity: `+${g.quantity_received}`,
        source: `Supplier: ${g.supplier_name || 'Vendor'} (Inv #${g.invoice_number || 'N/A'})`,
        batchNo: g.batch_no,
        timestamp: g.created_at
      })),
      ...adjustments.results.map(a => ({
        type: 'AUDIT_CORRECTION',
        id: a.id,
        productName: a.product_name,
        quantity: `${a.quantity_delta > 0 ? '+' : ''}${a.quantity_delta}`,
        source: `Audit: ${a.reason || 'Correction'} by ${a.adjusted_by_name || 'Staff'}`,
        batchNo: null,
        timestamp: a.created_at
      }))
    ].sort((a, b) => b.timestamp - a.timestamp);

    return c.json({ movements });
  });

  // ── 6. CASH CONTROL: Daily Cash Book & Expenses API ────────────────────────
  router.get('/cash-control/daily-book', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const companyId = user.company_id;
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayStartMs = todayStart.getTime();

    const [collections, expenses, handovers] = await Promise.all([
      db.prepare(`
        SELECT c.id, c.amount_paise, c.payment_method, c.receipt_id, c.status, c.created_at,
               r.name AS retailer_name, u.full_name AS collected_by_name
        FROM collections c
        LEFT JOIN retailers r ON r.id = c.retailer_id
        LEFT JOIN users u ON u.id = c.collected_by
        WHERE c.company_id = ? AND c.created_at >= ?
        ORDER BY c.created_at DESC
      `).bind(companyId, todayStartMs).all<any>(),

      db.prepare(`
        SELECT e.id, e.category, e.amount_paise, e.payment_mode, e.description, e.created_at,
               u.full_name AS paid_by_name
        FROM business_expenses e
        LEFT JOIN users u ON u.id = e.paid_by
        WHERE e.company_id = ? AND e.created_at >= ?
        ORDER BY e.created_at DESC
      `).bind(companyId, todayStartMs).all<any>(),

      db.prepare(`
        SELECT ch.id, ch.amount_paise, ch.status, ch.submitted_at, ch.acknowledged_at,
               u.full_name AS driver_name
        FROM cash_handovers ch
        LEFT JOIN users u ON u.id = ch.user_id
        WHERE ch.company_id = ? AND ch.submitted_at >= ?
        ORDER BY ch.submitted_at DESC
      `).bind(companyId, todayStartMs).all<any>()
    ]);

    const cashInPaise = collections.results
      .filter(c => c.payment_method === 'CASH' && c.status === 'SETTLED')
      .reduce((sum, c) => sum + c.amount_paise, 0);

    const expensesPaise = expenses.results
      .reduce((sum, e) => sum + e.amount_paise, 0);

    return c.json({
      summary: {
        cashInPaise,
        expensesPaise,
        netCashInHandPaise: Math.max(0, cashInPaise - expensesPaise)
      },
      collections: collections.results,
      expenses: expenses.results,
      handovers: handovers.results
    });
  });

  router.post('/cash-control/expenses', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const body = await c.req.json().catch(() => ({}));
    const { category, amountRupees, paymentMode, description, vehicleNumber } = body;

    const amt = parseFloat(amountRupees || '0');
    if (isNaN(amt) || amt <= 0) {
      return c.json({ error: 'Valid expense amount in Rupees is required' }, 400);
    }
    if (!description || description.trim().length < 2) {
      return c.json({ error: 'Expense description is required' }, 400);
    }

    const db = c.env.DB as D1Database;
    const expId = `exp_${crypto.randomUUID().slice(0, 10)}`;
    const now = Date.now();
    const amountPaise = Math.round(amt * 100);

    await db.prepare(`
      INSERT INTO business_expenses (
        id, company_id, category, amount_paise, payment_mode, description,
        paid_by, vehicle_number, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      expId, user.company_id, category || 'OTHER', amountPaise, paymentMode || 'CASH',
      description.trim(), user.sub, vehicleNumber || null, now
    ).run();

    await recordAudit(c, 'EXPENSE_RECORDED', expId, `Recorded ₹${amt} expense for ${category}: ${description}`);

    return c.json({ success: true, message: 'Expense recorded', expense: { id: expId, amountPaise } }, 201);
  });

  // ── 7. PURCHASE PLANNING & REORDER LIST ────────────────────────────────────
  router.get('/purchase-planning/suggestions', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const db = c.env.DB as D1Database;
    const companyId = user.company_id;

    // Detect fast-moving items, low stock, and zero stock
    const { results } = await db.prepare(`
      SELECT p.id, p.name, p.sku, p.category, p.stock_quantity, p.price_paise, p.unit,
             COALESCE(SUM(oi.quantity), 0) AS total_sold_units
      FROM products p
      LEFT JOIN order_items oi ON oi.product_id = p.id
      WHERE p.company_id = ? AND p.is_active = 1
      GROUP BY p.id
      ORDER BY p.stock_quantity ASC, total_sold_units DESC
    `).bind(companyId).all<any>();

    const purchaseList = results.map(p => {
      const suggestedReorder = p.stock_quantity <= 10 ? 50 : (p.stock_quantity <= 25 ? 30 : 0);
      const isUrgent = p.stock_quantity <= 5;
      return {
        ...p,
        priceRupees: (p.price_paise / 100).toFixed(2),
        suggestedReorderUnits: suggestedReorder,
        isUrgent,
        estimatedCostPaise: suggestedReorder * p.price_paise
      };
    }).filter(p => p.suggestedReorderUnits > 0);

    return c.json({
      reorderCount: purchaseList.length,
      purchaseList
    });
  });

  // ── 8. STAFF CONTROL & LIVE ATTENDANCE ─────────────────────────────────────
  router.get('/staff-control/summary', auth, async (c) => {
    const user = c.get('user');
    if (!user || !['OWNER', 'ADMIN'].includes(user.role)) {
      return c.json({ error: 'Permission denied' }, 403);
    }

    const db = c.env.DB as D1Database;
    const companyId = user.company_id;

    const [staff, shifts, visits] = await Promise.all([
      db.prepare(`
        SELECT id, username, full_name, role, is_active, phone_number
        FROM users
        WHERE company_id = ?
        ORDER BY role, full_name
      `).bind(companyId).all<any>(),

      db.prepare(`
        SELECT s.user_id, s.status, s.start_time, s.end_time, s.start_latitude, s.start_longitude
        FROM shifts s
        WHERE s.company_id = ? AND s.status IN ('ON_SHIFT', 'ON_BREAK')
      `).bind(companyId).all<any>(),

      db.prepare(`
        SELECT employee_id, COUNT(id) AS visits_count
        FROM visits
        WHERE company_id = ?
        GROUP BY employee_id
      `).bind(companyId).all<any>()
    ]);

    const activeShiftMap = new Map(shifts.results.map(s => [s.user_id, s]));
    const visitCountMap = new Map(visits.results.map(v => [v.employee_id, v.visits_count]));

    const staffList = staff.results.map(u => {
      const shift = activeShiftMap.get(u.id);
      return {
        ...u,
        isOnShift: !!shift,
        shiftStatus: shift ? shift.status : 'OFF_SHIFT',
        shiftStartedAt: shift ? shift.start_time : null,
        visitsToday: visitCountMap.get(u.id) || 0
      };
    });

    return c.json({ staff: staffList });
  });

  // ── 9. REPORTS & PRINTABLE / SHAREABLE PDF SIMULATORS ──────────────────────
  // Generates complete, styled HTML printable documents (PDF-ready for browser Ctrl+P)
  router.get('/reports/printable/:docType', auth, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Auth required' }, 401);

    const docType = c.req.param('docType'); // 'daily-closing', 'retailer-ledger', 'tax-invoice'
    const id = c.req.query('id');
    const db = c.env.DB as D1Database;
    const companyId = user.company_id;

    if (docType === 'daily-closing') {
      const todayStr = new Date().toISOString().split('T')[0];
      const row = await db.prepare(
        'SELECT * FROM day_book_checklists WHERE company_id = ? AND business_date = ? AND type = ?'
      ).bind(companyId, todayStr, 'NIGHT_CLOSING').first<any>();

      const comp = await db.prepare('SELECT name FROM companies WHERE id = ?').bind(companyId).first<any>();

      const html = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Daily Closing Summary - ${todayStr}</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 30px; color: #1e293b; }
            .header { border-bottom: 2px solid #2563eb; padding-bottom: 12px; margin-bottom: 20px; }
            h1 { margin: 0; font-size: 24px; color: #0f172a; }
            .badge { background: #eff6ff; color: #2563eb; padding: 4px 8px; border-radius: 6px; font-weight: 600; font-size: 12px; }
            table { width: 100%; border-collapse: collapse; margin-top: 15px; }
            th, td { border: 1px solid #cbd5e1; padding: 10px 12px; text-align: left; }
            th { background: #f8fafc; font-weight: 600; }
            .footer { margin-top: 40px; font-size: 12px; color: #64748b; border-top: 1px solid #e2e8f0; padding-top: 10px; }
          </style>
        </head>
        <body>
          <div class="header">
            <span class="badge">ROUTEFLOW OFFICIAL CLOSING SLIP</span>
            <h1>${comp?.name || 'Jaipur Wholesale Distributors'}</h1>
            <p style="margin: 4px 0 0; color: #64748b;">Daily Business Closing Record • Date: <strong>${todayStr}</strong></p>
          </div>
          <table>
            <tr><th>Metric</th><th>Recorded Value</th></tr>
            <tr><td>Total Booked Sales</td><td>₹${((row?.sales_total_paise || 0) / 100).toFixed(2)}</td></tr>
            <tr><td>Physical Cash Collected</td><td>₹${((row?.collections_cash_paise || 0) / 100).toFixed(2)}</td></tr>
            <tr><td>UPI Collections</td><td>₹${((row?.collections_upi_paise || 0) / 100).toFixed(2)}</td></tr>
            <tr><td>Cheque Collections</td><td>₹${((row?.collections_cheque_paise || 0) / 100).toFixed(2)}</td></tr>
            <tr><td>Daily Operating Expenses</td><td>₹${((row?.expenses_total_paise || 0) / 100).toFixed(2)}</td></tr>
            <tr><td><strong>Net Cash in Hand Settled</strong></td><td><strong>₹${((row?.cash_in_hand_paise || 0) / 100).toFixed(2)}</strong></td></tr>
          </table>
          <div class="footer">
            Generated via RouteFlow Daily Operating System • Verified by Owner • Authenticated Session
          </div>
        </body>
        </html>
      `;
      return c.html(html);
    }

    if (docType === 'retailer-ledger' && id) {
      const ret = await db.prepare('SELECT * FROM retailers WHERE id = ? AND company_id = ?').bind(id, companyId).first<any>();
      const comp = await db.prepare('SELECT name FROM companies WHERE id = ?').bind(companyId).first<any>();
      const col = await db.prepare('SELECT * FROM collections WHERE retailer_id = ? AND company_id = ? ORDER BY created_at DESC LIMIT 10').bind(id, companyId).all<any>();

      const html = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Retailer Ledger - ${ret?.name || 'Retailer'}</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 30px; color: #1e293b; }
            .header { border-bottom: 2px solid #059669; padding-bottom: 12px; margin-bottom: 20px; }
            h1 { margin: 0; font-size: 22px; color: #065f46; }
            table { width: 100%; border-collapse: collapse; margin-top: 15px; }
            th, td { border: 1px solid #cbd5e1; padding: 9px 12px; text-align: left; font-size: 13px; }
            th { background: #f0fdf4; font-weight: 600; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>${comp?.name || 'Jaipur Wholesale Distributors'}</h1>
            <p style="margin: 4px 0 0; color: #475569;">Retailer Statement • Shop: <strong>${ret?.name}</strong> • Phone: ${ret?.contact_number || 'N/A'}</p>
            <p style="margin: 4px 0 0; font-size: 14px; font-weight: 700; color: #b91c1c;">Outstanding Due: ₹${((ret?.outstanding_amount_paise || 0) / 100).toFixed(2)}</p>
          </div>
          <table>
            <tr><th>Date</th><th>Receipt / Ref</th><th>Payment Mode</th><th>Status</th><th>Amount (INR)</th></tr>
            ${col.results.map(c => `
              <tr>
                <td>${new Date(c.created_at).toLocaleDateString()}</td>
                <td>${c.receipt_id || c.id}</td>
                <td>${c.payment_method}</td>
                <td>${c.status}</td>
                <td>₹${(c.amount_paise / 100).toFixed(2)}</td>
              </tr>
            `).join('')}
          </table>
        </body>
        </html>
      `;
      return c.html(html);
    }

    return c.json({ error: 'Document type not supported' }, 400);
  });

  return router;
}
