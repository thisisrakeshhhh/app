import { test, before } from 'node:test';
import assert from 'node:assert/strict';

const base = process.env.ROUTEFLOW_TEST_URL;
if (!base) throw new Error('Use run-isolated.mjs to execute planned route tests');

const tokens = {};

async function req(role, path, body, method) {
  const r = await fetch(base + path, {
    method: method || (body ? 'POST' : 'GET'),
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokens[role]}`,
      'X-Test-Runner': 'true',
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const data = await r.json().catch(() => ({}));
  if (Array.isArray(data)) {
    data.httpStatus = r.status;
    return data;
  }
  return { httpStatus: r.status, ...data };
}

const ok = (r) => {
  assert.equal(r.httpStatus, 200, JSON.stringify(r));
  return r;
};

before(async () => {
  for (const role of ['owner', 'sales', 'warehouse', 'delivery', 'admin', 'owner_comp2', 'sales_comp2']) {
    const res = await req(role, '/auth/login', { username: role, password: 'password123' });
    tokens[role] = res.access_token;
  }
});

test('1. Calculate Road Route: 0/1 coords, validation, and multi-stop calculation', async () => {
  // Empty coordinates: returns 0 immediately without error
  const emptyRes = ok(await req('owner', '/planned-routes/calculate-road', { coordinates: [] }));
  assert.equal(emptyRes.distanceMeters, 0);
  assert.equal(emptyRes.durationSeconds, 0);

  // Single coordinate: returns 0 immediately
  const singleRes = ok(await req('owner', '/planned-routes/calculate-road', {
    coordinates: [{ latitude: 30.7333, longitude: 76.7794 }]
  }));
  assert.equal(singleRes.distanceMeters, 0);
  assert.equal(singleRes.durationSeconds, 0);

  // Invalid coordinates: latitude > 90
  const invalidRes = await req('owner', '/planned-routes/calculate-road', {
    coordinates: [
      { latitude: 95.0, longitude: 76.7794 },
      { latitude: 30.7333, longitude: 76.7794 }
    ]
  });
  assert.equal(invalidRes.httpStatus, 400);

  // Two valid coordinates (Chandigarh Sector 17 to Sector 22)
  const calcRes = ok(await req('owner', '/planned-routes/calculate-road', {
    coordinates: [
      { latitude: 30.7333, longitude: 76.7794 },
      { latitude: 30.7250, longitude: 76.7700 }
    ]
  }));
  assert.ok(calcRes.distanceMeters > 500, `Expected distance > 500m, got ${calcRes.distanceMeters}`);
  assert.ok(calcRes.durationSeconds > 10, `Expected duration > 10s, got ${calcRes.durationSeconds}`);
  assert.ok(calcRes.provider === 'OSRM' || calcRes.provider === 'HAVERSINE_FALLBACK');
});

test('2. Role Access Control: Salesperson cannot create or publish routes', async () => {
  const denyCreate = await req('sales', '/planned-routes', {
    routeDate: '2026-10-27',
    name: 'Unauthorized Route',
    salespersonId: 'user_sales',
    stops: [{ retailerId: 'R1', stopSequence: 1 }]
  });
  assert.equal(denyCreate.httpStatus, 403, 'Salesperson should not be allowed to create routes');

  const denyPublish = await req('sales', '/planned-routes/fake_id/publish', {});
  assert.equal(denyPublish.httpStatus, 403, 'Salesperson should not be allowed to publish routes');
});

test('3. Owner Route Planning: Validation of duplicates, sequences, and DRAFT creation', async () => {
  // Reject duplicate retailer on same route
  const dupRetailerRes = await req('owner', '/planned-routes', {
    routeDate: '2026-10-27',
    name: 'Tricity Daily Morning Route',
    salespersonId: 'user_sales',
    stops: [
      { retailerId: 'R1', stopSequence: 1 },
      { retailerId: 'R1', stopSequence: 2 }
    ]
  });
  assert.equal(dupRetailerRes.httpStatus, 400);
  assert.match(dupRetailerRes.error, /Duplicate stop for retailer/i);

  // Reject duplicate stop sequence
  const dupSeqRes = await req('owner', '/planned-routes', {
    routeDate: '2026-10-27',
    name: 'Tricity Daily Morning Route',
    salespersonId: 'user_sales',
    stops: [
      { retailerId: 'R1', stopSequence: 1 },
      { retailerId: 'R2', stopSequence: 1 }
    ]
  });
  assert.equal(dupSeqRes.httpStatus, 400);
  assert.match(dupSeqRes.error, /Duplicate stop sequence/i);

  // Successful DRAFT creation with 2 stops
  const createRes = ok(await req('owner', '/planned-routes', {
    routeDate: '2026-10-27',
    name: 'Chandigarh Sector 17-22 Beat',
    salespersonId: 'user_sales',
    stops: [
      { retailerId: 'R1', stopSequence: 1, notes: 'Collect pending payment' },
      { retailerId: 'R2', stopSequence: 2, notes: 'Introduce new biscuit batch' }
    ]
  }));

  assert.ok(createRes.route);
  assert.equal(createRes.route.status, 'DRAFT');
  assert.equal(createRes.route.total_stops, 2);
  assert.equal(createRes.stops.length, 2);
  assert.equal(createRes.stops[0].retailer_id, 'R1');
  assert.equal(createRes.stops[0].stop_sequence, 1);
  assert.equal(createRes.stops[1].retailer_id, 'R2');
  assert.equal(createRes.stops[1].stop_sequence, 2);

  const routeId = createRes.route.id;

  // Salesperson cannot see DRAFT routes
  const salesListBeforePublish = ok(await req('sales', '/planned-routes'));
  const foundInDraft = (salesListBeforePublish.routes || []).find(r => r.id === routeId);
  assert.equal(foundInDraft, undefined, 'Salesperson must not see unpublished draft route');

  // Owner can update DRAFT route (e.g. swap stop sequence)
  const updateRes = ok(await req('owner', `/planned-routes/${routeId}`, {
    routeDate: '2026-10-27',
    name: 'Chandigarh Sector 17-22 Beat (Reordered)',
    salespersonId: 'user_sales',
    stops: [
      { retailerId: 'R2', stopSequence: 1, notes: 'Visit R2 first now' },
      { retailerId: 'R1', stopSequence: 2, notes: 'Visit R1 second' }
    ]
  }, 'PUT'));

  assert.equal(updateRes.route.name, 'Chandigarh Sector 17-22 Beat (Reordered)');
  assert.equal(updateRes.stops[0].retailer_id, 'R2');
  assert.equal(updateRes.stops[0].stop_sequence, 1);
  assert.equal(updateRes.stops[1].retailer_id, 'R1');
  assert.equal(updateRes.stops[1].stop_sequence, 2);

  // Check inventory baseline BEFORE publish
  const p1BeforePublish = (await (await req('owner', '/products')).find(p => p.id === 'P1'));
  const p2BeforePublish = (await (await req('owner', '/products')).find(p => p.id === 'P2'));

  // Publish Route
  const publishRes = ok(await req('owner', `/planned-routes/${routeId}/publish`, {}));
  assert.equal(publishRes.route.status, 'PUBLISHED');
  assert.ok(publishRes.route.published_at > 0);

  // STRICT BUSINESS RULE: Publishing route must NOT touch inventory or order reservations
  const p1AfterPublish = (await (await req('owner', '/products')).find(p => p.id === 'P1'));
  const p2AfterPublish = (await (await req('owner', '/products')).find(p => p.id === 'P2'));
  assert.equal(p1AfterPublish.stockQuantity, p1BeforePublish.stockQuantity, 'Stock must not change when publishing route');
  assert.equal(p1AfterPublish.reservedQuantity, p1BeforePublish.reservedQuantity, 'Reserved stock must not change when publishing route');
  assert.equal(p2AfterPublish.stockQuantity, p2BeforePublish.stockQuantity, 'Stock must not change when publishing route');
  assert.equal(p2AfterPublish.reservedQuantity, p2BeforePublish.reservedQuantity, 'Reserved stock must not change when publishing route');

  // Once published, cannot edit stops
  const denyEditPublished = await req('owner', `/planned-routes/${routeId}`, {
    name: 'Illegal Edit'
  }, 'PUT');
  assert.equal(denyEditPublished.httpStatus, 400);

  // Salesperson can now see the PUBLISHED route
  const salesListAfterPublish = ok(await req('sales', '/planned-routes'));
  const foundPublished = (salesListAfterPublish.routes || []).find(r => r.id === routeId);
  assert.ok(foundPublished, 'Salesperson must see assigned published route');
  assert.equal(foundPublished.status, 'PUBLISHED');

  // Salesperson gets route details
  const salesRouteDetail = ok(await req('sales', `/planned-routes/${routeId}`));
  assert.equal(salesRouteDetail.route.id, routeId);
  assert.equal(salesRouteDetail.stops.length, 2);

  // Salesperson updates stop 1 to VISITED
  const stop1Id = salesRouteDetail.stops[0].id;
  const visitRes = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop1Id}/status`, {
    status: 'VISITED',
    notes: 'Shop visited, retailer requested callback at 4pm'
  }));
  assert.equal(visitRes.stop.status, 'VISITED');
  assert.ok(visitRes.stop.visited_at > 0);

  // Salesperson updates stop 2 to SKIPPED
  const stop2Id = salesRouteDetail.stops[1].id;
  const skipRes = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop2Id}/status`, {
    status: 'SKIPPED',
    notes: 'Shop closed due to festival'
  }));
  assert.equal(skipRes.stop.status, 'SKIPPED');

  // Cancel Route
  const cancelRes = ok(await req('owner', `/planned-routes/${routeId}/cancel`, {
    reason: 'Heavy rain in sector 17-22'
  }));
  assert.equal(cancelRes.success, true);

  const finalRoute = (await req('owner', `/planned-routes/${routeId}`)).route;
  assert.equal(finalRoute.status, 'CANCELLED');
  assert.equal(finalRoute.cancellation_reason, 'Heavy rain in sector 17-22');
});

test('4. Security & Multi-Tenant Authorization: Salesperson route ID spoofing, cross-tenant isolation, and publication consistency', async () => {
  // A. Tenant isolation: comp_1 owner cannot use comp_2 salesperson or retailer
  const crossSalesRes = await req('owner', '/planned-routes', {
    routeDate: '2026-10-27',
    name: 'Cross Tenant Route',
    salespersonId: 'user_sales_comp2',
    stops: [{ retailerId: 'R1', stopSequence: 1 }]
  });
  assert.equal(crossSalesRes.httpStatus, 404, 'Cannot assign salesperson from another company');

  const crossRetailerRes = await req('owner', '/planned-routes', {
    routeDate: '2026-10-27',
    name: 'Cross Tenant Retailer Route',
    salespersonId: 'user_sales',
    stops: [{ retailerId: 'ret_comp2_1', stopSequence: 1 }]
  });
  assert.equal(crossRetailerRes.httpStatus, 404, 'Cannot include retailer from another company');

  // B. Company 2 owner creates a published route for sales_comp2
  const comp2RouteRes = ok(await req('owner_comp2', '/planned-routes', {
    routeDate: '2026-10-27',
    name: 'Company 2 Route',
    salespersonId: 'user_sales_comp2',
    stops: [{ retailerId: 'ret_comp2_1', stopSequence: 1 }]
  }));
  const comp2RouteId = comp2RouteRes.route.id;
  ok(await req('owner_comp2', `/planned-routes/${comp2RouteId}/publish`, {}));

  // C. Salesperson from Company 1 attempts to read Company 2 route by ID -> 404 (multi-tenant boundary)
  const crossTenantAccess = await req('sales', `/planned-routes/${comp2RouteId}`);
  assert.equal(crossTenantAccess.httpStatus, 404, 'Cross-tenant route read must return 404');

  // D. Create Route in Company 1 assigned to sales_1, publish it
  const routeComp1Res = ok(await req('owner', '/planned-routes', {
    routeDate: '2026-10-28',
    name: 'Owner Route For Sales 1',
    salespersonId: 'user_sales',
    stops: [{ retailerId: 'R1', stopSequence: 1 }]
  }));
  const routeComp1Id = routeComp1Res.route.id;

  // Before publication, sales_1 cannot read draft route by ID -> 403 Forbidden
  const denyDraftAccess = await req('sales', `/planned-routes/${routeComp1Id}`);
  assert.equal(denyDraftAccess.httpStatus, 403, 'Salesperson cannot access unpublished draft route');

  // Publish the route
  ok(await req('owner', `/planned-routes/${routeComp1Id}/publish`, {}));

  // Non-assigned role (e.g. delivery or warehouse) cannot read route by ID -> 403 Forbidden
  const denyWarehouse = await req('warehouse', `/planned-routes/${routeComp1Id}`);
  assert.equal(denyWarehouse.httpStatus, 403, 'Warehouse manager cannot access salesperson planned route');

  const denyDelivery = await req('delivery', `/planned-routes/${routeComp1Id}`);
  assert.equal(denyDelivery.httpStatus, 403, 'Delivery executive cannot access salesperson planned route');

  // Assigned salesperson CAN read their published route
  const salesAllowed = ok(await req('sales', `/planned-routes/${routeComp1Id}`));
  assert.equal(salesAllowed.route.id, routeComp1Id);

  // E. Duplicate publication idempotency: publishing an already-published route returns 200 idempotent: true
  const dupPublishRes = ok(await req('owner', `/planned-routes/${routeComp1Id}/publish`, {}));
  assert.equal(dupPublishRes.idempotent, true);

  // F. Modifying published route returns 400
  const editPublished = await req('owner', `/planned-routes/${routeComp1Id}`, { name: 'Illegal Modification' }, 'PUT');
  assert.equal(editPublished.httpStatus, 400);

  // G. Publication requires >= 1 stop: Create empty draft, try to publish
  const emptyDraft = ok(await req('owner', '/planned-routes', {
    routeDate: '2026-10-28',
    name: 'Empty Route',
    salespersonId: 'user_sales',
    stops: []
  }));
  const publishEmpty = await req('owner', `/planned-routes/${emptyDraft.route.id}/publish`, {});
  assert.equal(publishEmpty.httpStatus, 400);
  assert.match(publishEmpty.error, /zero stops/i);
});

test('5. Stop Status Sync: Offline timestamp preservation, replay idempotency, stale event defense, and ownership guards', async () => {
  // Create and publish a 2-stop route for user_sales
  const rRes = ok(await req('owner', '/planned-routes', {
    routeDate: '2026-10-29',
    name: 'Stop Sync Test Beat',
    salespersonId: 'user_sales',
    stops: [
      { retailerId: 'R1', stopSequence: 1 },
      { retailerId: 'R2', stopSequence: 2 }
    ]
  }));
  const routeId = rRes.route.id;
  ok(await req('owner', `/planned-routes/${routeId}/publish`, {}));

  const stop1Id = rRes.stops[0].id;
  const stop2Id = rRes.stops[1].id;

  // 1. Cross-user attack: Salesperson from Company 2 cannot update Stop 1 -> 404 (multi-tenant boundary)
  const crossCompRes = await req('sales_comp2', `/planned-routes/${routeId}/stops/${stop1Id}/status`, {
    status: 'VISITED'
  });
  assert.equal(crossCompRes.httpStatus, 404, 'Cross-company stop update must return 404');

  // 2. Unauthorized role attack: Delivery cannot update stop -> 403 Forbidden
  const deliveryRes = await req('delivery', `/planned-routes/${routeId}/stops/${stop1Id}/status`, {
    status: 'VISITED'
  });
  assert.equal(deliveryRes.httpStatus, 403, 'Delivery executive cannot update route stop status');

  // 3. Assigned salesperson marks Stop 1 as VISITED with an offline client timestamp (e.g. 2 hours ago)
  const offlineVisitTime = Date.now() - 7200000;
  const visitRes = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop1Id}/status`, {
    status: 'VISITED',
    visitedAt: offlineVisitTime,
    clientTimestamp: offlineVisitTime,
    notes: 'Visited offline earlier'
  }));
  assert.equal(visitRes.stop.status, 'VISITED');
  assert.equal(visitRes.stop.visited_at, offlineVisitTime, 'Backend must preserve original offline visitedAt timestamp');

  // 4. Duplicate delivery / replay: repeating the exact same stop update returns 200 with idempotent: true
  const dupVisitRes = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop1Id}/status`, {
    status: 'VISITED',
    visitedAt: offlineVisitTime,
    clientTimestamp: offlineVisitTime,
    notes: 'Visited offline earlier'
  }));
  assert.equal(dupVisitRes.idempotent, true, 'Replay of identical stop update must be idempotent');
  assert.equal(dupVisitRes.stop.visited_at, offlineVisitTime);

  // 5. Stale event & clock-skew guard:
  // 5a. Stale event with older timestamp attempting to set Stop 1 to SKIPPED is safely ignored
  const staleTime = offlineVisitTime - 10000;
  const staleRes = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop1Id}/status`, {
    status: 'SKIPPED',
    clientTimestamp: staleTime,
    notes: 'Stale offline skip before actual visit'
  }));
  assert.equal(staleRes.ignoredStale, true, 'Stale update must be safely ignored');
  assert.equal(staleRes.stop.status, 'VISITED', 'Stop status must remain VISITED and not regress');

  // 5b. Future clock-skew attack: salesperson sends SKIPPED with a future timestamp (+24 hours) -> rejected/ignored
  const futureClockSkewTime = Date.now() + 86400000;
  const futureSkipRes = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop1Id}/status`, {
    status: 'SKIPPED',
    clientTimestamp: futureClockSkewTime,
    notes: 'Delayed event with skewed future device clock'
  }));
  assert.equal(futureSkipRes.ignoredStale, true, 'Future clock-skewed skip attempt must be safely ignored');
  assert.equal(futureSkipRes.stop.status, 'VISITED', 'Stop status must remain VISITED and not regress');

  // 5c. Salesperson cannot regress VISITED to PENDING
  const pendingRegressRes = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop1Id}/status`, {
    status: 'PENDING',
    notes: 'Attempt to reset visited stop to pending'
  }));
  assert.equal(pendingRegressRes.ignoredStale, true, 'Pending regression attempt must be safely ignored');
  assert.equal(pendingRegressRes.stop.status, 'VISITED', 'Stop status must remain VISITED and not regress');

  // 6. Valid first-time transitions on unvisited Stop 2:
  // 6a. Valid PENDING -> SKIPPED transition succeeds
  const skipStop2Res = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop2Id}/status`, {
    status: 'SKIPPED',
    notes: 'Store closed today'
  }));
  assert.equal(skipStop2Res.stop.status, 'SKIPPED', 'Initial PENDING to SKIPPED must succeed');

  // 6b. Valid SKIPPED -> VISITED transition succeeds (store reopened later in the day)
  const visitStop2Res = ok(await req('sales', `/planned-routes/${routeId}/stops/${stop2Id}/status`, {
    status: 'VISITED',
    notes: 'Store reopened in the afternoon'
  }));
  assert.equal(visitStop2Res.stop.status, 'VISITED', 'Subsequent visit of skipped stop must succeed');

  // 7. Permitted planner correction:
  // An authorized planner (e.g. Owner with 'route:plan') can correct a VISITED stop back to PENDING or SKIPPED
  const plannerCorrectionRes = ok(await req('owner', `/planned-routes/${routeId}/stops/${stop2Id}/status`, {
    status: 'PENDING',
    notes: 'Owner corrected stop status to PENDING for re-assignment'
  }));
  assert.equal(plannerCorrectionRes.stop.status, 'PENDING', 'Authorized planner correction must be permitted');
  assert.equal(plannerCorrectionRes.stop.visited_at, null, 'Visited timestamp must be cleared on transition to PENDING');
});
