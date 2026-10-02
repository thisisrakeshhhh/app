import { Hono, type Context, type MiddlewareHandler } from 'hono';

export type Actor = { sub: string; company_id: string; role: string; sid: string; name: string };
type TripEnv = { Bindings: { DB: D1Database }; Variables: { user: Actor } };
type Ctx = Context<TripEnv>;

const bad = (c: Ctx, error: string, status: 400 | 403 | 404 | 409 = 400) =>
  c.json({ error }, status);

const managementRoles = ['OWNER', 'ADMIN', 'WAREHOUSE_MANAGER'];
const allTripRoles = ['OWNER', 'ADMIN', 'WAREHOUSE_MANAGER', 'DELIVERY_EXECUTIVE'];

const audit = (c: Ctx, action: string, id: string, details: unknown) =>
  c.env.DB.prepare(
    'INSERT INTO audit_logs (id,company_id,user_id,action,entity_id,details,timestamp) VALUES (?,?,?,?,?,?,?)'
  ).bind(
    crypto.randomUUID(), c.get('user').company_id, c.get('user').sub,
    action, id, JSON.stringify(details), Date.now()
  );

export function tripRouter(authMiddleware: MiddlewareHandler<TripEnv>) {
  const router = new Hono<TripEnv>();
  router.use('*', authMiddleware);

  // ──────────────────────────────────────────────────────────────
  // POST /trips
  // Create delivery trip from ready orders.
  // ──────────────────────────────────────────────────────────────
  router.post('/', async (c) => {
    const user = c.get('user');
    if (!managementRoles.includes(user.role)) {
      return bad(c, 'Permission denied: warehouse, admin, or owner role required', 403);
    }

    const body = await c.req.json<{
      driverUserId?: string;
      driverId?: string;
      vehicleNumber?: string;
      routeArea?: string;
      orderIds: string[];
      startTime?: number;
      notes?: string;
    }>();

    const driverId = body.driverUserId || body.driverId;
    const orderIds = body.orderIds;

    if (!driverId || typeof driverId !== 'string') {
      return bad(c, 'driverUserId is required');
    }
    if (!Array.isArray(orderIds) || orderIds.length === 0) {
      return bad(c, 'orderIds must be a non-empty array');
    }
    if (new Set(orderIds).size !== orderIds.length) {
      return bad(c, 'Duplicate order IDs in trip');
    }
    if (orderIds.length > 50) {
      return bad(c, 'Maximum 50 orders per trip');
    }

    // 1. Verify driver belongs to this company and is an active DELIVERY_EXECUTIVE
    const driver = await c.env.DB.prepare(
      'SELECT id, full_name FROM users WHERE id = ? AND company_id = ? AND role = ? AND is_active = 1'
    ).bind(driverId, user.company_id, 'DELIVERY_EXECUTIVE').first<{ id: string; full_name: string }>();

    if (!driver) {
      return bad(c, 'Active delivery executive not found in company', 404);
    }

    // 2. Fetch and validate all orders belong to company
    const placeholders = orderIds.map(() => '?').join(',');
    const { results: orders } = await c.env.DB.prepare(
      `SELECT o.id, o.retailer_id, o.status, o.total_amount_paise, r.name as retailer_name, r.address, r.beat_id
       FROM orders o
       JOIN retailers r ON r.id = o.retailer_id
       WHERE o.id IN (${placeholders}) AND o.company_id = ?`
    ).bind(...orderIds, user.company_id).all<any>();

    if (orders.length !== orderIds.length) {
      return bad(c, 'One or more order IDs do not exist or belong to another company', 400);
    }

    const invalidStatus = orders.find(o =>
      ['DELIVERED', 'CANCELLED', 'ASSIGNED_TO_TRIP', 'OUT_FOR_DELIVERY'].includes(o.status)
    );
    if (invalidStatus) {
      return bad(c, `Order ${invalidStatus.id} has status ${invalidStatus.status}. Cannot assign order already delivered, cancelled, or in active trip.`, 400);
    }

    const tripId = `trip_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const now = Date.now();
    const tripNumber = `TRIP-${Math.floor(1000 + Math.random() * 9000)}`;
    const totalAmount = orders.reduce((sum, o) => sum + (o.total_amount_paise || 0), 0);

    const statements: any[] = [
      c.env.DB.prepare(
        `INSERT INTO delivery_trips (
          id, company_id, trip_number, driver_user_id, vehicle_number, route_area,
          status, started_at, total_orders, delivered_orders, failed_orders, total_amount_paise,
          collected_cash_paise, notes, created_by, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, 'PLANNED', ?, ?, 0, 0, ?, 0, ?, ?, ?, ?)`
      ).bind(
        tripId, user.company_id, tripNumber, driverId, body.vehicleNumber || 'RJ14-DEFAULT',
        body.routeArea || 'Jaipur Central', body.startTime || now, orders.length,
        totalAmount, body.notes || null, user.sub, now, now
      ),
      audit(c, 'TRIP_CREATED', tripId, { tripNumber, driverId, orderCount: orders.length })
    ];

    orderIds.forEach((orderId, index) => {
      const stopId = `stop_${tripId}_${index + 1}`;
      const ord = orders.find(o => o.id === orderId);
      statements.push(
        c.env.DB.prepare(
          `INSERT INTO delivery_trip_stops (
            id, trip_id, company_id, order_id, retailer_id, stop_sequence, status, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, 'PENDING', ?)`
        ).bind(stopId, tripId, user.company_id, orderId, ord.retailer_id, index + 1, now),
        c.env.DB.prepare(
          `UPDATE orders SET trip_id = ?, stop_sequence = ?, delivery_employee_id = ?, status = 'ASSIGNED_TO_TRIP', updated_at = ?
           WHERE id = ? AND company_id = ?`
        ).bind(tripId, index + 1, driverId, now, orderId, user.company_id)
      );
    });

    await c.env.DB.batch(statements);

    return c.json({
      id: tripId,
      tripNumber,
      driverUserId: driverId,
      driverId,
      driverName: driver.full_name,
      vehicleNumber: body.vehicleNumber || 'RJ14-DEFAULT',
      routeArea: body.routeArea || 'Jaipur Central',
      status: 'PLANNED',
      totalOrders: orders.length,
      totalStops: orders.length,
      completedStops: 0,
      failedStops: 0,
      totalAmountPaise: totalAmount,
      totalValuePaise: totalAmount,
      cashCollectedPaise: 0,
      createdAt: now
    }, 200);
  });

  // ──────────────────────────────────────────────────────────────
  // GET /trips/active
  // Get active trip for delivery executive (or driverId query for owner/admin).
  // ──────────────────────────────────────────────────────────────
  router.get('/active', async (c) => {
    const user = c.get('user');
    if (!allTripRoles.includes(user.role)) return bad(c, 'Permission denied', 403);

    let driverId: string;
    if (user.role === 'DELIVERY_EXECUTIVE') {
      driverId = user.sub;
    } else {
      const queryDriverId = c.req.query('driverId');
      if (!queryDriverId) {
        return bad(c, 'driverId query parameter required for management roles', 400);
      }
      driverId = queryDriverId;
    }

    const trip = await c.env.DB.prepare(
      `SELECT t.id, t.trip_number as tripNumber, t.driver_user_id as driverUserId,
              t.driver_user_id as driverId, u.full_name as driverName,
              t.vehicle_number as vehicleNumber, t.route_area as routeArea,
              t.status, t.started_at as startTime, t.started_at as startedAt,
              t.completed_at as endTime, t.total_orders as totalOrders,
              t.delivered_orders as deliveredOrders, t.failed_orders as failedOrders,
              t.total_amount_paise as totalAmountPaise, t.collected_cash_paise as cashCollectedPaise,
              t.created_at as createdAt
       FROM delivery_trips t
       JOIN users u ON u.id = t.driver_user_id
       WHERE t.company_id = ? AND t.driver_user_id = ? AND t.status IN ('PLANNED', 'OUT_FOR_DELIVERY', 'IN_TRANSIT')
       ORDER BY CASE WHEN t.status = 'OUT_FOR_DELIVERY' OR t.status = 'IN_TRANSIT' THEN 0 ELSE 1 END, t.created_at DESC
       LIMIT 1`
    ).bind(user.company_id, driverId).first<any>();

    if (!trip) return c.json(null);

    // Fetch stops with orders and retailer geo-coordinates
    const { results: stopsRaw } = await c.env.DB.prepare(
      `SELECT s.id as stopId, s.trip_id as tripId, s.order_id as orderId, s.retailer_id as retailerId,
              s.stop_sequence as sequenceOrder, s.status, s.arrived_at as arrivedAt,
              s.completed_at as completedAt, s.failure_reason as failureReason,
              r.name as retailerName, r.address, r.contact_number as contactNumber,
              r.latitude, r.longitude,
              o.total_amount_paise as totalAmountPaise, o.delivered_amount_paise as deliveredAmountPaise,
              o.status as orderStatus, o.delivery_failure_reason as deliveryFailureReason
       FROM delivery_trip_stops s
       JOIN retailers r ON r.id = s.retailer_id
       JOIN orders o ON o.id = s.order_id
       WHERE s.trip_id = ? AND s.company_id = ?
       ORDER BY s.stop_sequence ASC`
    ).bind(trip.id, user.company_id).all<any>();

    let completedStops = 0;
    let failedStops = 0;
    let totalValuePaise = 0;
    let cashCollectedPaise = 0;

    const stops = (stopsRaw || []).map((s: any) => {
      totalValuePaise += s.totalAmountPaise || 0;
      if (s.orderStatus === 'DELIVERED' || s.orderStatus === 'PARTIALLY_DELIVERED') {
        completedStops++;
        cashCollectedPaise += s.deliveredAmountPaise || s.totalAmountPaise || 0;
      } else if (s.orderStatus === 'DELIVERY_FAILED') {
        failedStops++;
      }

      return {
        stopId: s.stopId,
        orderId: s.orderId,
        retailerId: s.retailerId,
        retailerName: s.retailerName,
        address: s.address,
        contactNumber: s.contactNumber,
        latitude: s.latitude,
        longitude: s.longitude,
        sequenceOrder: s.sequenceOrder,
        totalAmountPaise: s.totalAmountPaise,
        status: s.orderStatus,
        deliveredAmountPaise: s.deliveredAmountPaise || 0,
        failureReason: s.deliveryFailureReason || s.failureReason
      };
    });

    return c.json({
      ...trip,
      totalStops: stops.length,
      completedStops,
      failedStops,
      totalValuePaise,
      cashCollectedPaise,
      stops
    });
  });

  // Alias /trips/active/current for client app
  router.get('/active/current', async (c) => {
    const user = c.get('user');
    if (!allTripRoles.includes(user.role)) return bad(c, 'Permission denied', 403);

    let driverId: string;
    if (user.role === 'DELIVERY_EXECUTIVE') {
      driverId = user.sub;
    } else {
      const queryDriverId = c.req.query('driverId');
      if (!queryDriverId) {
        return bad(c, 'driverId query parameter required for management roles', 400);
      }
      driverId = queryDriverId;
    }

    const trip = await c.env.DB.prepare(
      `SELECT t.id, t.trip_number as tripNumber, t.driver_user_id as driverUserId,
              t.driver_user_id as driverId, u.full_name as driverName,
              t.vehicle_number as vehicleNumber, t.route_area as routeArea,
              t.status, t.started_at as startTime, t.started_at as startedAt,
              t.completed_at as endTime, t.total_orders as totalOrders,
              t.delivered_orders as deliveredOrders, t.failed_orders as failedOrders,
              t.total_amount_paise as totalAmountPaise, t.collected_cash_paise as cashCollectedPaise,
              t.created_at as createdAt
       FROM delivery_trips t
       JOIN users u ON u.id = t.driver_user_id
       WHERE t.company_id = ? AND t.driver_user_id = ? AND t.status IN ('PLANNED', 'OUT_FOR_DELIVERY', 'IN_TRANSIT')
       ORDER BY CASE WHEN t.status = 'OUT_FOR_DELIVERY' OR t.status = 'IN_TRANSIT' THEN 0 ELSE 1 END, t.created_at DESC
       LIMIT 1`
    ).bind(user.company_id, driverId).first<any>();

    if (!trip) return c.json({ activeTrip: null });

    const { results: stopsRaw } = await c.env.DB.prepare(
      `SELECT s.id as stopId, s.trip_id as tripId, s.order_id as orderId, s.retailer_id as retailerId,
              s.stop_sequence as sequenceOrder, s.status, s.arrived_at as arrivedAt,
              s.completed_at as completedAt, s.failure_reason as failureReason,
              r.name as retailerName, r.address, r.contact_number as contactNumber,
              r.latitude, r.longitude,
              o.total_amount_paise as totalAmountPaise, o.delivered_amount_paise as deliveredAmountPaise,
              o.status as orderStatus, o.delivery_failure_reason as deliveryFailureReason
       FROM delivery_trip_stops s
       JOIN retailers r ON r.id = s.retailer_id
       JOIN orders o ON o.id = s.order_id
       WHERE s.trip_id = ? AND s.company_id = ?
       ORDER BY s.stop_sequence ASC`
    ).bind(trip.id, user.company_id).all<any>();

    const stops = (stopsRaw || []).map((s: any) => ({
      stopId: s.stopId,
      orderId: s.orderId,
      retailerId: s.retailerId,
      retailerName: s.retailerName,
      address: s.address,
      contactNumber: s.contactNumber,
      latitude: s.latitude,
      longitude: s.longitude,
      sequenceOrder: s.sequenceOrder,
      totalAmountPaise: s.totalAmountPaise,
      status: s.orderStatus,
      deliveredAmountPaise: s.deliveredAmountPaise || 0,
      failureReason: s.deliveryFailureReason || s.failureReason
    }));

    return c.json({ activeTrip: { ...trip, stops } });
  });

  // ──────────────────────────────────────────────────────────────
  // GET /trips
  // List trips with optional driverId or status filter.
  // ──────────────────────────────────────────────────────────────
  router.get('/', async (c) => {
    const user = c.get('user');
    if (!allTripRoles.includes(user.role)) return bad(c, 'Permission denied', 403);

    let query = `
      SELECT t.id, t.trip_number as tripNumber, t.driver_user_id as driverUserId,
             t.driver_user_id as driver_id, u.full_name as driver_name, u.full_name as driverName,
             t.vehicle_number as vehicle_number, t.vehicle_number as vehicleNumber,
             t.route_area as route_area, t.route_area as routeArea,
             t.status, t.started_at as start_time, t.started_at as startedAt,
             t.completed_at as end_time, t.completed_at as completedAt,
             t.total_orders as total_stops, t.total_orders as totalOrders,
             t.delivered_orders as deliveredOrders, t.failed_orders as failedOrders,
             t.total_amount_paise as totalAmountPaise, t.collected_cash_paise as cashCollectedPaise,
             t.created_at as created_at, t.created_at as createdAt
      FROM delivery_trips t
      JOIN users u ON u.id = t.driver_user_id
      WHERE t.company_id = ?
    `;
    const params: any[] = [user.company_id];

    if (user.role === 'DELIVERY_EXECUTIVE') {
      query += ' AND t.driver_user_id = ?';
      params.push(user.sub);
    } else {
      const driverId = c.req.query('driverId');
      if (driverId) {
        query += ' AND t.driver_user_id = ?';
        params.push(driverId);
      }
    }

    const status = c.req.query('status');
    if (status) {
      query += ' AND t.status = ?';
      params.push(status);
    }

    query += ' ORDER BY t.created_at DESC LIMIT 50';

    const { results } = await c.env.DB.prepare(query).bind(...params).all();
    return c.json(results || []);
  });

  // ──────────────────────────────────────────────────────────────
  // GET /trips/:id
  // Single trip detail.
  // ──────────────────────────────────────────────────────────────
  router.get('/:id', async (c) => {
    const user = c.get('user');
    if (!allTripRoles.includes(user.role)) return bad(c, 'Permission denied', 403);

    const tripId = c.req.param('id');
    const trip = await c.env.DB.prepare(
      `SELECT t.id, t.trip_number as tripNumber, t.driver_user_id as driverUserId,
              t.driver_user_id as driverId, u.full_name as driverName,
              t.vehicle_number as vehicleNumber, t.route_area as routeArea,
              t.status, t.started_at as startTime, t.started_at as startedAt,
              t.completed_at as endTime, t.completed_at as completedAt,
              t.total_orders as totalOrders, t.delivered_orders as deliveredOrders,
              t.failed_orders as failedOrders, t.total_amount_paise as totalAmountPaise,
              t.collected_cash_paise as cashCollectedPaise, t.notes, t.created_at as createdAt
       FROM delivery_trips t
       JOIN users u ON u.id = t.driver_user_id
       WHERE t.id = ? AND t.company_id = ?`
    ).bind(tripId, user.company_id).first<any>();

    if (!trip) return bad(c, 'Trip not found', 404);

    if (user.role === 'DELIVERY_EXECUTIVE' && trip.driverUserId !== user.sub) {
      return bad(c, 'Permission denied: not assigned to this trip', 403);
    }

    const { results: stopsRaw } = await c.env.DB.prepare(
      `SELECT s.id as stopId, s.trip_id as tripId, s.order_id as orderId, s.retailer_id as retailerId,
              s.stop_sequence as sequenceOrder, s.status, s.arrived_at as arrivedAt,
              s.completed_at as completedAt, s.failure_reason as failureReason,
              r.name as retailerName, r.address, r.contact_number as contactNumber,
              r.latitude, r.longitude,
              o.total_amount_paise as totalAmountPaise, o.delivered_amount_paise as deliveredAmountPaise,
              o.status as orderStatus, o.delivery_failure_reason as deliveryFailureReason
       FROM delivery_trip_stops s
       JOIN retailers r ON r.id = s.retailer_id
       JOIN orders o ON o.id = s.order_id
       WHERE s.trip_id = ? AND s.company_id = ?
       ORDER BY s.stop_sequence ASC`
    ).bind(tripId, user.company_id).all<any>();

    const stops = (stopsRaw || []).map((s: any) => ({
      stopId: s.stopId,
      orderId: s.orderId,
      retailerId: s.retailerId,
      retailerName: s.retailerName,
      address: s.address,
      contactNumber: s.contactNumber,
      latitude: s.latitude,
      longitude: s.longitude,
      sequenceOrder: s.sequenceOrder,
      totalAmountPaise: s.totalAmountPaise,
      status: s.orderStatus,
      deliveredAmountPaise: s.deliveredAmountPaise || 0,
      failureReason: s.deliveryFailureReason || s.failureReason
    }));

    return c.json({ ...trip, stops });
  });

  // ──────────────────────────────────────────────────────────────
  // PUT /trips/:id/reorder and PATCH /trips/:id/reorder
  // ──────────────────────────────────────────────────────────────
  const handleReorder = async (c: Ctx) => {
    const user = c.get('user');
    if (!allTripRoles.includes(user.role)) return bad(c, 'Permission denied', 403);

    const tripId = c.req.param('id');
    if (!tripId) return bad(c, 'Trip ID is required', 400);

    const trip = await c.env.DB.prepare(
      'SELECT id, driver_user_id, status FROM delivery_trips WHERE id = ? AND company_id = ?'
    ).bind(tripId, user.company_id).first<{ id: string; driver_user_id: string; status: string }>();

    if (!trip) return bad(c, 'Trip not found', 404);
    if (user.role === 'DELIVERY_EXECUTIVE' && trip.driver_user_id !== user.sub) {
      return bad(c, 'Permission denied', 403);
    }
    if (trip.status === 'COMPLETED' || trip.status === 'CANCELLED') {
      return bad(c, `Cannot reorder a trip with status ${trip.status}`, 400);
    }

    const body = await c.req.json<any>();
    const stopOrder = body.stopOrder; // Can be string[] of orderIds or object[] of { orderId, sequenceOrder }

    if (!Array.isArray(stopOrder) || stopOrder.length === 0) {
      return bad(c, 'stopOrder array is required', 400);
    }

    const reorderedIds = stopOrder.map((item: any) => typeof item === 'string' ? item : (item.orderId || item.stopId));
    if (new Set(reorderedIds).size !== reorderedIds.length) {
      return bad(c, 'Duplicate order IDs in stopOrder', 400);
    }

    const { results: existingStops } = await c.env.DB.prepare(
      'SELECT order_id FROM delivery_trip_stops WHERE trip_id = ? AND company_id = ?'
    ).bind(tripId, user.company_id).all<{ order_id: string }>();

    const tripOrderIds = new Set((existingStops || []).map(s => s.order_id));
    for (const orderId of reorderedIds) {
      if (!orderId || !tripOrderIds.has(orderId)) {
        return bad(c, `Order ${orderId} does not belong to trip ${tripId}`, 400);
      }
    }

    const now = Date.now();
    const statements: any[] = [];

    stopOrder.forEach((item: any, idx: number) => {
      const orderId = typeof item === 'string' ? item : (item.orderId || item.stopId);
      const seq = typeof item === 'object' && item.sequenceOrder ? item.sequenceOrder : idx + 1;
      statements.push(
        c.env.DB.prepare(
          'UPDATE delivery_trip_stops SET stop_sequence = ? WHERE trip_id = ? AND order_id = ? AND company_id = ?'
        ).bind(seq, tripId, orderId, user.company_id),
        c.env.DB.prepare(
          'UPDATE orders SET stop_sequence = ? WHERE id = ? AND company_id = ?'
        ).bind(seq, orderId, user.company_id)
      );
    });

    statements.push(
      c.env.DB.prepare('UPDATE delivery_trips SET updated_at = ? WHERE id = ?').bind(now, tripId),
      audit(c, 'TRIP_REORDERED', tripId, { count: stopOrder.length })
    );

    await c.env.DB.batch(statements);
    return c.json({ success: true });
  };

  router.put('/:id/reorder', handleReorder);
  router.patch('/:id/reorder', handleReorder);

  // ──────────────────────────────────────────────────────────────
  // POST /trips/:id/start
  // Start the delivery trip.
  // ──────────────────────────────────────────────────────────────
  router.post('/:id/start', async (c) => {
    const user = c.get('user');
    if (!allTripRoles.includes(user.role)) return bad(c, 'Permission denied', 403);

    const tripId = c.req.param('id');
    const trip = await c.env.DB.prepare(
      'SELECT id, driver_user_id, status FROM delivery_trips WHERE id = ? AND company_id = ?'
    ).bind(tripId, user.company_id).first<{ id: string; driver_user_id: string; status: string }>();

    if (!trip) return bad(c, 'Trip not found', 404);
    if (user.role === 'DELIVERY_EXECUTIVE' && trip.driver_user_id !== user.sub) {
      return bad(c, 'Permission denied', 403);
    }
    if (trip.status === 'CANCELLED' || trip.status === 'COMPLETED') {
      return bad(c, `Cannot start a trip with status ${trip.status}`, 400);
    }
    if (trip.status === 'OUT_FOR_DELIVERY' || trip.status === 'IN_TRANSIT') {
      return c.json({ success: true, idempotent: true, status: 'OUT_FOR_DELIVERY' });
    }

    const now = Date.now();
    const statements = [
      c.env.DB.prepare(
        "UPDATE delivery_trips SET status = 'OUT_FOR_DELIVERY', started_at = ?, updated_at = ? WHERE id = ?"
      ).bind(now, now, tripId),
      c.env.DB.prepare(
        `UPDATE orders SET status = 'OUT_FOR_DELIVERY', updated_at = ?
         WHERE trip_id = ? AND company_id = ? AND status IN ('ASSIGNED_TO_TRIP', 'PACKED', 'APPROVED')`
      ).bind(now, tripId, user.company_id),
      c.env.DB.prepare(
        `UPDATE delivery_trip_stops SET status = 'OUT_FOR_DELIVERY' WHERE trip_id = ? AND company_id = ?`
      ).bind(tripId, user.company_id),
      audit(c, 'TRIP_STARTED', tripId, { startedAt: now })
    ];

    await c.env.DB.batch(statements);
    return c.json({ success: true, status: 'OUT_FOR_DELIVERY', startedAt: now });
  });

  // ──────────────────────────────────────────────────────────────
  // POST /trips/:id/complete
  // Complete the delivery trip.
  // ──────────────────────────────────────────────────────────────
  router.post('/:id/complete', async (c) => {
    const user = c.get('user');
    if (!allTripRoles.includes(user.role)) return bad(c, 'Permission denied', 403);

    const tripId = c.req.param('id');
    const trip = await c.env.DB.prepare(
      'SELECT id, driver_user_id, status FROM delivery_trips WHERE id = ? AND company_id = ?'
    ).bind(tripId, user.company_id).first<{ id: string; driver_user_id: string; status: string }>();

    if (!trip) return bad(c, 'Trip not found', 404);
    if (user.role === 'DELIVERY_EXECUTIVE' && trip.driver_user_id !== user.sub) {
      return bad(c, 'Permission denied', 403);
    }
    if (trip.status === 'CANCELLED') {
      return bad(c, 'Cannot complete a cancelled trip', 400);
    }
    if (trip.status === 'COMPLETED') {
      return c.json({ success: true, idempotent: true, status: 'COMPLETED' });
    }

    const now = Date.now();
    const metrics = await c.env.DB.prepare(
      `SELECT
        COUNT(CASE WHEN o.status = 'DELIVERED' OR o.status = 'PARTIALLY_DELIVERED' THEN 1 END) as deliveredCount,
        COUNT(CASE WHEN o.status = 'DELIVERY_FAILED' THEN 1 END) as failedCount,
        COALESCE(SUM(CASE WHEN o.status = 'DELIVERED' THEN o.total_amount_paise WHEN o.status = 'PARTIALLY_DELIVERED' THEN o.delivered_amount_paise ELSE 0 END), 0) as cashExpected
       FROM delivery_trip_stops s
       JOIN orders o ON o.id = s.order_id
       WHERE s.trip_id = ? AND s.company_id = ?`
    ).bind(tripId, user.company_id).first<any>();

    await c.env.DB.batch([
      c.env.DB.prepare(
        `UPDATE delivery_trips
         SET status = 'COMPLETED', completed_at = ?, delivered_orders = ?, failed_orders = ?,
             collected_cash_paise = ?, updated_at = ?
         WHERE id = ?`
      ).bind(
        now, metrics?.deliveredCount || 0, metrics?.failedCount || 0,
        metrics?.cashExpected || 0, now, tripId
      ),
      audit(c, 'TRIP_COMPLETED', tripId, { completedAt: now, metrics })
    ]);

    return c.json({
      success: true,
      status: 'COMPLETED',
      completedAt: now,
      deliveredOrders: metrics?.deliveredCount || 0,
      failedOrders: metrics?.failedCount || 0
    });
  });

  return router;
}
