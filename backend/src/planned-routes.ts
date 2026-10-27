import { Hono } from 'hono';
import { canPerform } from './security';

export function haversineDistanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000; // Earth radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function encodeSignedNumber(num: number): string {
  let sgn_num = num < 0 ? ~(num << 1) : (num << 1);
  let encodeString = '';
  while (sgn_num >= 0x20) {
    encodeString += String.fromCharCode((0x20 | (sgn_num & 0x1f)) + 63);
    sgn_num >>= 5;
  }
  encodeString += String.fromCharCode(sgn_num + 63);
  return encodeString;
}

export function encodePolyline6(points: Array<[number, number]>): string {
  let result = '';
  let lastLat = 0;
  let lastLon = 0;

  for (const [lat, lon] of points) {
    const late6 = Math.round(lat * 1e6);
    const lone6 = Math.round(lon * 1e6);

    const dLat = late6 - lastLat;
    const dLon = lone6 - lastLon;

    lastLat = late6;
    lastLon = lone6;

    result += encodeSignedNumber(dLat) + encodeSignedNumber(dLon);
  }
  return result;
}

export function decodePolyline6(str: string): Array<[number, number]> {
  let index = 0, lat = 0, lng = 0;
  const coordinates: Array<[number, number]> = [];
  const factor = 1e6;

  while (index < str.length) {
    let b, shift = 0, result = 0;
    do {
      b = str.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = ((result & 1) ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = str.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = ((result & 1) ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    coordinates.push([lat / factor, lng / factor]);
  }
  return coordinates;
}

export async function calculateRoadRoute(
  coords: Array<{ latitude: number; longitude: number }>,
  osrmBaseUrl: string = 'https://router.project-osrm.org'
): Promise<{
  distanceMeters: number;
  durationSeconds: number;
  geometry: string | null;
  isFallback: boolean;
  provider: string;
}> {
  if (!coords || coords.length < 2) {
    return {
      distanceMeters: 0,
      durationSeconds: 0,
      geometry: null,
      isFallback: false,
      provider: 'NONE'
    };
  }

  // Format lon,lat coordinates semicolon-separated (OSRM expects longitude first, latitude second)
  const coordsParam = coords.map(c => `${c.longitude.toFixed(6)},${c.latitude.toFixed(6)}`).join(';');
  const url = `${osrmBaseUrl.replace(/\/$/, '')}/route/v1/driving/${coordsParam}?overview=full&geometries=polyline6&steps=false`;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const res = await fetch(url, {
      signal: controller.signal,
      headers: { 'Accept': 'application/json' }
    });
    clearTimeout(timeoutId);

    if (res.ok) {
      const data: any = await res.json();
      if (data.code === 'Ok' && data.routes && data.routes.length > 0) {
        const route = data.routes[0];
        return {
          distanceMeters: Math.round(route.distance),
          durationSeconds: Math.round(route.duration),
          geometry: route.geometry,
          isFallback: false,
          provider: 'OSRM'
        };
      }
    }
  } catch {
    // Network error, timeout, or OSRM outage
  }

  // Fallback straight-line calculation
  let totalDistance = 0;
  const polyPoints: Array<[number, number]> = [];
  for (let i = 0; i < coords.length; i++) {
    polyPoints.push([coords[i].latitude, coords[i].longitude]);
    if (i > 0) {
      totalDistance += haversineDistanceMeters(
        coords[i - 1].latitude, coords[i - 1].longitude,
        coords[i].latitude, coords[i].longitude
      );
    }
  }

  // Estimated driving speed 25 km/h in city traffic (6.94 m/s)
  const estimatedSeconds = Math.round(totalDistance / (25 * 1000 / 3600));

  return {
    distanceMeters: Math.round(totalDistance),
    durationSeconds: estimatedSeconds,
    geometry: encodePolyline6(polyPoints),
    isFallback: true,
    provider: 'HAVERSINE_FALLBACK'
  };
}

export function plannedRoutesRouter(authMiddleware: any) {
  const router = new Hono<{ Bindings: any; Variables: { user: any } }>();
  router.use('*', authMiddleware);

  // 1. Calculate road route between manual coordinates via OSRM gateway
  router.post('/calculate-road', async (c) => {
  const user = c.get('user');
  if (!canPerform(user.role, 'route:plan') && !canPerform(user.role, 'route:read')) {
    return c.json({ error: 'Permission denied: route planning or execution permission required' }, 403);
  }

  const body = await c.req.json().catch(() => ({}));
  const coordinates = body.coordinates;

  if (!Array.isArray(coordinates)) {
    return c.json({ error: 'coordinates array is required' }, 400);
  }

  for (let i = 0; i < coordinates.length; i++) {
    const pt = coordinates[i];
    if (typeof pt.latitude !== 'number' || typeof pt.longitude !== 'number' ||
        isNaN(pt.latitude) || isNaN(pt.longitude) ||
        pt.latitude < -90 || pt.latitude > 90 ||
        pt.longitude < -180 || pt.longitude > 180) {
      return c.json({ error: `Invalid coordinate at index ${i}: latitude must be [-90, 90] and longitude [-180, 180]` }, 400);
    }
  }

  const osrmBaseUrl = c.env.OSRM_BASE_URL || 'https://router.project-osrm.org';
  const result = await calculateRoadRoute(coordinates, osrmBaseUrl);

  return c.json({
    success: true,
    ...result
  });
});

// 2. List planned routes (Tenant scoped, RBAC scoped)
router.get('/', async (c) => {
  const user = c.get('user');
  const dateFilter = c.req.query('date');
  const salespersonFilter = c.req.query('salesperson_id');
  const statusFilter = c.req.query('status');

  const isPlanner = canPerform(user.role, 'route:plan');
  const isSales = canPerform(user.role, 'route:read');

  if (!isPlanner && !isSales) {
    return c.json({ error: 'Permission denied: unauthorized role for planned routes' }, 403);
  }

  let query = 'SELECT * FROM planned_routes WHERE company_id = ?';
  const params: any[] = [user.company_id];

  if (!isPlanner) {
    // Salesperson can ONLY see their own PUBLISHED routes
    query += ' AND salesperson_id = ? AND status = ?';
    params.push(user.sub, 'PUBLISHED');
  } else {
    // Owner / Admin can filter
    if (salespersonFilter) {
      query += ' AND salesperson_id = ?';
      params.push(salespersonFilter);
    }
    if (statusFilter) {
      query += ' AND status = ?';
      params.push(statusFilter);
    }
  }

  if (dateFilter) {
    query += ' AND route_date = ?';
    params.push(dateFilter);
  }

  query += ' ORDER BY route_date DESC, created_at DESC';

  const { results: routes } = await c.env.DB.prepare(query).bind(...params).all();
  return c.json({ success: true, routes: routes || [] });
});

// 3. Get single planned route with stops
router.get('/:id', async (c) => {
  const user = c.get('user');
  const routeId = c.req.param('id');

  const route = await c.env.DB.prepare('SELECT * FROM planned_routes WHERE id = ? AND company_id = ?')
    .bind(routeId, user.company_id)
    .first() as any;

  if (!route) {
    return c.json({ error: 'Planned route not found' }, 404);
  }

  const isPlanner = canPerform(user.role, 'route:plan');
  if (!isPlanner) {
    // Salesperson can ONLY view their own published routes
    if (route.salesperson_id !== user.sub || route.status !== 'PUBLISHED') {
      return c.json({ error: 'Permission denied: cannot access another user or draft route' }, 403);
    }
  }

  const { results: stops } = await c.env.DB.prepare(
    'SELECT * FROM planned_route_stops WHERE route_id = ? AND company_id = ? ORDER BY stop_sequence ASC'
  ).bind(routeId, user.company_id).all();

  return c.json({
    success: true,
    route,
    stops: stops || []
  });
});

// 4. Create new planned route (DRAFT)
router.post('/', async (c) => {
  try {
    const user = c.get('user');
    if (!canPerform(user.role, 'route:plan')) {
      return c.json({ error: 'Permission denied: owner or admin role required to plan routes' }, 403);
    }

  const body = await c.req.json().catch(() => ({}));
  const { routeDate, name, salespersonId, stops } = body;

  if (!routeDate || typeof routeDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(routeDate)) {
    return c.json({ error: 'routeDate is required in YYYY-MM-DD format' }, 400);
  }

  if (!name || typeof name !== 'string' || !name.trim()) {
    return c.json({ error: 'name is required' }, 400);
  }

  if (!salespersonId || typeof salespersonId !== 'string') {
    return c.json({ error: 'salespersonId is required' }, 400);
  }

  // Validate salesperson exists, is in company, is active, and has SALESPERSON role
  const salesperson = await c.env.DB.prepare(
    'SELECT id, full_name, role, is_active FROM users WHERE id = ? AND company_id = ?'
  ).bind(salespersonId, user.company_id).first() as any;

  if (!salesperson) {
    return c.json({ error: 'Salesperson not found in organization' }, 404);
  }
  if (salesperson.is_active === 0) {
    return c.json({ error: 'Cannot assign route to deactivated salesperson' }, 400);
  }
  if (salesperson.role !== 'SALESPERSON') {
    return c.json({ error: `User is not a salesperson (role: ${salesperson.role})` }, 400);
  }

  const stopList = Array.isArray(stops) ? stops : [];
  const retailerIds = new Set<string>();
  const sequences = new Set<number>();

  for (let i = 0; i < stopList.length; i++) {
    const s = stopList[i];
    if (!s.retailerId) {
      return c.json({ error: `Stop at index ${i} is missing retailerId` }, 400);
    }
    if (retailerIds.has(s.retailerId)) {
      return c.json({ error: `Duplicate stop for retailer ${s.retailerId} is not permitted on the same route` }, 400);
    }
    retailerIds.add(s.retailerId);

    const seq = s.stopSequence !== undefined ? Number(s.stopSequence) : i + 1;
    if (isNaN(seq) || seq < 1) {
      return c.json({ error: `Stop sequence must be a positive integer` }, 400);
    }
    if (sequences.has(seq)) {
      return c.json({ error: `Duplicate stop sequence ${seq} on the same route` }, 400);
    }
    sequences.add(seq);
  }

  // Fetch all retailers in one batch and validate
  const stopDetails: any[] = [];
  const coords: Array<{ latitude: number; longitude: number }> = [];

  for (let i = 0; i < stopList.length; i++) {
    const s = stopList[i];
    const seq = s.stopSequence !== undefined ? Number(s.stopSequence) : i + 1;
    const ret = await c.env.DB.prepare(
      'SELECT id, name, address, contact_number, latitude, longitude, is_active FROM retailers WHERE id = ? AND company_id = ?'
    ).bind(s.retailerId, user.company_id).first() as any;

    if (!ret) {
      return c.json({ error: `Retailer ${s.retailerId} not found` }, 404);
    }
    if (ret.is_active === 0) {
      return c.json({ error: `Cannot include deactivated retailer ${ret.name} in route` }, 400);
    }

    const lat = ret.latitude || 0;
    const lng = ret.longitude || 0;

    stopDetails.push({
      id: crypto.randomUUID(),
      retailerId: ret.id,
      retailerName: ret.name,
      stopSequence: seq,
      address: ret.address || '',
      contactNumber: ret.contact_number || '',
      latitude: lat,
      longitude: lng,
      notes: s.notes || null
    });

    if (lat !== 0 || lng !== 0) {
      coords.push({ latitude: lat, longitude: lng });
    }
  }

  // Sort stops by sequence
  stopDetails.sort((a, b) => a.stopSequence - b.stopSequence);

  // Calculate road metrics via OSRM
  const osrmBaseUrl = c.env.OSRM_BASE_URL || 'https://router.project-osrm.org';
  const routing = await calculateRoadRoute(coords, osrmBaseUrl);

  const routeId = crypto.randomUUID();
  const now = Date.now();

  const statements = [
    c.env.DB.prepare(`
      INSERT INTO planned_routes (
        id, company_id, route_date, name, salesperson_id, salesperson_name,
        status, total_stops, road_distance_meters, road_duration_seconds,
        route_geometry, routing_provider, routing_calculated_at, version,
        created_by, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      routeId, user.company_id, routeDate, name.trim(), salesperson.id, salesperson.full_name,
      'DRAFT', stopDetails.length, routing.distanceMeters, routing.durationSeconds,
      routing.geometry, routing.provider, now, 1,
      user.sub, now, now
    )
  ];

  for (const stop of stopDetails) {
    statements.push(
      c.env.DB.prepare(`
        INSERT INTO planned_route_stops (
          id, route_id, company_id, retailer_id, retailer_name, stop_sequence,
          address, contact_number, latitude, longitude, status, notes, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(
        stop.id, routeId, user.company_id, stop.retailerId, stop.retailerName, stop.stopSequence,
        stop.address, stop.contactNumber, stop.latitude, stop.longitude, 'PENDING', stop.notes, now, now
      )
    );
  }

  statements.push(
    c.env.DB.prepare(`
      INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).bind(
      crypto.randomUUID(), user.company_id, user.sub, 'ROUTE_CREATED', routeId,
      `Draft route "${name.trim()}" created with ${stopDetails.length} stops for ${salesperson.full_name}`, now
    )
  );

  await c.env.DB.batch(statements);

  const createdRoute = await c.env.DB.prepare('SELECT * FROM planned_routes WHERE id = ?').bind(routeId).first();
  const { results: createdStops } = await c.env.DB.prepare(
    'SELECT * FROM planned_route_stops WHERE route_id = ? ORDER BY stop_sequence ASC'
  ).bind(routeId).all();

  return c.json({
    success: true,
    route: createdRoute,
    stops: createdStops || []
  });
  } catch (err: any) {
    console.error('POST /planned-routes caught error:', err);
    return c.json({ error: err.message, stack: err.stack }, 500);
  }
});

// 5. Update planned route (DRAFT only)
router.put('/:id', async (c) => {
  const user = c.get('user');
  if (!canPerform(user.role, 'route:plan')) {
    return c.json({ error: 'Permission denied: owner or admin role required' }, 403);
  }

  const routeId = c.req.param('id');
  const existing = await c.env.DB.prepare('SELECT * FROM planned_routes WHERE id = ? AND company_id = ?')
    .bind(routeId, user.company_id)
    .first() as any;

  if (!existing) {
    return c.json({ error: 'Route not found' }, 404);
  }
  if (existing.status !== 'DRAFT') {
    return c.json({ error: `Cannot modify route with status ${existing.status}. Only DRAFT routes can be edited.` }, 400);
  }

  const body = await c.req.json().catch(() => ({}));
  const routeDate = body.routeDate || existing.route_date;
  const name = body.name ? body.name.trim() : existing.name;
  const salespersonId = body.salespersonId || existing.salesperson_id;
  const stopList = Array.isArray(body.stops) ? body.stops : null;

  // Validate salesperson
  const salesperson = await c.env.DB.prepare(
    'SELECT id, full_name, role, is_active FROM users WHERE id = ? AND company_id = ?'
  ).bind(salespersonId, user.company_id).first() as any;

  if (!salesperson) return c.json({ error: 'Salesperson not found' }, 404);
  if (salesperson.is_active === 0) return c.json({ error: 'Cannot assign route to deactivated salesperson' }, 400);
  if (salesperson.role !== 'SALESPERSON') return c.json({ error: 'User is not a salesperson' }, 400);

  const now = Date.now();
  const statements: any[] = [];

  if (stopList !== null) {
    // Validate new stops
    const retailerIds = new Set<string>();
    const sequences = new Set<number>();
    const stopDetails: any[] = [];
    const coords: Array<{ latitude: number; longitude: number }> = [];

    for (let i = 0; i < stopList.length; i++) {
      const s = stopList[i];
      if (!s.retailerId) return c.json({ error: `Stop at index ${i} is missing retailerId` }, 400);
      if (retailerIds.has(s.retailerId)) return c.json({ error: `Duplicate stop for retailer ${s.retailerId}` }, 400);
      retailerIds.add(s.retailerId);

      const seq = s.stopSequence !== undefined ? Number(s.stopSequence) : i + 1;
      if (isNaN(seq) || seq < 1) return c.json({ error: `Invalid stop sequence` }, 400);
      if (sequences.has(seq)) return c.json({ error: `Duplicate stop sequence ${seq}` }, 400);
      sequences.add(seq);

      const ret = await c.env.DB.prepare(
        'SELECT id, name, address, contact_number, latitude, longitude, is_active FROM retailers WHERE id = ? AND company_id = ?'
      ).bind(s.retailerId, user.company_id).first() as any;

      if (!ret) return c.json({ error: `Retailer ${s.retailerId} not found` }, 404);
      if (ret.is_active === 0) return c.json({ error: `Cannot include deactivated retailer ${ret.name}` }, 400);

      const lat = ret.latitude || 0;
      const lng = ret.longitude || 0;

      stopDetails.push({
        id: crypto.randomUUID(),
        retailerId: ret.id,
        retailerName: ret.name,
        stopSequence: seq,
        address: ret.address || '',
        contactNumber: ret.contact_number || '',
        latitude: lat,
        longitude: lng,
        notes: s.notes || null
      });

      if (lat !== 0 || lng !== 0) coords.push({ latitude: lat, longitude: lng });
    }

    stopDetails.sort((a, b) => a.stopSequence - b.stopSequence);

    const osrmBaseUrl = c.env.OSRM_BASE_URL || 'https://router.project-osrm.org';
    const routing = await calculateRoadRoute(coords, osrmBaseUrl);

    // Delete existing stops and re-insert
    statements.push(
      c.env.DB.prepare('DELETE FROM planned_route_stops WHERE route_id = ?').bind(routeId)
    );

    for (const stop of stopDetails) {
      statements.push(
        c.env.DB.prepare(`
          INSERT INTO planned_route_stops (
            id, route_id, company_id, retailer_id, retailer_name, stop_sequence,
            address, contact_number, latitude, longitude, status, notes, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).bind(
          stop.id, routeId, user.company_id, stop.retailerId, stop.retailerName, stop.stopSequence,
          stop.address, stop.contactNumber, stop.latitude, stop.longitude, 'PENDING', stop.notes, now, now
        )
      );
    }

    statements.push(
      c.env.DB.prepare(`
        UPDATE planned_routes SET
          route_date = ?, name = ?, salesperson_id = ?, salesperson_name = ?,
          total_stops = ?, road_distance_meters = ?, road_duration_seconds = ?,
          route_geometry = ?, routing_provider = ?, routing_calculated_at = ?,
          version = version + 1, updated_at = ?
        WHERE id = ? AND company_id = ?
      `).bind(
        routeDate, name, salesperson.id, salesperson.full_name,
        stopDetails.length, routing.distanceMeters, routing.durationSeconds,
        routing.geometry, routing.provider, now, now, routeId, user.company_id
      )
    );
  } else {
    // Just update metadata
    statements.push(
      c.env.DB.prepare(`
        UPDATE planned_routes SET
          route_date = ?, name = ?, salesperson_id = ?, salesperson_name = ?,
          version = version + 1, updated_at = ?
        WHERE id = ? AND company_id = ?
      `).bind(routeDate, name, salesperson.id, salesperson.full_name, now, routeId, user.company_id)
    );
  }

  await c.env.DB.batch(statements);

  const updatedRoute = await c.env.DB.prepare('SELECT * FROM planned_routes WHERE id = ?').bind(routeId).first();
  const { results: updatedStops } = await c.env.DB.prepare(
    'SELECT * FROM planned_route_stops WHERE route_id = ? ORDER BY stop_sequence ASC'
  ).bind(routeId).all();

  return c.json({
    success: true,
    route: updatedRoute,
    stops: updatedStops || []
  });
});

// 6. Publish route (Atomic validation, strictly does NOT touch stock or orders)
router.post('/:id/publish', async (c) => {
  const user = c.get('user');
  if (!canPerform(user.role, 'route:publish')) {
    return c.json({ error: 'Permission denied: owner or admin role required to publish routes' }, 403);
  }

  const routeId = c.req.param('id');
  const route = await c.env.DB.prepare('SELECT * FROM planned_routes WHERE id = ? AND company_id = ?')
    .bind(routeId, user.company_id)
    .first() as any;

  if (!route) {
    return c.json({ error: 'Planned route not found' }, 404);
  }

  if (route.status === 'PUBLISHED') {
    return c.json({ success: true, idempotent: true, route });
  }

  if (route.status !== 'DRAFT') {
    return c.json({ error: `Cannot publish route with status ${route.status}` }, 400);
  }

  // Ensure route has at least 1 stop
  if (route.total_stops < 1) {
    return c.json({ error: 'Cannot publish a route with zero stops' }, 400);
  }

  // Ensure salesperson is still active
  const salesperson = await c.env.DB.prepare('SELECT id, is_active FROM users WHERE id = ? AND company_id = ?')
    .bind(route.salesperson_id, user.company_id).first() as any;
  if (!salesperson || salesperson.is_active === 0) {
    return c.json({ error: 'Cannot publish route: assigned salesperson is inactive or not found' }, 400);
  }

  // Ensure all retailers are still active
  const { results: stops } = await c.env.DB.prepare('SELECT retailer_id, stop_sequence FROM planned_route_stops WHERE route_id = ?')
    .bind(routeId).all();

  for (const s of (stops as any[])) {
    const ret = await c.env.DB.prepare('SELECT id, name, is_active FROM retailers WHERE id = ? AND company_id = ?')
      .bind(s.retailer_id, user.company_id).first() as any;
    if (!ret || ret.is_active === 0) {
      return c.json({ error: `Cannot publish route: retailer ${ret?.name || s.retailer_id} is inactive` }, 400);
    }
  }

  const now = Date.now();
  const statements = [
    c.env.DB.prepare(`
      UPDATE planned_routes SET
        status = 'PUBLISHED', published_at = ?, published_by = ?, updated_at = ?
      WHERE id = ? AND status = 'DRAFT'
    `).bind(now, user.sub, now, routeId),
    c.env.DB.prepare(`
      INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).bind(
      crypto.randomUUID(), user.company_id, user.sub, 'ROUTE_PUBLISHED', routeId,
      `Route "${route.name}" published for ${route.salesperson_name} with ${route.total_stops} stops`, now
    )
  ];

  await c.env.DB.batch(statements);

  const publishedRoute = await c.env.DB.prepare('SELECT * FROM planned_routes WHERE id = ?').bind(routeId).first();
  return c.json({
    success: true,
    route: publishedRoute
  });
});

// 7. Cancel route
router.post('/:id/cancel', async (c) => {
  const user = c.get('user');
  if (!canPerform(user.role, 'route:publish')) {
    return c.json({ error: 'Permission denied: owner or admin role required to cancel routes' }, 403);
  }

  const routeId = c.req.param('id');
  const route = await c.env.DB.prepare('SELECT * FROM planned_routes WHERE id = ? AND company_id = ?')
    .bind(routeId, user.company_id)
    .first() as any;

  if (!route) {
    return c.json({ error: 'Planned route not found' }, 404);
  }

  if (route.status === 'CANCELLED') {
    return c.json({ success: true, idempotent: true });
  }

  const body = await c.req.json().catch(() => ({}));
  const reason = body.reason?.trim() || 'Cancelled by manager';
  const now = Date.now();

  const statements = [
    c.env.DB.prepare(`
      UPDATE planned_routes SET
        status = 'CANCELLED', cancelled_at = ?, cancelled_by = ?,
        cancellation_reason = ?, updated_at = ?
      WHERE id = ?
    `).bind(now, user.sub, reason, now, routeId),
    c.env.DB.prepare(`
      INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).bind(
      crypto.randomUUID(), user.company_id, user.sub, 'ROUTE_CANCELLED', routeId,
      `Route "${route.name}" cancelled: ${reason}`, now
    )
  ];

  await c.env.DB.batch(statements);

  return c.json({ success: true });
});

// 8. Update individual stop status (Salesperson field action)
router.post('/:routeId/stops/:stopId/status', async (c) => {
  const user = c.get('user');
  const routeId = c.req.param('routeId');
  const stopId = c.req.param('stopId');

  const route = await c.env.DB.prepare('SELECT * FROM planned_routes WHERE id = ? AND company_id = ?')
    .bind(routeId, user.company_id)
    .first() as any;

  if (!route) {
    return c.json({ error: 'Route not found' }, 404);
  }

  const isPlanner = canPerform(user.role, 'route:plan');
  if (!isPlanner) {
    // Salesperson can only update stops on their assigned published routes
    if (route.salesperson_id !== user.sub || route.status !== 'PUBLISHED') {
      return c.json({ error: 'Permission denied: stop can only be updated by the assigned salesperson on a published route' }, 403);
    }
  }

  const stop = await c.env.DB.prepare('SELECT * FROM planned_route_stops WHERE id = ? AND route_id = ? AND company_id = ?')
    .bind(stopId, routeId, user.company_id)
    .first() as any;

  if (!stop) {
    return c.json({ error: 'Stop not found on this route' }, 404);
  }

  const body = await c.req.json().catch(() => ({}));
  const status = body.status;
  const notes = body.notes !== undefined ? String(body.notes) : stop.notes;

  if (status !== 'VISITED' && status !== 'SKIPPED' && status !== 'PENDING') {
    return c.json({ error: 'Status must be VISITED, SKIPPED, or PENDING' }, 400);
  }

  const now = Date.now();
  const visitedAt = status === 'VISITED' ? (stop.visited_at || now) : null;

  await c.env.DB.prepare(`
    UPDATE planned_route_stops SET
      status = ?, visited_at = ?, notes = ?, updated_at = ?
    WHERE id = ? AND route_id = ?
  `).bind(status, visitedAt, notes, now, stopId, routeId).run();

  const updatedStop = await c.env.DB.prepare('SELECT * FROM planned_route_stops WHERE id = ?').bind(stopId).first();

  return c.json({
    success: true,
    stop: updatedStop
  });
});

  return router;
}
