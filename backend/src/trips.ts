import { Hono } from 'hono';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

const trips = new Hono<{ Bindings: Bindings }>();

// Helper to sanitize schema if trip tables exist or dynamically ensure them
async function ensureTripSchema(db: D1Database) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS delivery_trips (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL,
      trip_number TEXT NOT NULL,
      driver_id TEXT NOT NULL,
      vehicle_number TEXT NOT NULL,
      route_area TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'CREATED',
      start_time INTEGER NOT NULL,
      end_time INTEGER,
      created_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS trip_stops (
      id TEXT PRIMARY KEY,
      trip_id TEXT NOT NULL,
      order_id TEXT NOT NULL,
      sequence_order INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (trip_id) REFERENCES delivery_trips(id),
      FOREIGN KEY (order_id) REFERENCES orders(id)
    )`)
  ]);
}

// POST /trips - Create new delivery trip
trips.post('/', async (c) => {
  const user = c.get('user');
  if (user.role !== 'OWNER' && user.role !== 'ADMIN' && user.role !== 'WAREHOUSE_MANAGER') {
    return c.json({ error: 'Permission denied' }, 403);
  }

  await ensureTripSchema(c.env.DB);
  const body = await c.req.json();
  const { driverId, vehicleNumber, routeArea, orderIds, startTime } = body;

  if (!driverId || !vehicleNumber || !orderIds || !Array.isArray(orderIds) || orderIds.length === 0) {
    return c.json({ error: 'Driver, vehicle, and orders are required' }, 400);
  }

  const driver = await c.env.DB.prepare('SELECT full_name FROM users WHERE id = ? AND company_id = ?').bind(driverId, user.company_id).first();
  if (!driver) return c.json({ error: 'Driver not found' }, 404);

  const tripId = `trip_${Date.now()}_${Math.random().toString(36).substr(2, 4)}`;
  const tripNumber = `TRIP-${Math.floor(1000 + Math.random() * 9000)}`;
  const now = Date.now();

  const batchStmts: any[] = [
    c.env.DB.prepare(`INSERT INTO delivery_trips (id, company_id, trip_number, driver_id, vehicle_number, route_area, status, start_time, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 'CREATED', ?, ?)`).bind(tripId, user.company_id, tripNumber, driverId, vehicleNumber, routeArea || 'General Area', startTime || now, now)
  ];

  orderIds.forEach((orderId: string, idx: number) => {
    const stopId = `stop_${tripId}_${idx}`;
    batchStmts.push(
      c.env.DB.prepare(`INSERT INTO trip_stops (id, trip_id, order_id, sequence_order, created_at) VALUES (?, ?, ?, ?, ?)`).bind(stopId, tripId, orderId, idx + 1, now)
    );
    batchStmts.push(
      c.env.DB.prepare(`UPDATE orders SET delivery_employee_id = ?, status = 'ASSIGNED_TO_TRIP', updated_at = ? WHERE id = ? AND company_id = ?`)
        .bind(driverId, now, orderId, user.company_id)
    );
  });

  await c.env.DB.batch(batchStmts);

  return c.json({
    id: tripId,
    tripNumber,
    driverId,
    driverName: driver.full_name,
    vehicleNumber,
    routeArea: routeArea || 'General Area',
    status: 'CREATED',
    startTime: startTime || now,
    totalStops: orderIds.length,
    completedStops: 0,
    failedStops: 0,
    cashCollectedPaise: 0
  });
});

// GET /trips/active - Get driver's active trip
trips.get('/active', async (c) => {
  const user = c.get('user');
  await ensureTripSchema(c.env.DB);

  let query = `SELECT t.*, u.full_name as driver_name FROM delivery_trips t
               JOIN users u ON t.driver_id = u.id
               WHERE t.company_id = ? AND t.status IN ('CREATED', 'IN_TRANSIT')`;
  const params: any[] = [user.company_id];

  if (user.role === 'DELIVERY_EXECUTIVE') {
    query += ` AND t.driver_id = ?`;
    params.push(user.sub);
  }
  query += ` ORDER BY t.created_at DESC LIMIT 1`;

  const trip: any = await c.env.DB.prepare(query).bind(...params).first();
  if (!trip) return c.json(null);

  // Fetch stops with orders & retailers
  const stopsQuery = `
    SELECT ts.sequence_order, o.id as order_id, o.status, o.total_amount_paise, o.delivered_amount_paise, o.delivery_failure_reason,
           r.id as retailer_id, r.name as retailer_name, r.address, r.latitude, r.longitude
    FROM trip_stops ts
    JOIN orders o ON ts.order_id = o.id
    JOIN retailers r ON o.retailer_id = r.id
    WHERE ts.trip_id = ?
    ORDER BY ts.sequence_order ASC
  `;

  const { results: stopsRaw } = await c.env.DB.prepare(stopsQuery).bind(trip.id).all();

  let completedStops = 0;
  let failedStops = 0;
  let totalValuePaise = 0;
  let cashCollectedPaise = 0;

  const stops = (stopsRaw || []).map((s: any) => {
    totalValuePaise += s.total_amount_paise || 0;
    if (s.status === 'DELIVERED' || s.status === 'PARTIALLY_DELIVERED') {
      completedStops++;
      cashCollectedPaise += s.delivered_amount_paise || s.total_amount_paise || 0;
    } else if (s.status === 'DELIVERY_FAILED') {
      failedStops++;
    }

    return {
      orderId: s.order_id,
      retailerId: s.retailer_id,
      retailerName: s.retailer_name,
      address: s.address,
      latitude: s.latitude,
      longitude: s.longitude,
      sequenceOrder: s.sequence_order,
      totalAmountPaise: s.total_amount_paise,
      status: s.status,
      deliveredAmountPaise: s.delivered_amount_paise || 0,
      failureReason: s.delivery_failure_reason
    };
  });

  return c.json({
    id: trip.id,
    tripNumber: trip.trip_number,
    driverId: trip.driver_id,
    driverName: trip.driver_name,
    vehicleNumber: trip.vehicle_number,
    routeArea: trip.route_area,
    status: trip.status,
    startTime: trip.start_time,
    endTime: trip.end_time,
    totalStops: stops.length,
    completedStops,
    failedStops,
    totalValuePaise,
    cashCollectedPaise,
    stops
  });
});

// GET /trips - List all trips
trips.get('/', async (c) => {
  const user = c.get('user');
  await ensureTripSchema(c.env.DB);

  const { results: tripsRaw } = await c.env.DB.prepare(`
    SELECT t.*, u.full_name as driver_name, COUNT(ts.id) as total_stops
    FROM delivery_trips t
    JOIN users u ON t.driver_id = u.id
    LEFT JOIN trip_stops ts ON t.id = ts.trip_id
    WHERE t.company_id = ?
    GROUP BY t.id
    ORDER BY t.created_at DESC
  `).bind(user.company_id).all();

  return c.json(tripsRaw || []);
});

// PUT /trips/:id/reorder - Reorder stops
trips.put('/:id/reorder', async (c) => {
  const user = c.get('user');
  const tripId = c.req.param('id');
  const { stopOrder } = await c.req.json(); // array of orderIds

  if (!stopOrder || !Array.isArray(stopOrder)) return c.json({ error: 'stopOrder required' }, 400);

  const batchStmts = stopOrder.map((orderId: string, idx: number) => {
    return c.env.DB.prepare(`UPDATE trip_stops SET sequence_order = ? WHERE trip_id = ? AND order_id = ?`)
      .bind(idx + 1, tripId, orderId);
  });

  await c.env.DB.batch(batchStmts);
  return c.json({ success: true });
});

// POST /trips/:id/start - Start trip
trips.post('/:id/start', async (c) => {
  const tripId = c.req.param('id');
  const now = Date.now();

  await c.env.DB.prepare(`UPDATE delivery_trips SET status = 'IN_TRANSIT' WHERE id = ?`).bind(tripId).run();

  // Set all assigned orders to OUT_FOR_DELIVERY if still assigned
  await c.env.DB.prepare(`
    UPDATE orders SET status = 'OUT_FOR_DELIVERY', updated_at = ?
    WHERE id IN (SELECT order_id FROM trip_stops WHERE trip_id = ?) AND status = 'ASSIGNED_TO_TRIP'
  `).bind(now, tripId).run();

  return c.json({ success: true });
});

// POST /trips/:id/complete - Complete trip
trips.post('/:id/complete', async (c) => {
  const tripId = c.req.param('id');
  const now = Date.now();

  await c.env.DB.prepare(`UPDATE delivery_trips SET status = 'COMPLETED', end_time = ? WHERE id = ?`).bind(now, tripId).run();
  return c.json({ success: true });
});

export default trips;
