import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { sign } from '@tsndr/cloudflare-worker-jwt';

const BASE_URL = 'http://127.0.0.1:8787';

describe('RouteFlow API End-to-End Integration Suite', () => {
  let ownerToken = '';
  let salesToken = '';
  let warehouseToken = '';
  let deliveryToken = '';
  let delivery2Token = '';
  let salesComp2Token = '';
  let ownerComp2Token = '';
  let salesRefreshToken = '';

  test('1. Auth: Valid logins across all active roles and multi-company setup', async () => {
    // Owner comp_1
    const resOwner = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'owner', password: 'password123', device_id: 'dev_owner' })
    });
    assert.equal(resOwner.status, 200, 'Owner login failed');
    const ownerData = await resOwner.json();
    assert.ok(ownerData.access_token);
    assert.equal(ownerData.user.role, 'OWNER');
    ownerToken = ownerData.access_token;

    // Salesperson comp_1
    const resSales = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123', device_id: 'dev_sales' })
    });
    assert.equal(resSales.status, 200, 'Sales login failed');
    const salesData = await resSales.json();
    assert.equal(salesData.user.role, 'SALESPERSON');
    salesToken = salesData.access_token;
    salesRefreshToken = salesData.refresh_token;

    // Warehouse Manager comp_1
    const resWh = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'warehouse', password: 'password123' })
    });
    assert.equal(resWh.status, 200, 'Warehouse login failed');
    warehouseToken = (await resWh.json()).access_token;

    // Delivery Executive 1 comp_1
    const resDel1 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'delivery', password: 'password123' })
    });
    assert.equal(resDel1.status, 200, 'Delivery 1 login failed');
    deliveryToken = (await resDel1.json()).access_token;

    // Delivery Executive 2 comp_1
    const resDel2 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'delivery2', password: 'password123' })
    });
    assert.equal(resDel2.status, 200, 'Delivery 2 login failed');
    delivery2Token = (await resDel2.json()).access_token;

    // Comp 2 Salesperson
    const resSales2 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales_comp2', password: 'password123' })
    });
    assert.equal(resSales2.status, 200, 'Comp 2 Sales login failed');
    salesComp2Token = (await resSales2.json()).access_token;

    // Comp 2 Owner
    const resOwner2 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'owner_comp2', password: 'password123' })
    });
    assert.equal(resOwner2.status, 200, 'Comp 2 Owner login failed');
    ownerComp2Token = (await resOwner2.json()).access_token;
  });

  test('2. Auth Security: Rejections for invalid, disabled users, and tampered tokens', async () => {
    // Invalid credentials
    const resBad = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'owner', password: 'wrongpassword' })
    });
    assert.equal(resBad.status, 401, 'Should reject invalid credentials');

    // Disabled user
    const resDisabled = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'disabled', password: 'password123' })
    });
    assert.equal(resDisabled.status, 403, 'Should reject disabled account');

    // Tampered token
    const resTampered = await fetch(`${BASE_URL}/retailers`, {
      headers: { Authorization: `Bearer ${salesToken}tampered` }
    });
    assert.equal(resTampered.status, 401, 'Should reject tampered token');
  });

  test('3. Session Revocation: Old access token rejected after logout and refresh token reuse', async () => {
    // A. Log in a temporary session
    const tempLogin = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123', device_id: 'temp_device' })
    });
    assert.equal(tempLogin.status, 200);
    const { access_token: tempAccess, refresh_token: tempRefresh } = await tempLogin.json();

    // Verify tempAccess works initially
    const resBeforeLogout = await fetch(`${BASE_URL}/me`, {
      headers: { Authorization: `Bearer ${tempAccess}` }
    });
    assert.equal(resBeforeLogout.status, 200);

    // Call logout to revoke session
    const resLogout = await fetch(`${BASE_URL}/auth/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tempAccess}` }
    });
    assert.equal(resLogout.status, 200);

    // CRITICAL: Verify the OLD ACCESS TOKEN is immediately rejected with 401
    const resOldAccessAfterLogout = await fetch(`${BASE_URL}/me`, {
      headers: { Authorization: `Bearer ${tempAccess}` }
    });
    assert.equal(resOldAccessAfterLogout.status, 401, 'Old access token MUST be rejected after logout');

    // Verify refresh token is also invalid after logout
    const resRefreshAfterLogout = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: tempRefresh })
    });
    assert.equal(resRefreshAfterLogout.status, 401);

    // B. Refresh token reuse detection revoking the session
    const login2 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123', device_id: 'reuse_test_device' })
    });
    const { access_token: acc2, refresh_token: ref2 } = await login2.json();

    // Rotate refresh token
    const resRotate = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: ref2 })
    });
    assert.equal(resRotate.status, 200);
    const { access_token: acc3, refresh_token: ref3 } = await resRotate.json();

    // Attacker attempts reuse of old ref2
    const resReplay = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: ref2 })
    });
    assert.equal(resReplay.status, 401, 'Old refresh token reuse must be rejected');

    // CRITICAL: Both old access token (acc2) and newer access token (acc3) must be rejected because session is revoked!
    const resAcc2 = await fetch(`${BASE_URL}/me`, { headers: { Authorization: `Bearer ${acc2}` } });
    assert.equal(resAcc2.status, 401, 'Access token must be rejected after reuse revocation');
    const resAcc3 = await fetch(`${BASE_URL}/me`, { headers: { Authorization: `Bearer ${acc3}` } });
    assert.equal(resAcc3.status, 401, 'Newer access token must also be rejected after reuse revocation');

    // C. Atomic conditional refresh race test
    const loginRace = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123', device_id: 'race_device' })
    });
    const { refresh_token: raceRef } = await loginRace.json();

    // Fire 2 concurrent refresh calls with same token
    const [resRace1, resRace2] = await Promise.all([
      fetch(`${BASE_URL}/auth/refresh`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refresh_token: raceRef }) }),
      fetch(`${BASE_URL}/auth/refresh`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refresh_token: raceRef }) })
    ]);

    const statuses = [resRace1.status, resRace2.status];
    assert.ok(statuses.includes(200), 'Exactly one concurrent refresh must succeed');
    assert.ok(statuses.includes(401), 'Conflicting concurrent refresh must be rejected with 401');

    // Restore salesToken
    const finalSalesLogin = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123' })
    });
    salesToken = (await finalSalesLogin.json()).access_token;
  });

  test('4. Multi-Tenant Isolation (Two Companies)', async () => {
    // Comp 1 Salesperson fetching retailers: sees Comp 1 retailers only
    const resRet1 = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${salesToken}` } });
    const retailers1 = await resRet1.json();
    assert.ok(retailers1.every(r => r.beatId === 'BEAT-04'));
    assert.ok(!retailers1.some(r => r.id === 'ret_comp2_1'), 'Company 1 must not see Company 2 retailers');

    // Comp 2 Salesperson fetching retailers: sees Comp 2 retailers only
    const resRet2 = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${salesComp2Token}` } });
    const retailers2 = await resRet2.json();
    assert.ok(retailers2.some(r => r.id === 'ret_comp2_1'), 'Company 2 must see its own retailer');
    assert.ok(!retailers2.some(r => r.id === 'ret_1' || r.id === 'R1'), 'Company 2 must not see Company 1 retailers');

    // Cross-tenant order submission: Comp 2 salesperson trying to order for Comp 1 retailer -> 400
    const resCrossSubmit = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesComp2Token}` },
      body: JSON.stringify({
        order: {
          id: `cross_tenant_${Date.now()}`,
          retailerId: 'R1', // from comp_1
          employeeId: 'user_sales_comp2',
          status: 'SUBMITTED',
          totalAmountPaise: 10000,
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: 'item1', productId: 'prod_comp2_1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 10000, isPicked: false }]
      })
    });
    assert.equal(resCrossSubmit.status, 400, 'Cross-tenant retailer order must be rejected');

    // Comp 2 Owner accessing Comp 1 order: 404
    const resCrossOrder = await fetch(`${BASE_URL}/orders/non_existent_or_other_tenant`, {
      headers: { Authorization: `Bearer ${ownerComp2Token}` }
    });
    assert.equal(resCrossOrder.status, 404);
  });

  test('5. Assignment Permissions: Two Delivery Accounts & Salesperson Beat Checks', async () => {
    // A. Salesperson beat assignment check
    // Create an unassigned retailer in comp_1 under BEAT-99
    // Attempting to submit order by user_sales (assigned only to BEAT-04) for BEAT-99 retailer should fail 403
    // Note: ret_comp2_1 is in comp_2, but let's test beat assignment with another beat if available.
    // If user_sales orders for R1 (BEAT-04), it succeeds:
    const validBeatOrder = {
      order: {
        id: `beat_valid_${Date.now()}`,
        retailerId: 'R1',
        employeeId: 'user_sales',
        status: 'SUBMITTED',
        totalAmountPaise: 45000,
        createdAt: Date.now(),
        updatedAt: Date.now()
      },
      items: [{ id: `item_${Date.now()}`, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
    };
    const resValidBeat = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(validBeatOrder)
    });
    assert.equal(resValidBeat.status, 200, 'Assigned beat order must succeed');

    // B. Delivery user assignment scoping
    // Complete cycle up to dispatch, assigned to user_delivery (Driver 1)
    const delOrderId = validBeatOrder.order.id;
    await fetch(`${BASE_URL}/orders/${delOrderId}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } });
    await fetch(`${BASE_URL}/orders/${delOrderId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P1', isPicked: true })
    });
    await fetch(`${BASE_URL}/orders/${delOrderId}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    const resDisp = await fetch(`${BASE_URL}/orders/${delOrderId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });
    assert.equal(resDisp.status, 200);

    // Driver 1 lists orders: MUST include delOrderId
    const resDel1List = await fetch(`${BASE_URL}/orders`, { headers: { Authorization: `Bearer ${deliveryToken}` } });
    const del1Orders = await resDel1List.json();
    assert.ok(del1Orders.some(o => o.id === delOrderId), 'Assigned driver 1 must see assigned order in list');

    // Driver 1 reads order detail: MUST succeed
    const resDel1Detail = await fetch(`${BASE_URL}/orders/${delOrderId}`, { headers: { Authorization: `Bearer ${deliveryToken}` } });
    assert.equal(resDel1Detail.status, 200, 'Assigned driver 1 can view order detail');

    // Driver 2 lists orders: MUST NOT include delOrderId
    const resDel2List = await fetch(`${BASE_URL}/orders`, { headers: { Authorization: `Bearer ${delivery2Token}` } });
    const del2Orders = await resDel2List.json();
    assert.ok(!del2Orders.some(o => o.id === delOrderId), 'Driver 2 must NOT see orders assigned to Driver 1 in list');

    // Driver 2 attempts to read order detail: MUST return 403 Forbidden
    const resDel2Detail = await fetch(`${BASE_URL}/orders/${delOrderId}`, { headers: { Authorization: `Bearer ${delivery2Token}` } });
    assert.equal(resDel2Detail.status, 403, 'Driver 2 must be rejected with 403 when reading Driver 1 order');

    // Driver 2 attempts to deliver Driver 1 order: MUST return 403 Forbidden
    const resDel2Deliver = await fetch(`${BASE_URL}/orders/${delOrderId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${delivery2Token}` },
      body: JSON.stringify({ paymentMethod: 'CASH' })
    });
    assert.equal(resDel2Deliver.status, 403, 'Driver 2 cannot deliver Driver 1 order');

    // Driver 1 completes delivery: MUST succeed
    const resDel1Deliver = await fetch(`${BASE_URL}/orders/${delOrderId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CASH' })
    });
    assert.equal(resDel1Deliver.status, 200, 'Assigned driver 1 can complete delivery');
  });

  test('6. Server Validation, Promotions & Bound Idempotency Keys', async () => {
    // A. Bounded Integer Validation
    // Negative quantity -> 400
    const resNeg = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: `neg_${Date.now()}`, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 45000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: 'item_neg', productId: 'P1', quantity: -5, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
      })
    });
    assert.equal(resNeg.status, 400, 'Negative quantity must be rejected');

    // Excessive total amount (> 1,000,000,000 paise) -> 400
    const resExcessive = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: `exc_${Date.now()}`, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 2000000000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: 'item_exc', productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 2000000000, isPicked: false }]
      })
    });
    assert.equal(resExcessive.status, 400, 'Total > 1B paise must be rejected');

    // B. Promotion Calculation on Server
    // P1 promotion: min_quantity = 2, free_quantity = 1
    // Salesperson sends order for quantity 4 and freeQuantity 0
    const promoOrderId = `promo_ord_${Date.now()}`;
    const resPromo = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: promoOrderId, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 4 * 45000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `item_${promoOrderId}`, productId: 'P1', quantity: 4, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
      })
    });
    assert.equal(resPromo.status, 200);

    // Verify order detail in DB: freeQuantity must be 2 (Math.floor(4/2) * 1)
    const resPromoDetail = await fetch(`${BASE_URL}/orders/${promoOrderId}`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const promoDetail = await resPromoDetail.json();
    assert.equal(promoDetail.items[0].freeQuantity, 2, 'Server must calculate promotional free units (4 units -> 2 free)');

    // C. Bound Idempotency Keys (actor, operation, request_hash)
    const testKey = `bound_idemp_${Date.now()}`;
    const basePayload = {
      order: { id: `idemp_ord_${Date.now()}`, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 45000, createdAt: Date.now(), updatedAt: Date.now() },
      items: [{ id: `item_${Date.now()}`, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }],
      idempotencyKey: testKey
    };

    // First submission
    const resIdemp1 = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(basePayload)
    });
    assert.equal(resIdemp1.status, 200);

    // Replay with identical payload -> Returns 200 with saved result
    const resIdempReplay = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(basePayload)
    });
    assert.equal(resIdempReplay.status, 200);

    // Replay with DIFFERENT payload -> MUST return 409 Conflict
    const conflictingPayload = {
      ...basePayload,
      order: { ...basePayload.order, totalAmountPaise: 90000 },
      items: [{ ...basePayload.items[0], quantity: 2 }]
    };
    const resIdempConflict = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(conflictingPayload)
    });
    assert.equal(resIdempConflict.status, 409, 'Reusing idempotency key with differing payload must return 409 Conflict');
  });

  test('7. Same-Order Concurrency & Ledger Integrity', async () => {
    // A. Concurrent Approvals on the EXACT SAME order
    const concOrdId = `conc_same_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: concOrdId, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 12000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${concOrdId}_item`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }]
      })
    });

    const p2Before = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');

    // Fire 3 concurrent approvals on the SAME order
    const [appr1, appr2, appr3] = await Promise.all([
      fetch(`${BASE_URL}/orders/${concOrdId}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } }),
      fetch(`${BASE_URL}/orders/${concOrdId}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } }),
      fetch(`${BASE_URL}/orders/${concOrdId}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } })
    ]);

    // All should either succeed with 200 (first creates transition, subsequent are idempotent or 409)
    const p2After = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');
    assert.equal(p2After.reservedQuantity, p2Before.reservedQuantity + 1, 'Stock reserved quantity must increase by EXACTLY 1, never duplicated by concurrent requests');

    // B. Pick and Pack
    await fetch(`${BASE_URL}/orders/${concOrdId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P2', isPicked: true })
    });
    await fetch(`${BASE_URL}/orders/${concOrdId}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${concOrdId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });

    // C. Concurrent Delivery & Durable Ledger on the SAME order
    // Test invalid payment method first:
    const resBadMethod = await fetch(`${BASE_URL}/orders/${concOrdId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CRYPTO' })
    });
    assert.equal(resBadMethod.status, 400, 'Invalid payment method must be rejected');

    // Fire 2 concurrent delivery requests on the same order with valid method UPI
    const [deliv1, deliv2] = await Promise.all([
      fetch(`${BASE_URL}/orders/${concOrdId}/deliver`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` }, body: JSON.stringify({ paymentMethod: 'UPI' }) }),
      fetch(`${BASE_URL}/orders/${concOrdId}/deliver`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` }, body: JSON.stringify({ paymentMethod: 'UPI' }) })
    ]);

    assert.ok(deliv1.status === 200 || deliv2.status === 200);

    // Verify order final state
    const orderFinal = (await (await fetch(`${BASE_URL}/orders/${concOrdId}`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).order;
    assert.equal(orderFinal.status, 'DELIVERED');
    assert.equal(orderFinal.paymentMethod, 'UPI');
  });
});
