import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.ROUTEFLOW_TEST_URL || 'http://127.0.0.1:8787';

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

    const resBeforeLogout = await fetch(`${BASE_URL}/me`, {
      headers: { Authorization: `Bearer ${tempAccess}` }
    });
    assert.equal(resBeforeLogout.status, 200);

    // Logout
    const resLogout = await fetch(`${BASE_URL}/auth/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tempAccess}` }
    });
    assert.equal(resLogout.status, 200);

    // Old access token must be rejected after logout
    const resOldAccessAfterLogout = await fetch(`${BASE_URL}/me`, {
      headers: { Authorization: `Bearer ${tempAccess}` }
    });
    assert.equal(resOldAccessAfterLogout.status, 401, 'Old access token MUST be rejected after logout');

    // Refresh token also invalid after logout
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

    const resAcc2 = await fetch(`${BASE_URL}/me`, { headers: { Authorization: `Bearer ${acc2}` } });
    assert.equal(resAcc2.status, 401);
    const resAcc3 = await fetch(`${BASE_URL}/me`, { headers: { Authorization: `Bearer ${acc3}` } });
    assert.equal(resAcc3.status, 401);

    // C. Atomic conditional refresh race test
    const loginRace = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123', device_id: 'race_device' })
    });
    const { refresh_token: raceRef } = await loginRace.json();

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
    // Comp 1 Salesperson sees Comp 1 retailers only
    const resRet1 = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${salesToken}` } });
    const retailers1 = await resRet1.json();
    assert.ok(retailers1.every(r => r.beatId === 'BEAT-04'));
    assert.ok(!retailers1.some(r => r.id === 'ret_comp2_1'), 'Company 1 must not see Company 2 retailers');

    // Comp 2 Salesperson sees Comp 2 retailers only
    const resRet2 = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${salesComp2Token}` } });
    const retailers2 = await resRet2.json();
    assert.ok(retailers2.some(r => r.id === 'ret_comp2_1'), 'Company 2 must see its own retailer');
    assert.ok(!retailers2.some(r => r.id === 'ret_1' || r.id === 'R1'), 'Company 2 must not see Company 1 retailers');

    // Cross-tenant order submission rejected
    const resCrossSubmit = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesComp2Token}` },
      body: JSON.stringify({
        order: {
          id: `cross_tenant_${Date.now()}`,
          retailerId: 'R1',
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

    // Comp 2 Owner accessing other tenant order
    const resCrossOrder = await fetch(`${BASE_URL}/orders/non_existent_or_other_tenant`, {
      headers: { Authorization: `Bearer ${ownerComp2Token}` }
    });
    assert.equal(resCrossOrder.status, 404);
  });

  test('5. Assignment Permissions: Two Delivery Accounts & Salesperson Beat Checks', async () => {
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

    // Driver 1 lists orders: includes delOrderId
    const resDel1List = await fetch(`${BASE_URL}/orders`, { headers: { Authorization: `Bearer ${deliveryToken}` } });
    const del1Orders = await resDel1List.json();
    assert.ok(del1Orders.some(o => o.id === delOrderId));

    // Driver 1 reads order detail: succeeds
    const resDel1Detail = await fetch(`${BASE_URL}/orders/${delOrderId}`, { headers: { Authorization: `Bearer ${deliveryToken}` } });
    assert.equal(resDel1Detail.status, 200);

    // Driver 2 lists orders: does NOT include delOrderId
    const resDel2List = await fetch(`${BASE_URL}/orders`, { headers: { Authorization: `Bearer ${delivery2Token}` } });
    const del2Orders = await resDel2List.json();
    assert.ok(!del2Orders.some(o => o.id === delOrderId), 'Driver 2 must NOT see Driver 1 assigned orders');

    // Driver 2 attempts to read order detail: 403 Forbidden
    const resDel2Detail = await fetch(`${BASE_URL}/orders/${delOrderId}`, { headers: { Authorization: `Bearer ${delivery2Token}` } });
    assert.equal(resDel2Detail.status, 403, 'Driver 2 reading Driver 1 order must be 403');

    // Driver 2 attempts to deliver Driver 1 order: 403 Forbidden
    const resDel2Deliver = await fetch(`${BASE_URL}/orders/${delOrderId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${delivery2Token}` },
      body: JSON.stringify({ paymentMethod: 'CASH' })
    });
    assert.equal(resDel2Deliver.status, 403, 'Driver 2 delivering Driver 1 order must be 403');

    // Driver 1 delivers order: succeeds with test bypass header
    const resDel1Deliver = await fetch(`${BASE_URL}/orders/${delOrderId}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({ paymentMethod: 'CASH' })
    });
    assert.equal(resDel1Deliver.status, 200);
  });

  test('6. Restored Promotion (BUY 10 GET 1 FREE) & Bound Idempotency Keys', async () => {
    // A. Bounded Integer Validation
    const resNeg = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: `neg_${Date.now()}`, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 45000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: 'item_neg', productId: 'P1', quantity: -5, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
      })
    });
    assert.equal(resNeg.status, 400, 'Negative quantity must be rejected');

    // B. Restored Promotion: Premium Tea (P1) is BUY 10 GET 1 FREE
    // Order 1: 10 units -> 1 free unit
    const promoOrd1 = `promo_tea_10_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: promoOrd1, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 10 * 45000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `item_${promoOrd1}`, productId: 'P1', quantity: 10, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
      })
    });
    const d1 = await (await fetch(`${BASE_URL}/orders/${promoOrd1}`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json();
    assert.equal(d1.items[0].freeQuantity, 1, 'Ordering 10 Premium Tea must grant 1 free unit');

    // Order 2: 20 units -> 2 free units
    const promoOrd2 = `promo_tea_20_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: promoOrd2, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 20 * 45000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `item_${promoOrd2}`, productId: 'P1', quantity: 20, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
      })
    });
    const d2 = await (await fetch(`${BASE_URL}/orders/${promoOrd2}`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json();
    assert.equal(d2.items[0].freeQuantity, 2, 'Ordering 20 Premium Tea must grant 2 free units');

    // Order 3: 9 units -> 0 free units
    const promoOrd3 = `promo_tea_9_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: promoOrd3, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 9 * 45000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `item_${promoOrd3}`, productId: 'P1', quantity: 9, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
      })
    });
    const d3 = await (await fetch(`${BASE_URL}/orders/${promoOrd3}`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json();
    assert.equal(d3.items[0].freeQuantity, 0, 'Ordering 9 Premium Tea must grant 0 free units');

    // C. Bound Idempotency Keys (actor, operation, request_hash)
    const testKey = `bound_idemp_${Date.now()}`;
    const basePayload = {
      order: { id: `idemp_ord_${Date.now()}`, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 45000, createdAt: Date.now(), updatedAt: Date.now() },
      items: [{ id: `item_${Date.now()}`, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }],
      idempotencyKey: testKey
    };

    const resIdemp1 = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(basePayload)
    });
    assert.equal(resIdemp1.status, 200);

    // Replay with identical payload -> Returns 200
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

  test('7. Atomic Transitions with Failure Injection and Rollback Verification', async () => {
    // A. Failure-injection on Approval: stock reservation failure leaves order SUBMITTED and retryable
    const failApprOrdId = `fail_appr_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: failApprOrdId, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 12000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${failApprOrdId}_item`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }]
      })
    });

    const p2Before = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');

    // Injected inventory write failure on approval
    const resInjectedApprove = await fetch(`${BASE_URL}/orders/${failApprOrdId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}`, 'X-Test-Fail-Inventory': 'true' }
    });
    assert.equal(resInjectedApprove.status, 400, 'Injected inventory failure must cause approval to fail');

    // CRITICAL: Order status MUST still be SUBMITTED, and stock MUST NOT be reserved
    const orderAfterFail = (await (await fetch(`${BASE_URL}/orders/${failApprOrdId}`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).order;
    assert.equal(orderAfterFail.status, 'SUBMITTED', 'Order status must remain SUBMITTED when inventory reservation fails');

    const p2AfterFail = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');
    assert.equal(p2AfterFail.reservedQuantity, p2Before.reservedQuantity, 'Reserved quantity must NOT change when approval fails');

    // Safe Retry: Approval without failure header MUST succeed
    const resRetryApprove = await fetch(`${BASE_URL}/orders/${failApprOrdId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resRetryApprove.status, 200, 'Approval retry must succeed');

    const p2AfterRetry = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');
    assert.equal(p2AfterRetry.reservedQuantity, p2Before.reservedQuantity + 1, 'Stock must now be reserved exactly once');

    // Advance to OUT_FOR_DELIVERY
    await fetch(`${BASE_URL}/orders/${failApprOrdId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P2', isPicked: true })
    });
    await fetch(`${BASE_URL}/orders/${failApprOrdId}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${failApprOrdId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });

    // B. Failure-injection on Delivery: invoice write failure leaves order OUT_FOR_DELIVERY and balance unchanged
    const r1Before = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R1');

    // Injected invoice failure on delivery
    const resInjectedDeliver = await fetch(`${BASE_URL}/orders/${failApprOrdId}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Fail-Invoice': 'true',
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({ paymentMethod: 'CREDIT' })
    });
    assert.equal(resInjectedDeliver.status, 400, 'Injected invoice write failure must cause delivery to fail');

    // CRITICAL: Order status MUST still be OUT_FOR_DELIVERY, retailer balance unchanged
    const orderAfterDeliverFail = (await (await fetch(`${BASE_URL}/orders/${failApprOrdId}`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).order;
    assert.equal(orderAfterDeliverFail.status, 'OUT_FOR_DELIVERY', 'Order status must remain OUT_FOR_DELIVERY when invoice write fails');

    const r1AfterDeliverFail = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R1');
    assert.equal(r1AfterDeliverFail.outstandingAmountPaise, r1Before.outstandingAmountPaise, 'Retailer balance must NOT change on delivery failure');

    // Safe Retry: Delivery without failure header MUST succeed
    const resRetryDeliver = await fetch(`${BASE_URL}/orders/${failApprOrdId}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({ paymentMethod: 'CREDIT' })
    });
    assert.equal(resRetryDeliver.status, 200, 'Delivery retry must succeed');

    const r1Final = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R1');
    assert.equal(r1Final.outstandingAmountPaise, r1Before.outstandingAmountPaise + 12000, 'Retailer balance must now be incremented exactly once');
  });

  test('8. Concurrent Retailer Balance Updates (Two Different Orders to Same Retailer)', async () => {
    // Order A for Retailer R2 (Total: 12,000 paise)
    const ordA = `diff_ord_A_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: ordA, retailerId: 'R2', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 12000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${ordA}_item`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }]
      })
    });
    await fetch(`${BASE_URL}/orders/${ordA}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } });
    await fetch(`${BASE_URL}/orders/${ordA}/pick-item`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` }, body: JSON.stringify({ productId: 'P2', isPicked: true }) });
    await fetch(`${BASE_URL}/orders/${ordA}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${ordA}/dispatch`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` }, body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' }) });

    // Order B for Retailer R2 (Total: 24,000 paise)
    const ordB = `diff_ord_B_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: ordB, retailerId: 'R2', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 24000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${ordB}_item`, productId: 'P2', quantity: 2, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }]
      })
    });
    await fetch(`${BASE_URL}/orders/${ordB}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } });
    await fetch(`${BASE_URL}/orders/${ordB}/pick-item`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` }, body: JSON.stringify({ productId: 'P2', isPicked: true }) });
    await fetch(`${BASE_URL}/orders/${ordB}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${ordB}/dispatch`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` }, body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' }) });

    // Baseline balance of Retailer R2
    const r2Before = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R2');

    // Concurrently deliver BOTH orders to Retailer R2 with CREDIT payment method
    const [delResA, delResB] = await Promise.all([
      fetch(`${BASE_URL}/orders/${ordA}/deliver`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${deliveryToken}`,
          'X-Test-Bypass-Delivery-Otp': 'true'
        },
        body: JSON.stringify({ paymentMethod: 'CREDIT' })
      }),
      fetch(`${BASE_URL}/orders/${ordB}/deliver`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${deliveryToken}`,
          'X-Test-Bypass-Delivery-Otp': 'true'
        },
        body: JSON.stringify({ paymentMethod: 'CREDIT' })
      })
    ]);

    assert.equal(delResA.status, 200, 'Delivery A must succeed');
    assert.equal(delResB.status, 200, 'Delivery B must succeed');

    // CRITICAL: Retailer R2 outstanding balance must include BOTH order amounts (no lost update!)
    const r2After = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R2');
    const expectedBalance = r2Before.outstandingAmountPaise + 12000 + 24000;
    assert.equal(
      r2After.outstandingAmountPaise,
      expectedBalance,
      `Concurrent delivery must accurately increment balance by both amounts (${expectedBalance}), got: ${r2After.outstandingAmountPaise}`
    );
  });

  test('9. Payment Settlement Accuracy (Restricted to CASH and CREDIT in Stage 2)', async () => {
    const settleOrd = `settle_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: settleOrd, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 12000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${settleOrd}_item`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }]
      })
    });
    await fetch(`${BASE_URL}/orders/${settleOrd}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } });
    await fetch(`${BASE_URL}/orders/${settleOrd}/pick-item`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` }, body: JSON.stringify({ productId: 'P2', isPicked: true }) });
    await fetch(`${BASE_URL}/orders/${settleOrd}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${settleOrd}/dispatch`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` }, body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' }) });

    // Reject unverified/unsettled payment methods (UPI, CHEQUE, BITCOIN)
    const resUpi = await fetch(`${BASE_URL}/orders/${settleOrd}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({ paymentMethod: 'UPI' })
    });
    assert.equal(resUpi.status, 400, 'UPI must be rejected as unverified payment method in this milestone');

    const resCheque = await fetch(`${BASE_URL}/orders/${settleOrd}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({ paymentMethod: 'CHEQUE' })
    });
    assert.equal(resCheque.status, 400, 'CHEQUE must be rejected as unverified payment method in this milestone');

    // Deliver with CASH (immediate settlement) -> succeeds, balance unchanged
    const r1BeforeCash = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R1');
    const resCash = await fetch(`${BASE_URL}/orders/${settleOrd}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({ paymentMethod: 'CASH' })
    });
    assert.equal(resCash.status, 200, 'CASH delivery must succeed');

    const r1AfterCash = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R1');
    assert.equal(r1AfterCash.outstandingAmountPaise, r1BeforeCash.outstandingAmountPaise, 'CASH payment must NOT increase outstanding balance');
  });

  test('10. Same-Order Concurrency: Duplicate Requests & Approval vs Rejection Race', async () => {
    // Part A: Duplicate Concurrent Approval on the SAME order
    const dupApprOrd = `dup_appr_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: dupApprOrd, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 12000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${dupApprOrd}_item`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }]
      })
    });

    const p2Initial = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');

    // Fire two concurrent approval requests on the SAME order
    const [resAppr1, resAppr2] = await Promise.all([
      fetch(`${BASE_URL}/orders/${dupApprOrd}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } }),
      fetch(`${BASE_URL}/orders/${dupApprOrd}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } })
    ]);

    // Both should return 200 (one is winning transition, other is idempotent)
    assert.equal(resAppr1.status, 200);
    assert.equal(resAppr2.status, 200);

    // Stock reserved quantity MUST increase by exactly 1 (not 2!)
    const p2AfterDup = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');
    assert.equal(p2AfterDup.reservedQuantity, p2Initial.reservedQuantity + 1, 'Concurrent duplicate approvals must NOT reserve stock twice');

    // Part B: Approval vs Rejection Race on the SAME submitted order
    const raceOrd = `race_ord_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: raceOrd, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 12000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${raceOrd}_item`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }]
      })
    });

    const p2BeforeRace = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');

    // Race approve and reject simultaneously
    const [resRaceAppr, resRaceRej] = await Promise.all([
      fetch(`${BASE_URL}/orders/${raceOrd}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } }),
      fetch(`${BASE_URL}/orders/${raceOrd}/reject`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
        body: JSON.stringify({ reason: 'Raced rejection' })
      })
    ]);

    // Check final order status
    const raceOrderFinal = (await (await fetch(`${BASE_URL}/orders/${raceOrd}`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).order;
    assert.ok(raceOrderFinal.status === 'APPROVED' || raceOrderFinal.status === 'REJECTED', `Status must be APPROVED or REJECTED, was ${raceOrderFinal.status}`);

    const p2AfterRace = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P2');
    if (raceOrderFinal.status === 'APPROVED') {
      assert.equal(p2AfterRace.reservedQuantity, p2BeforeRace.reservedQuantity + 1, 'Stock reserved when approval wins race');
    } else {
      assert.equal(p2AfterRace.reservedQuantity, p2BeforeRace.reservedQuantity, 'Stock NOT reserved when rejection wins race');
    }
  });

  test('11. Delivery Executive Listing & Start Picking Transition', async () => {
    // 1. Warehouse user fetches delivery executives
    const resDev = await fetch(`${BASE_URL}/delivery-executives`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resDev.status, 200);
    const executives = await resDev.json();
    assert.ok(Array.isArray(executives));
    assert.ok(executives.length >= 2, 'Should return at least 2 delivery executives in comp_1');
    const userDelivery = executives.find(e => e.id === 'user_delivery');
    assert.ok(userDelivery, 'user_delivery must be present');
    assert.equal(userDelivery.fullName, 'Suresh Yadav');

    // Cross-company delivery user should NOT be in comp_1 list
    const crossCompanyUser = executives.find(e => e.id === 'user_delivery_comp2');
    assert.equal(crossCompanyUser, undefined, 'Cross-company delivery user must not appear');

    // 2. Start picking transition
    const pickOrd = `pick_start_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: pickOrd, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 12000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${pickOrd}_item`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }]
      })
    });

    // Attempt start-picking BEFORE approval -> should fail 400
    const resPremature = await fetch(`${BASE_URL}/orders/${pickOrd}/start-picking`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resPremature.status, 400);

    // Approve the order
    await fetch(`${BASE_URL}/orders/${pickOrd}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });

    // Start picking -> should succeed
    const resStart = await fetch(`${BASE_URL}/orders/${pickOrd}/start-picking`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resStart.status, 200);
    const startBody = await resStart.json();
    assert.equal(startBody.success, true);
    assert.equal(startBody.status, 'PICKING');

    // Idempotent second call -> should also return 200 with idempotent flag
    const resStartAgain = await fetch(`${BASE_URL}/orders/${pickOrd}/start-picking`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resStartAgain.status, 200);
    const startAgainBody = await resStartAgain.json();
    assert.equal(startAgainBody.idempotent, true);
  });

  test('12. Server-Validated Delivery OTP & Recipient Proof Workflow', async () => {
    const otpOrd = `otp_ord_${Date.now()}`;
    // 1. Submit and approve an order
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: { id: otpOrd, retailerId: 'R1', employeeId: 'user_sales', status: 'SUBMITTED', totalAmountPaise: 45000, createdAt: Date.now(), updatedAt: Date.now() },
        items: [{ id: `${otpOrd}_i1`, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
      })
    });

    await fetch(`${BASE_URL}/orders/${otpOrd}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });

    // Start picking and pack
    await fetch(`${BASE_URL}/orders/${otpOrd}/start-picking`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });

    await fetch(`${BASE_URL}/orders/${otpOrd}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P1', isPicked: true })
    });

    await fetch(`${BASE_URL}/orders/${otpOrd}/pack`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });

    // Dispatch order to Suresh Yadav (user_delivery) -> auto-generates 6-digit OTP
    const resDispatch = await fetch(`${BASE_URL}/orders/${otpOrd}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });
    assert.equal(resDispatch.status, 200);

    // 1. Normal driver request-otp call: driver receives confirmation message but NEVER debugOtp
    const resDriverReq = await fetch(`${BASE_URL}/orders/${otpOrd}/request-otp`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${deliveryToken}` }
    });
    assert.equal(resDriverReq.status, 200);
    const driverData = await resDriverReq.json();
    assert.equal(driverData.debugOtp, undefined, 'Driver must never receive OTP in API response');
    assert.ok(driverData.message.includes('Delivery OTP sent via SMS'), 'Message must indicate SMS notification');

    // 2. Automated test runner request-otp call: receives debugOtp for verification
    const resTestReq = await fetch(`${BASE_URL}/orders/${otpOrd}/request-otp`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${deliveryToken}`, 'X-Test-Runner': 'true' }
    });
    assert.equal(resTestReq.status, 200);
    const otpData = await resTestReq.json();
    assert.ok(otpData.debugOtp, 'Test runner must provide 6-digit OTP');
    const validOtp = otpData.debugOtp;
    assert.equal(validOtp.length, 6);

    // Rejection 0: Delivery attempt omitting recipient name and OTP (prevents bypass)
    const resNoOtpNoRecipient = await fetch(`${BASE_URL}/orders/${otpOrd}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CASH' })
    });
    assert.equal(resNoOtpNoRecipient.status, 400, 'Delivery omitting recipient name and OTP must be strictly rejected');
    assert.equal((await resNoOtpNoRecipient.json()).error, 'Recipient name is required to confirm delivery');

    // Rejection 1: Delivery attempt missing recipient name
    const resNoRecipient = await fetch(`${BASE_URL}/orders/${otpOrd}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CASH', otp: validOtp, recipientName: '' })
    });
    assert.equal(resNoRecipient.status, 400, 'Empty recipient name must be rejected');

    // Rejection 2: Incorrect OTP (attempt 1) -> 400 with remaining attempts
    const resWrongOtp = await fetch(`${BASE_URL}/orders/${otpOrd}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CASH', otp: '000000', recipientName: 'Sharma Ji' })
    });
    assert.equal(resWrongOtp.status, 400);
    const wrongBody = await resWrongOtp.json();
    assert.ok(wrongBody.error.includes('attempt(s) remaining'));

    // Rejection 3: Malformed OTP (e.g. 4 digits or non-digits)
    const resShortOtp = await fetch(`${BASE_URL}/orders/${otpOrd}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CASH', otp: '4829', recipientName: 'Sharma Ji' })
    });
    assert.equal(resShortOtp.status, 400, '4-digit OTP must be rejected as invalid format');

    // Successful Delivery with valid server OTP and recipient name
    const resSuccessDeliver = await fetch(`${BASE_URL}/orders/${otpOrd}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({
        paymentMethod: 'CASH',
        otp: validOtp,
        recipientName: 'Ramesh Sharma (Owner)',
        proofPhotoUrl: 'https://r2.routeflow.internal/proofs/ord1.jpg',
        signatureUrl: 'https://r2.routeflow.internal/signatures/ord1.png'
      })
    });
    assert.equal(resSuccessDeliver.status, 200, 'Delivery with valid OTP and recipient must succeed');

    // Verification: Order details reflect delivered status and recipient name
    const resOrder = await fetch(`${BASE_URL}/orders/${otpOrd}`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const orderData = await resOrder.json();
    assert.equal(orderData.order.status, 'DELIVERED');
    assert.equal(orderData.order.paymentMethod, 'CASH');

    // Duplicate delivery attempt -> idempotent 200
    const resDupDeliver = await fetch(`${BASE_URL}/orders/${otpOrd}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CASH', otp: validOtp, recipientName: 'Ramesh Sharma (Owner)' })
    });
    assert.equal(resDupDeliver.status, 200);
    assert.equal((await resDupDeliver.json()).idempotent, true);
  });

  test('13. Owner Master Data: Product CRUD, Price Preservation, and Audited Stock Adjustments', async () => {
    // 1. Salesperson/Warehouse cannot create product (403)
    const resSalesCreate = await fetch(`${BASE_URL}/products`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ name: 'Unauthorized Biscuit', pricePaise: 5000, unit: 'Pack' })
    });
    assert.equal(resSalesCreate.status, 403);

    // 2. Owner creates new product
    const newProdId = `prod_test_${Date.now()}`;
    const resOwnerCreate = await fetch(`${BASE_URL}/products`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        id: newProdId,
        name: 'Jaipur Special Masala Tea',
        category: 'Beverages',
        pricePaise: 35000,
        mrpPaise: 40000,
        stockQuantity: 50,
        unit: '500g Jar',
        sku: 'JAI-TEA-500'
      })
    });
    assert.equal(resOwnerCreate.status, 200);

    // 3. Audited Stock Adjustment (Stock Receipt: +25 units)
    const resStockReceipt = await fetch(`${BASE_URL}/inventory/adjust`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({
        productId: newProdId,
        changeQuantity: 25,
        reason: 'STOCK_RECEIPT',
        notes: 'Inbound shipment PO-8821'
      })
    });
    assert.equal(resStockReceipt.status, 200);
    const receiptData = await resStockReceipt.json();
    assert.equal(receiptData.newStockQuantity, 75);

    // Negative stock adjustment rejected
    const resExcessDeduct = await fetch(`${BASE_URL}/inventory/adjust`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({
        productId: newProdId,
        changeQuantity: -100,
        reason: 'DAMAGE'
      })
    });
    // 4. Concurrent Stock Adjustments (5 simultaneous requests, zero lost updates)
    const adjustments = [10, 5, -15, 20, -5]; // Net sum = +15
    const concurrentAdjPromises = adjustments.map((qty, idx) =>
      fetch(`${BASE_URL}/inventory/adjust`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
        body: JSON.stringify({
          productId: newProdId,
          changeQuantity: qty,
          reason: 'AUDIT_CORRECTION',
          notes: `Concurrent test adj #${idx + 1}`
        })
      })
    );
    const adjResponses = await Promise.all(concurrentAdjPromises);
    for (const res of adjResponses) {
      assert.equal(res.status, 200, 'Each concurrent adjustment must succeed');
    }

    // Verify final stock quantity: starting was 75, net change +15 -> must be exactly 90
    const resProdAfterAdj = await fetch(`${BASE_URL}/products`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const prodsList = await resProdAfterAdj.json();
    const finalProd = prodsList.find(p => p.id === newProdId);
    assert.equal(finalProd.stockQuantity, 90, `Concurrent adjustments must not lose updates. Expected 90, got ${finalProd.stockQuantity}`);

    // 5. Owner updates product price (to 38,000 paise)
    const resUpdatePrice = await fetch(`${BASE_URL}/products/${newProdId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ pricePaise: 38000 })
    });
    assert.equal(resUpdatePrice.status, 200);
  });

  test('14. Owner Master Data: Retailer Creation/Editing, Employee Onboarding & Instant Session Revocation', async () => {
    // 1. Owner creates new retailer
    const newRetId = `ret_test_${Date.now()}`;
    const resCreateRet = await fetch(`${BASE_URL}/retailers`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        id: newRetId,
        name: 'Kripa Super Store',
        beatId: 'BEAT-04',
        address: 'Plot 12, Tonk Road, Jaipur',
        contactNumber: '9829988776',
        creditLimitPaise: 1500000,
        paymentTermsDays: 14
      })
    });
    assert.equal(resCreateRet.status, 200);

    // 2. Owner updates retailer credit limit
    const resUpdateRet = await fetch(`${BASE_URL}/retailers/${newRetId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ creditLimitPaise: 2000000 })
    });
    assert.equal(resUpdateRet.status, 200);

    // 3. Owner onboards a new salesperson
    const newEmpUser = `sales_new_${Date.now()}`;
    const resCreateEmp = await fetch(`${BASE_URL}/employees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        username: newEmpUser,
        password: 'Password@123',
        fullName: 'Vikram Choudhary',
        role: 'SALESPERSON',
        beatId: 'BEAT-04'
      })
    });
    assert.equal(resCreateEmp.status, 200);
    const empData = await resCreateEmp.json();
    const newEmpId = empData.employee.id;

    // Login with the newly created employee
    const resNewLogin = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: newEmpUser, password: 'Password@123' })
    });
    assert.equal(resNewLogin.status, 200);
    const newEmpToken = (await resNewLogin.json()).access_token;

    // New employee can view retailers in assigned beat
    const resRetCheck = await fetch(`${BASE_URL}/retailers`, {
      headers: { Authorization: `Bearer ${newEmpToken}` }
    });
    assert.equal(resRetCheck.status, 200);

    // 4. Owner deactivates employee -> session must be instantly revoked
    const resDeact = await fetch(`${BASE_URL}/employees/${newEmpId}/deactivate`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resDeact.status, 200);

    // Deactivated user's active access token must now return 401 Unauthorized
    const resPostDeact = await fetch(`${BASE_URL}/retailers`, {
      headers: { Authorization: `Bearer ${newEmpToken}` }
    });
    assert.equal(resPostDeact.status, 401, 'Revoked employee session must return 401');
  });

  test('15. Field Operations: Shop Visit Synchronization and In-Store Stock Audit', async () => {
    // 1. Salesperson records completed shop visit
    const visitId = `vis_${Date.now()}`;
    const now = Date.now();
    const resVisit = await fetch(`${BASE_URL}/visits`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        id: visitId,
        retailerId: 'R1',
        checkInTime: now - 900000, // 15 mins ago
        checkOutTime: now,
        latitude: 26.8521,
        longitude: 75.7645,
        accuracy: 8.5,
        durationSeconds: 900,
        status: 'COMPLETED',
        notes: 'Owner verified stock, placed weekly order',
        idempotencyKey: `idemp_${visitId}`
      })
    });
    assert.equal(resVisit.status, 200);
    const visitBody = await resVisit.json();
    assert.equal(visitBody.success, true);

    // Idempotent duplicate submission
    const resDupVisit = await fetch(`${BASE_URL}/visits`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        id: visitId,
        retailerId: 'R1',
        checkInTime: now - 900000,
        checkOutTime: now,
        latitude: 26.8521,
        longitude: 75.7645,
        accuracy: 8.5,
        durationSeconds: 900,
        status: 'COMPLETED',
        notes: 'Owner verified stock, placed weekly order',
        idempotencyKey: `idemp_${visitId}`
      })
    });
    assert.equal(resDupVisit.status, 200);
    assert.equal((await resDupVisit.json()).idempotent, true);

    // 2. Salesperson lists visits
    const resGetVisits = await fetch(`${BASE_URL}/visits`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    assert.equal(resGetVisits.status, 200);
    const visits = await resGetVisits.json();
    assert.ok(visits.some(v => v.id === visitId));

    // 3. Salesperson records in-store stock check for retailer R1
    const resStockCheck = await fetch(`${BASE_URL}/stock-checks`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        retailerId: 'R1',
        productId: 'P1',
        quantity: 8 // Retailer has 8 units remaining on shelf
      })
    });
    assert.equal(resStockCheck.status, 200);
    const scBody = await resStockCheck.json();
    assert.ok(scBody.stockCheckId);

    // Read back in-store stock check
    const resGetSc = await fetch(`${BASE_URL}/stock-checks/R1`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    assert.equal(resGetSc.status, 200);
    const scList = await resGetSc.json();
    assert.ok(scList.length > 0);
    assert.equal(scList[0].productId, 'P1');
    assert.equal(scList[0].quantity, 8);

    // 4. Tenant Isolation & Beat Assignment Rejections for Visits & Stock Checks
    // A. Cross-company retailer visit rejected (400)
    const resCrossVisit = await fetch(`${BASE_URL}/visits`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        id: `vis_cross_${Date.now()}`,
        retailerId: 'ret_comp2_1',
        checkInTime: Date.now()
      })
    });
    assert.equal(resCrossVisit.status, 400, 'Visit to cross-company retailer must be rejected');

    // B. Cross-company retailer stock check rejected (400)
    const resCrossSc = await fetch(`${BASE_URL}/stock-checks`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        retailerId: 'ret_comp2_1',
        productId: 'P1',
        quantity: 5
      })
    });
    assert.equal(resCrossSc.status, 400, 'Stock check for cross-company retailer must be rejected');

    // C. Cross-company product stock check rejected (400)
    const resCrossProdSc = await fetch(`${BASE_URL}/stock-checks`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        retailerId: 'R1',
        productId: 'prod_comp2_1',
        quantity: 5
      })
    });
    assert.equal(resCrossProdSc.status, 400, 'Stock check with cross-company product must be rejected');

    // D. Cross-company GET /stock-checks rejected (404)
    const resCrossGetSc = await fetch(`${BASE_URL}/stock-checks/ret_comp2_1`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    assert.equal(resCrossGetSc.status, 404, 'Getting stock checks for cross-company retailer must return 404');
  });

  test('16. Collections & Payment Ledger: Partial collection, durable ledger and idempotency', async () => {
    // Check initial retailer outstanding balance
    const resRetBefore = await fetch(`${BASE_URL}/retailers`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const retListBefore = await resRetBefore.json();
    const r1Before = retListBefore.find(r => r.id === 'R1');
    const initialBal = r1Before.outstandingAmountPaise;

    const collectionAmount = 50000; // ₹500
    const testIdempotencyKey = `col_test_${Date.now()}`;

    // 1. Salesperson records a partial CASH collection for R1
    const resCol = await fetch(`${BASE_URL}/collections`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        retailerId: 'R1',
        amountPaise: collectionAmount,
        paymentMethod: 'CASH',
        receiptId: 'REC-TEST-001',
        notes: 'Partial collection by salesperson',
        idempotencyKey: testIdempotencyKey
      })
    });
    assert.equal(resCol.status, 200, 'Recording collection should succeed');
    const colData = await resCol.json();
    assert.ok(colData.success);
    assert.equal(colData.balanceAfterPaise, initialBal - collectionAmount);
    assert.equal(colData.receiptId, 'REC-TEST-001');

    // 2. Retry with same idempotency key must not double-decrement
    const resColRetry = await fetch(`${BASE_URL}/collections`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        retailerId: 'R1',
        amountPaise: collectionAmount,
        paymentMethod: 'CASH',
        receiptId: 'REC-TEST-001',
        notes: 'Partial collection by salesperson',
        idempotencyKey: testIdempotencyKey
      })
    });
    assert.equal(resColRetry.status, 200);
    const retryData = await resColRetry.json();
    assert.ok(retryData.idempotent);
    assert.equal(retryData.balanceAfterPaise, initialBal - collectionAmount);

    // 3. Verify collections list
    const resList = await fetch(`${BASE_URL}/collections?retailerId=R1`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    assert.equal(resList.status, 200);
    const listData = await resList.json();
    const found = listData.collections.find(c => c.id === colData.collectionId);
    assert.ok(found, 'Recorded collection must appear in collections list');
    assert.equal(found.amount_paise, collectionAmount);
  });

  test('17. Cash Handover: Request, calculation from ledger, owner acknowledgement and reconciliation', async () => {
    // 0. Ensure clean state: reject any leftover pending handover for clean test run
    const resClean = await fetch(`${BASE_URL}/owner/handovers`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    if (resClean.ok) {
      const cleanList = await resClean.json();
      for (const h of cleanList.handovers || []) {
        if (h.status === 'PENDING') {
          await fetch(`${BASE_URL}/owner/handovers/${h.id}/acknowledge`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
            body: JSON.stringify({ idempotencyKey: crypto.randomUUID(), action: 'REJECT', notes: 'Cleanup prior test runs' })
          });
        }
      }
    }

    // 1. Salesperson checks cash summary
    const resSummBefore = await fetch(`${BASE_URL}/handovers/summary`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    assert.equal(resSummBefore.status, 200);
    const summBefore = await resSummBefore.json();
    assert.ok(summBefore.cashHeldPaise >= 50000, 'Cash held must reflect at least the ₹500 collected');

    // 2. Attempt handover exceeding cash held should fail
    const resOver = await fetch(`${BASE_URL}/handovers/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        amountPaise: summBefore.cashHeldPaise + 100000,
        notes: 'Excessive handover'
      })
    });
    assert.equal(resOver.status, 400, 'Handover exceeding cash held must be rejected');

    // 3. Submit valid handover request for ₹300 (30000 paise)
    const handoverAmt = 30000;
    const resReq = await fetch(`${BASE_URL}/handovers/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        amountPaise: handoverAmt,
        notes: 'Evening cash handover'
      })
    });
    assert.equal(resReq.status, 200);
    const reqData = await resReq.json();
    assert.ok(reqData.handoverId);
    assert.equal(reqData.status, 'PENDING');

    // 4. Duplicate request while pending must fail
    const resDup = await fetch(`${BASE_URL}/handovers/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        amountPaise: 10000
      })
    });
    assert.equal(resDup.status, 400, 'Duplicate handover while pending must be rejected');

    // 5. Owner views pending handovers
    const resOwnerList = await fetch(`${BASE_URL}/owner/handovers`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resOwnerList.status, 200);
    const ownerList = await resOwnerList.json();
    const pendingHnd = ownerList.handovers.find(h => h.id === reqData.handoverId);
    assert.ok(pendingHnd, 'Owner must see pending handover');
    assert.equal(pendingHnd.amount_paise, handoverAmt);

    // 6. Owner acknowledges handover with ₹20 discrepancy (received ₹280 = 28000 paise)
    const receivedAmt = 28000;
    const resAck = await fetch(`${BASE_URL}/owner/handovers/${reqData.handoverId}/acknowledge`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        action: 'ACCEPT',
        receivedAmountPaise: receivedAmt,
        notes: '₹20 shortage noted'
      })
    });
    assert.equal(resAck.status, 200);
    const ackData = await resAck.json();
    assert.equal(ackData.status, 'ACCEPTED');
    assert.equal(ackData.discrepancyPaise, -2000);

    // 7. Verify cash held is now reduced by the settled amount
    const resSummAfter = await fetch(`${BASE_URL}/handovers/summary`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    const summAfter = await resSummAfter.json();
    assert.equal(summAfter.cashHeldPaise, summBefore.cashHeldPaise - receivedAmt);
  });

  test('18. Returns Workflow: Delivered order linking, inspection disposition, atomic stock & credit effect', async () => {
    // 1. Create a quick order for return test
    const returnOrderId = `ord_ret_${Date.now()}`;
    const returnOrder = {
      order: {
        id: returnOrderId,
        retailerId: 'R1',
        employeeId: 'user_sales',
        status: 'SUBMITTED',
        totalAmountPaise: 135000,
        createdAt: Date.now(),
        updatedAt: Date.now()
      },
      items: [{ id: `item_ret_${Date.now()}`, productId: 'P1', quantity: 3, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }]
    };
    const resOrder = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(returnOrder)
    });
    assert.equal(resOrder.status, 200, 'Order creation should succeed');
    const orderId = returnOrderId;

    // Approve
    const resAppr = await fetch(`${BASE_URL}/orders/${orderId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const apprData = await resAppr.json();
    assert.equal(resAppr.status, 200, `Approval failed: ${JSON.stringify(apprData)}`);

    // Start picking & pick item
    await fetch(`${BASE_URL}/orders/${orderId}/start-picking`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    await fetch(`${BASE_URL}/orders/${orderId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P1', isPicked: true })
    });
    const resPack = await fetch(`${BASE_URL}/orders/${orderId}/pack`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resPack.status, 200);

    // Dispatch
    const resDisp = await fetch(`${BASE_URL}/orders/${orderId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });
    assert.equal(resDisp.status, 200);

    // Request OTP & Deliver with CREDIT
    const resOtp = await fetch(`${BASE_URL}/orders/${orderId}/request-otp`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${deliveryToken}`, 'X-Test-Runner': 'true' }
    });
    const otpData = await resOtp.json();
    const resDel = await fetch(`${BASE_URL}/orders/${orderId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({
        otp: otpData.debugOtp,
        recipientName: 'Test Recipient',
        paymentMethod: 'CREDIT'
      })
    });
    assert.equal(resDel.status, 200);

    // Check P1 stock and R1 balance before return
    const resP1Before = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${warehouseToken}` } });
    const p1ListBefore = await resP1Before.json();
    const p1Before = p1ListBefore.find(p => p.id === 'P1');
    const p1StockBefore = p1Before.stockQuantity;

    const resR1Before = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const r1ListBefore = await resR1Before.json();
    const r1Before = r1ListBefore.find(r => r.id === 'R1');
    const r1BalBefore = r1Before.outstandingAmountPaise;

    // 2. Submit return request for 2 units of P1 (Order has 3 units)
    const resRetReq = await fetch(`${BASE_URL}/returns`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        orderId: orderId,
        items: [{ productId: 'P1', requestedQuantity: 2 }],
        notes: 'Damaged packaging during transit'
      })
    });
    assert.equal(resRetReq.status, 200);
    const retReqData = await resRetReq.json();
    assert.ok(retReqData.returnId);

    // 3. Warehouse manager retrieves pending returns
    const resPendingRet = await fetch(`${BASE_URL}/returns/pending`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resPendingRet.status, 200);
    const pendingList = await resPendingRet.json();
    const foundReturn = pendingList.returns.find(r => r.id === retReqData.returnId);
    assert.ok(foundReturn, 'Warehouse must see pending return');
    assert.equal(foundReturn.items[0].requested_quantity, 2);

    // 4. Warehouse inspects: 1 saleable (restocked), 1 damaged (not restocked), total 2 credited
    const resInspect = await fetch(`${BASE_URL}/returns/${retReqData.returnId}/inspect`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        action: 'APPROVE',
        items: [{ productId: 'P1', saleableQuantity: 1, damagedQuantity: 1 }],
        notes: '1 unit restocked to shelf, 1 written off as damaged packaging'
      })
    });
    const inspectData = await resInspect.json();
    assert.equal(resInspect.status, 200, `Inspection failed: ${JSON.stringify(inspectData)}`);
    assert.equal(inspectData.status, 'APPROVED');
    assert.ok(inspectData.totalCreditNotePaise > 0);

    // 5. Verify atomic stock effect: P1 stock increased by exactly 1 (saleable)
    const resP1After = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${warehouseToken}` } });
    const p1ListAfter = await resP1After.json();
    const p1After = p1ListAfter.find(p => p.id === 'P1');
    assert.equal(p1After.stockQuantity, p1StockBefore + 1, 'Stock must increase by saleable quantity');

    // 6. Verify atomic credit note effect: R1 balance decreased by credit note amount
    const resR1After = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const r1ListAfter = await resR1After.json();
    const r1After = r1ListAfter.find(r => r.id === 'R1');
    assert.equal(r1After.outstandingAmountPaise, r1BalBefore - inspectData.totalCreditNotePaise, 'Retailer balance must decrease by credit note amount');

    // 7. Double inspection rejected (cannot process twice)
    const resInspectAgain = await fetch(`${BASE_URL}/returns/${retReqData.returnId}/inspect`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        action: 'APPROVE',
        items: [{ productId: 'P1', saleableQuantity: 3, damagedQuantity: 1 }]
      })
    });
    assert.equal(resInspectAgain.status, 400, 'Cannot inspect already processed return');
  });

  test('19. Partial & Failed Deliveries: Item quantities, driver-held stock, warehouse acknowledgement & accounting', async () => {
    // Check initial R1 balance and P1, P2 stocks
    const r1InitRes = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const r1InitList = await r1InitRes.json();
    const r1Init = r1InitList.find(r => r.id === 'R1');
    const r1BalInit = r1Init.outstandingAmountPaise;

    const pInitRes = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${warehouseToken}` } });
    const pInitList = await pInitRes.json();
    const p2InitStock = pInitList.find(p => p.id === 'P2').stockQuantity;

    // --- PART A: Partial Delivery ---
    // 1. Create order with 5 units of P1 (price 45000 paise each, total 225000 paise)
    const partialOrdId = 'ord_partial_test_' + Date.now();
    const orderPartialReq = {
      order: {
        id: partialOrdId,
        retailerId: 'R1',
        employeeId: 'user_sales',
        status: 'SUBMITTED',
        totalAmountPaise: 225000,
        createdAt: Date.now(),
        updatedAt: Date.now()
      },
      items: [{
        id: 'item_part_1_' + Date.now(),
        orderId: partialOrdId,
        productId: 'P1',
        quantity: 5,
        freeQuantity: 0,
        pricePaiseAtTime: 45000,
        isPicked: false
      }],
      idempotencyKey: 'idemp_partial_' + Date.now()
    };
    const resCreate = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(orderPartialReq)
    });
    assert.equal(resCreate.status, 200, 'Order creation should succeed');

    // Approve -> Pick -> Pack -> Dispatch to user_delivery
    await fetch(`${BASE_URL}/orders/${partialOrdId}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } });
    await fetch(`${BASE_URL}/orders/${partialOrdId}/start-picking`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${partialOrdId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P1', isPicked: true })
    });
    await fetch(`${BASE_URL}/orders/${partialOrdId}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${partialOrdId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });

    // 2. Deliver partially: 3 delivered (135000 paise), 2 undelivered with reason SHORTAGE
    const resPartDel = await fetch(`${BASE_URL}/orders/${partialOrdId}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({
        paymentMethod: 'CREDIT',
        recipientName: 'Ramesh Storekeeper',
        items: [{
          productId: 'P1',
          deliveredQuantity: 3,
          deliveredFreeQuantity: 0,
          undeliveredQuantity: 2,
          undeliveredFreeQuantity: 0,
          undeliveredReason: 'SHORTAGE'
        }]
      })
    });
    const partDelData = await resPartDel.json();
    assert.equal(resPartDel.status, 200, `Partial delivery failed: ${JSON.stringify(partDelData)}`);
    assert.equal(partDelData.status, 'PARTIALLY_DELIVERED');
    assert.equal(partDelData.deliveredAmountPaise, 135000);

    // 3. Verify R1 balance increased ONLY by delivered amount (135000 paise)
    const r1AfterPartRes = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const r1AfterPart = (await r1AfterPartRes.json()).find(r => r.id === 'R1');
    assert.equal(r1AfterPart.outstandingAmountPaise, r1BalInit + 135000, 'Balance must increase by delivered amount only');

    // 4. Verify undelivered goods tracked as HELD_BY_DRIVER
    const resUndel = await fetch(`${BASE_URL}/warehouse/undelivered-goods?status=HELD_BY_DRIVER`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    const undelList = await resUndel.json();
    const p1Held = undelList.find(u => u.orderId === partialOrdId && u.productId === 'P1');
    assert.ok(p1Held, 'Undelivered goods record must exist for P1');
    assert.equal(p1Held.undeliveredPaidQuantity, 2);
    assert.equal(p1Held.reason, 'SHORTAGE');
    assert.equal(p1Held.status, 'HELD_BY_DRIVER');

    // --- PART B: Failed Delivery ---
    // 5. Create order with 2 units of P2 (price 12000 paise each, total 24000 paise)
    const failOrdId = 'ord_fail_test_' + Date.now();
    const orderFailReq = {
      order: {
        id: failOrdId,
        retailerId: 'R1',
        employeeId: 'user_sales',
        status: 'SUBMITTED',
        totalAmountPaise: 24000,
        createdAt: Date.now(),
        updatedAt: Date.now()
      },
      items: [{
        id: 'item_fail_1_' + Date.now(),
        orderId: failOrdId,
        productId: 'P2',
        quantity: 2,
        freeQuantity: 0,
        pricePaiseAtTime: 12000,
        isPicked: false
      }],
      idempotencyKey: 'idemp_fail_' + Date.now()
    };
    const resCreateFail = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(orderFailReq)
    });
    const createFailData = await resCreateFail.json();
    assert.equal(resCreateFail.status, 200, `Fail test order creation should succeed: ${JSON.stringify(createFailData)}`);

    await fetch(`${BASE_URL}/orders/${failOrdId}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } });
    await fetch(`${BASE_URL}/orders/${failOrdId}/start-picking`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${failOrdId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P2', isPicked: true })
    });
    await fetch(`${BASE_URL}/orders/${failOrdId}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${failOrdId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });

    // 6. Record delivery failure: SHOP_CLOSED, rescheduled for 2026-10-01
    const resFail = await fetch(`${BASE_URL}/orders/${failOrdId}/delivery-failed`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({
        reason: 'SHOP_CLOSED',
        rescheduledDate: '2026-10-01',
        notes: 'Shop shutters down, owner on holiday'
      })
    });
    const failData = await resFail.json();
    assert.equal(resFail.status, 200, `Failed delivery call error: ${JSON.stringify(failData)}`);
    assert.equal(failData.status, 'DELIVERY_FAILED');

    // 7. Verify R1 balance remains UNCHANGED after delivery failure
    const r1AfterFailRes = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const r1AfterFail = (await r1AfterFailRes.json()).find(r => r.id === 'R1');
    assert.equal(r1AfterFail.outstandingAmountPaise, r1AfterPart.outstandingAmountPaise, 'Failed delivery must not change retailer balance');

    // --- PART C: Owner Exceptions & Driver-Held Stock ---
    // 8. Owner lists delivery exceptions
    const resExceptions = await fetch(`${BASE_URL}/owner/delivery-exceptions`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resExceptions.status, 200);
    const exceptions = await resExceptions.json();
    const foundPartExc = exceptions.find(e => e.id === partialOrdId);
    const foundFailExc = exceptions.find(e => e.id === failOrdId);
    assert.ok(foundPartExc, 'Owner must see partially delivered order');
    assert.ok(foundFailExc, 'Owner must see failed delivery order');
    assert.equal(foundFailExc.deliveryFailureReason, 'SHOP_CLOSED');
    assert.equal(foundFailExc.rescheduledDate, '2026-10-01');

    // 9. Owner / Driver checks driver-held stock
    const resDriverStock = await fetch(`${BASE_URL}/owner/driver-held-stock`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resDriverStock.status, 200);
    const driverStock = await resDriverStock.json();
    const p2DriverHeld = driverStock.find(d => d.productId === 'P2' && d.driverId === 'user_delivery');
    assert.ok(p2DriverHeld, 'Driver held stock must include P2');
    assert.equal(p2DriverHeld.totalPaidQuantity, 2);

    // --- PART D: Warehouse Return Acknowledgement & Stock Restoration ---
    // 10. Warehouse manager acknowledges return of P2: 1 saleable, 1 damaged
    const resUndelP2 = await fetch(`${BASE_URL}/warehouse/undelivered-goods?status=HELD_BY_DRIVER`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    const undelListP2 = await resUndelP2.json();
    const p2UndelRecord = undelListP2.find(u => u.orderId === failOrdId && u.productId === 'P2');
    assert.ok(p2UndelRecord, 'Undelivered goods record for P2 must exist');

    const resAck = await fetch(`${BASE_URL}/warehouse/undelivered-goods/${p2UndelRecord.id}/acknowledge`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({
        status: 'RETURNED_TO_WAREHOUSE',
        saleableQuantity: 1,
        damagedQuantity: 1,
        shortageQuantity: 0,
        notes: '1 unit intact, 1 unit crushed during return'
      })
    });
    const ackData = await resAck.json();
    assert.equal(resAck.status, 200, `Acknowledge failed: ${JSON.stringify(ackData)}`);
    assert.equal(ackData.status, 'RETURNED_TO_WAREHOUSE');

    // 11. Verify P2 warehouse stock restored by exactly 1 saleable unit
    const pAfterAckRes = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${warehouseToken}` } });
    const pAfterAckList = await pAfterAckRes.json();
    const p2AfterStock = pAfterAckList.find(p => p.id === 'P2').stockQuantity;
    assert.equal(p2AfterStock, p2InitStock - 1, 'Saleable return must restore stock by exactly 1 unit');

    // 12. Cannot acknowledge already acknowledged goods (duplicate prevention)
    const resAckDup = await fetch(`${BASE_URL}/warehouse/undelivered-goods/${p2UndelRecord.id}/acknowledge`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({
        status: 'RETURNED_TO_WAREHOUSE',
        saleableQuantity: 1,
        damagedQuantity: 1,
        shortageQuantity: 0
      })
    });
    assert.equal(resAckDup.status, 400, 'Duplicate acknowledgement must be rejected');

    // 12b. Attempting retry delivery on goods already returned to warehouse must be rejected with 409
    const resRetryReturned = await fetch(`${BASE_URL}/orders/${failOrdId}/retry-delivery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({
        deliveryEmployeeId: 'user_delivery',
        rescheduledDate: '2026-10-02'
      })
    });
    assert.equal(resRetryReturned.status, 409, 'Retry must not reuse goods already returned to warehouse');

    // 13. Customer return on partial delivery: Limited to actual delivered quantity
    // For partialOrdId: 3 delivered out of 5 ordered.
    // Attempting to return 4 units of P1 must fail (exceeds delivered quantity 3)
    const resReturnExceed = await fetch(`${BASE_URL}/returns`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        orderId: partialOrdId,
        items: [{ productId: 'P1', requestedQuantity: 4 }]
      })
    });
    assert.equal(resReturnExceed.status, 400, 'Return exceeding delivered quantity on partial delivery must be rejected');

    // Valid return of 2 units of P1 (within delivered 3)
    const resReturnValid = await fetch(`${BASE_URL}/returns`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        orderId: partialOrdId,
        items: [{ productId: 'P1', requestedQuantity: 2 }]
      })
    });
    assert.equal(resReturnValid.status, 200, 'Valid return within delivered quantity must succeed');

    // Attempting to return 2 more units (2 already requested + 2 = 4 > 3 delivered) must fail
    const resReturnExceed2 = await fetch(`${BASE_URL}/returns`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),
        orderId: partialOrdId,
        items: [{ productId: 'P1', requestedQuantity: 2 }]
      })
    });
    assert.ok([400, 409].includes(resReturnExceed2.status), 'Cumulative return exceeding delivered quantity must be rejected');

    // 14. Duplicate delivery call on already partially delivered order is idempotent
    const resPartDelDup = await fetch(`${BASE_URL}/orders/${partialOrdId}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({
        paymentMethod: 'CREDIT',
        recipientName: 'Ramesh Storekeeper'
      })
    });
    assert.equal(resPartDelDup.status, 200);
    const dupData = await resPartDelDup.json();
    assert.equal(dupData.idempotent, true, 'Repeat delivery must be reported as idempotent');
  });

  test('20. Rescheduling and Retry Delivery Workflow: Credit revalidation, driver stock transfer & zero duplicate effects', async () => {
    // 1. Initial product stock check
    const pRes = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${warehouseToken}` } });
    const pList = await pRes.json();
    const p1StartStock = pList.find(p => p.id === 'P1').stockQuantity;

    // Initial R2 balance check
    const r2InitRes = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const r2InitList = await r2InitRes.json();
    const r2Init = r2InitList.find(r => r.id === 'R2');
    const r2BalInit = r2Init.outstandingAmountPaise;

    // 2. Submit order for R2: 10 paid + 1 free of P1 (450000 paise)
    const retryOrdId = 'ord_retry_test_' + Date.now();
    const orderRetryReq = {
      order: {
        id: retryOrdId,
        retailerId: 'R2',
        employeeId: 'user_sales',
        status: 'SUBMITTED',
        totalAmountPaise: 450000,
        createdAt: Date.now(),
        updatedAt: Date.now()
      },
      items: [{
        id: 'item_retry_1_' + Date.now(),
        orderId: retryOrdId,
        productId: 'P1',
        quantity: 10,
        freeQuantity: 1,
        pricePaiseAtTime: 45000,
        isPicked: false
      }],
      idempotencyKey: 'idemp_retry_order_' + Date.now()
    };
    const resCreate = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(orderRetryReq)
    });
    assert.equal(resCreate.status, 200, 'Order creation for retry test should succeed');

    // 3. Approve -> Pick -> Pack -> Dispatch to user_delivery
    await fetch(`${BASE_URL}/orders/${retryOrdId}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } });
    await fetch(`${BASE_URL}/orders/${retryOrdId}/start-picking`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${retryOrdId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P1', isPicked: true })
    });
    await fetch(`${BASE_URL}/orders/${retryOrdId}/pack`, { method: 'POST', headers: { Authorization: `Bearer ${warehouseToken}` } });
    await fetch(`${BASE_URL}/orders/${retryOrdId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });

    // Verify warehouse stock deducted by 11 (10 paid + 1 free)
    const pAfterDispatchRes = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${warehouseToken}` } });
    const pAfterDispatch = (await pAfterDispatchRes.json()).find(p => p.id === 'P1').stockQuantity;
    assert.equal(pAfterDispatch, p1StartStock - 11, 'Warehouse stock must be deducted exactly once at dispatch');

    // 4. Driver 1 reports delivery failure: SHOP_CLOSED
    const resFail = await fetch(`${BASE_URL}/orders/${retryOrdId}/delivery-failed`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({
        reason: 'SHOP_CLOSED',
        rescheduledDate: '2026-10-02',
        notes: 'Shop closed due to festival'
      })
    });
    assert.equal(resFail.status, 200);

    // Verify driver 1 holds undelivered stock (10 paid + 1 free)
    const resHeldBefore = await fetch(`${BASE_URL}/warehouse/undelivered-goods?driverId=user_delivery&status=HELD_BY_DRIVER`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    const heldListBefore = await resHeldBefore.json();
    const heldP1 = heldListBefore.find(u => u.orderId === retryOrdId);
    assert.ok(heldP1, 'Undelivered goods record must exist for driver 1');
    assert.equal(heldP1.undeliveredPaidQuantity, 10);
    assert.equal(heldP1.undeliveredFreeQuantity, 1);

    // 5. Test Credit Limit check during retry scheduling:
    // Temporarily reduce R2 credit limit to 1000 paise so exposure would be exceeded
    await fetch(`${BASE_URL}/retailers/R2`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ creditLimitPaise: 1000 })
    });

    // Attempt to schedule retry -> MUST FAIL with 400 (credit limit exceeded)
    const resRetryBlocked = await fetch(`${BASE_URL}/orders/${retryOrdId}/retry-delivery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({
        deliveryEmployeeId: 'user_delivery_2',
        rescheduledDate: '2026-10-02',
        notes: 'Retry attempt re-assigned'
      })
    });
    assert.equal(resRetryBlocked.status, 400, 'Retry must be blocked if credit limit is exceeded');

    // Restore R2 credit limit to 10,000,000 paise (1 lakh)
    await fetch(`${BASE_URL}/retailers/R2`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ creditLimitPaise: 10000000 })
    });

    // 6. Schedule retry and reassign to user_delivery_2
    const resRetrySuccess = await fetch(`${BASE_URL}/orders/${retryOrdId}/retry-delivery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({
        deliveryEmployeeId: 'user_delivery_2',
        rescheduledDate: '2026-10-02',
        notes: 'Retry attempt re-assigned to delivery executive 2'
      })
    });
    assert.equal(resRetrySuccess.status, 200, 'Retry scheduling must succeed');
    const retryData = await resRetrySuccess.json();
    assert.equal(retryData.status, 'OUT_FOR_DELIVERY');

    // Verify driver-held stock was transferred from user_delivery to user_delivery_2
    const resHeldDriver2 = await fetch(`${BASE_URL}/warehouse/undelivered-goods?driverId=user_delivery_2&status=HELD_BY_DRIVER`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    const heldListDriver2 = await resHeldDriver2.json();
    const heldP1Driver2 = heldListDriver2.find(u => u.orderId === retryOrdId);
    assert.ok(heldP1Driver2, 'Stock custody must be transferred to user_delivery_2');
    assert.equal(heldP1Driver2.undeliveredPaidQuantity, 10);
    assert.equal(heldP1Driver2.undeliveredFreeQuantity, 1);

    // 6b. Previous driver (user_delivery) must be rejected with 403 when trying to act on reassigned order
    const resPrevDriverBlocked = await fetch(`${BASE_URL}/orders/${retryOrdId}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${deliveryToken}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({
        paymentMethod: 'CREDIT',
        recipientName: 'Previous Driver Attempt',
        items: [{
          productId: 'P1',
          deliveredQuantity: 10,
          deliveredFreeQuantity: 1,
          undeliveredQuantity: 0,
          undeliveredFreeQuantity: 0
        }]
      })
    });
    assert.equal(resPrevDriverBlocked.status, 403, 'Previous driver must be forbidden from delivering reassigned order');

    // 7. Complete delivery by user_delivery_2
    const resDeliverRetry = await fetch(`${BASE_URL}/orders/${retryOrdId}/deliver`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${delivery2Token}`,
        'X-Test-Bypass-Delivery-Otp': 'true'
      },
      body: JSON.stringify({
        paymentMethod: 'CREDIT',
        recipientName: 'Gopal Store Owner',
        items: [{
          productId: 'P1',
          deliveredQuantity: 10,
          deliveredFreeQuantity: 1,
          undeliveredQuantity: 0,
          undeliveredFreeQuantity: 0,
          undeliveredReason: null
        }]
      })
    });
    assert.equal(resDeliverRetry.status, 200, 'Delivery completion on retry must succeed');
    const delRetryData = await resDeliverRetry.json();
    assert.equal(delRetryData.status, 'DELIVERED');
    assert.equal(delRetryData.deliveredAmountPaise, 450000);

    // 8. Verify Financials & Stock:
    // A. Retailer balance updated by delivered amount (450000 paise) exactly once
    const r2AfterRetryRes = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const r2AfterRetry = (await r2AfterRetryRes.json()).find(r => r.id === 'R2');
    assert.equal(r2AfterRetry.outstandingAmountPaise, r2BalInit + 450000, 'Retailer balance must increase by invoice amount');

    // B. Warehouse stock was NOT deducted again (still p1StartStock - 11)
    const pAfterFinalRes = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${warehouseToken}` } });
    const pAfterFinal = (await pAfterFinalRes.json()).find(p => p.id === 'P1').stockQuantity;
    assert.equal(pAfterFinal, p1StartStock - 11, 'Warehouse stock must not be deducted a second time on retry delivery');

    // C. Driver-held stock for this order is now 0 (resolved)
    const resHeldFinal = await fetch(`${BASE_URL}/warehouse/undelivered-goods?status=HELD_BY_DRIVER`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    const heldListFinal = await resHeldFinal.json();
    const heldOrderRetry = heldListFinal.find(u => u.orderId === retryOrdId);
    assert.equal(heldOrderRetry, undefined, 'Driver-held stock must be cleared upon successful retry delivery');
  });

  test('21. Bulk Order Items Retrieval: Bounded, Tenant-Isolated, and Role-Scoped', async () => {
    // 1. Submit two orders for company 1
    const ord1Id = `ord_bulk_1_${Date.now()}`;
    const res1 = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        idempotencyKey: `idemp_${ord1Id}`,
        order: { id: ord1Id, retailerId: 'R1', totalAmountPaise: 45000 },
        items: [{ id: `item_1_${Date.now()}`, productId: 'P1', quantity: 1, pricePaiseAtTime: 45000 }]
      })
    });
    assert.equal(res1.status, 200, 'Order 1 submission failed');

    const ord2Id = `ord_bulk_2_${Date.now()}`;
    const res2 = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        idempotencyKey: `idemp_${ord2Id}`,
        order: { id: ord2Id, retailerId: 'R1', totalAmountPaise: 12000 },
        items: [{ id: `item_2_${Date.now()}`, productId: 'P2', quantity: 1, pricePaiseAtTime: 12000 }]
      })
    });
    assert.equal(res2.status, 200, 'Order 2 submission failed');

    // 2. Fetch bulk items for both orders in a single API call
    const resBulk = await fetch(`${BASE_URL}/orders/items-bulk`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ orderIds: [ord1Id, ord2Id] })
    });
    assert.equal(resBulk.status, 200, 'Bulk items request failed');
    const bulkData = await resBulk.json();
    assert.ok(Array.isArray(bulkData.items), 'items must be an array');
    assert.equal(bulkData.items.length, 2, 'Must return items for both orders');
    const returnedOrderIds = new Set(bulkData.items.map(i => i.orderId));
    assert.ok(returnedOrderIds.has(ord1Id));
    assert.ok(returnedOrderIds.has(ord2Id));

    // 3. Multi-tenant isolation: Owner of company 2 cannot retrieve company 1 items
    const resComp2Bulk = await fetch(`${BASE_URL}/orders/items-bulk`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerComp2Token}` },
      body: JSON.stringify({ orderIds: [ord1Id, ord2Id] })
    });
    assert.equal(resComp2Bulk.status, 200);
    const comp2BulkData = await resComp2Bulk.json();
    assert.equal(comp2BulkData.items.length, 0, 'Cross-tenant bulk items request must return 0 items');

    // 4. Bounded validation: Empty orderIds returns empty items
    const resEmpty = await fetch(`${BASE_URL}/orders/items-bulk`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ orderIds: [] })
    });
    assert.equal(resEmpty.status, 200);
    assert.deepEqual(await resEmpty.json(), { items: [] });

    // 5. Bounded validation: >50 orderIds rejected
    const tooManyIds = Array.from({ length: 51 }, (_, i) => `ord_dummy_${i}`);
    const resTooMany = await fetch(`${BASE_URL}/orders/items-bulk`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ orderIds: tooManyIds })
    });
    assert.equal(resTooMany.status, 400, 'Must reject >50 order IDs');
  });

  test('22. Team Delegation & Employee Invitation Flow', async () => {
    // 1. Create a Team as Owner
    const teamRes = await fetch(`${BASE_URL}/teams`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ name: 'Jaipur North Beat Team' })
    });
    assert.equal(teamRes.status, 201, 'Team creation failed');
    const teamData = await teamRes.json();
    assert.ok(teamData.team.id);

    // 2. Non-owner (Salesperson) cannot create teams
    const teamSalesRes = await fetch(`${BASE_URL}/teams`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ name: 'Rogue Team' })
    });
    assert.equal(teamSalesRes.status, 403, 'Salesperson must not create teams');

    // 3. List teams
    const listTeamsRes = await fetch(`${BASE_URL}/teams`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(listTeamsRes.status, 200);
    const { teams } = await listTeamsRes.json();
    assert.ok(teams.some(t => t.name === 'Jaipur North Beat Team'));

    // 4. Invite an ADMIN / Team Leader
    const adminUsername = `admin_tl_${Date.now()}`;
    const inviteRes = await fetch(`${BASE_URL}/employees/invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        fullName: 'Vikram Singh TL',
        username: adminUsername,
        role: 'ADMIN'
      })
    });
    assert.equal(inviteRes.status, 201, 'Employee invitation failed');
    const inviteData = await inviteRes.json();
    assert.ok(inviteData.invitation.inviteToken, 'Must generate single-use invite token');
    const inviteToken = inviteData.invitation.inviteToken;

    // 5. Employee accepts invitation and sets password (public endpoint)
    const acceptRes = await fetch(`${BASE_URL}/auth/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        inviteToken,
        password: 'SecureAdminPassword123!'
      })
    });
    assert.equal(acceptRes.status, 200, 'Accept invite failed');

    // 6. Token is single-use: accepting again fails
    const acceptAgainRes = await fetch(`${BASE_URL}/auth/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        inviteToken,
        password: 'SecureAdminPassword123!'
      })
    });
    assert.equal(acceptAgainRes.status, 404, 'Single-use token must not be accepted twice');

    // 7. New Admin logs in
    const adminLoginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: adminUsername, password: 'SecureAdminPassword123!' })
    });
    assert.equal(adminLoginRes.status, 200, 'Admin login failed');
    const adminAuth = await adminLoginRes.json();
    assert.equal(adminAuth.user.role, 'ADMIN');
    const adminToken = adminAuth.access_token;

    // 8. Admin can view pending orders
    const adminPendingRes = await fetch(`${BASE_URL}/orders/pending`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert.equal(adminPendingRes.status, 200, 'Admin must be able to view pending orders');

    // 9. Admin can approve a submitted order within delegated limit
    const ordToApproveId = `ord_tl_appr_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        idempotencyKey: `idemp_${ordToApproveId}`,
        order: { id: ordToApproveId, retailerId: 'R1', totalAmountPaise: 45000 },
        items: [{ id: `item_appr_${Date.now()}`, productId: 'P1', quantity: 1, pricePaiseAtTime: 45000 }]
      })
    });
    const adminApproveRes = await fetch(`${BASE_URL}/orders/${ordToApproveId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert.equal(adminApproveRes.status, 200, 'Admin must be able to approve orders');
  });

  test('23. Public Owner Registration, Session Listing, Reauth & Password Change', async () => {
    // 1. Public owner registers a new distributor business
    const newOwnerUser = `newbiz_owner_${Date.now()}`;
    const registerRes = await fetch(`${BASE_URL}/auth/register-owner`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        businessName: 'Rajasthan Spice Traders',
        fullName: 'Ramesh Sharma',
        username: newOwnerUser,
        password: 'OwnerPassword456!',
        contactNumber: '9876543210'
      })
    });
    assert.equal(registerRes.status, 201, 'Owner registration failed');
    const regData = await registerRes.json();
    assert.ok(regData.access_token, 'Must return access token');
    assert.ok(regData.refresh_token, 'Must return refresh token');
    assert.equal(regData.user.role, 'OWNER');
    assert.equal(regData.user.status, 'ACTIVE');
    const newOwnerToken = regData.access_token;
    const newCompanyId = regData.user.companyId;

    // 2. Duplicate username rejected
    const dupRes = await fetch(`${BASE_URL}/auth/register-owner`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        businessName: 'Another Traders',
        fullName: 'Another Owner',
        username: newOwnerUser,
        password: 'AnotherPassword456!'
      })
    });
    assert.equal(dupRes.status, 409, 'Duplicate username must be rejected');

    // 3. New Owner has company isolation (cannot see company 1 products)
    const prodsRes = await fetch(`${BASE_URL}/products`, {
      headers: { Authorization: `Bearer ${newOwnerToken}` }
    });
    assert.equal(prodsRes.status, 200);
    const prods = await prodsRes.json();
    assert.equal(prods.length, 0, 'New business must start with 0 products');

    // 4. Session listing
    const sessionsRes = await fetch(`${BASE_URL}/auth/sessions`, {
      headers: { Authorization: `Bearer ${newOwnerToken}` }
    });
    assert.equal(sessionsRes.status, 200);
    const { sessions } = await sessionsRes.json();
    assert.ok(sessions.length >= 1, 'Must list active session');

    // 5. Reauthentication for sensitive owner actions
    const reauthRes = await fetch(`${BASE_URL}/auth/reauthenticate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${newOwnerToken}` },
      body: JSON.stringify({ password: 'OwnerPassword456!' })
    });
    assert.equal(reauthRes.status, 200, 'Reauthentication failed');
    const reauthData = await reauthRes.json();
    assert.ok(reauthData.reauthToken, 'Must return short-lived reauth token');

    // 6. Wrong password reauthentication rejected
    const badReauthRes = await fetch(`${BASE_URL}/auth/reauthenticate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${newOwnerToken}` },
      body: JSON.stringify({ password: 'WrongPassword!' })
    });
    assert.equal(badReauthRes.status, 401, 'Wrong password must be rejected');

    // 7. Password change
    const changePassRes = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${newOwnerToken}` },
      body: JSON.stringify({
        oldPassword: 'OwnerPassword456!',
        newPassword: 'BrandNewOwnerPassword789!'
      })
    });
    assert.equal(changePassRes.status, 200, 'Password change failed');

    // 8. Login with old password rejected
    const oldLoginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: newOwnerUser, password: 'OwnerPassword456!' })
    });
    assert.equal(oldLoginRes.status, 401, 'Old password must no longer work');

    // 9. Login with new password succeeds
    const newLoginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: newOwnerUser, password: 'BrandNewOwnerPassword789!' })
    });
    assert.equal(newLoginRes.status, 200, 'New password login failed');
  });

  test('24. Product batch GRN, FEFO ordering, expiry alerts, and permission enforcement', async () => {
    // 1. Get a product id to use for batch testing
    const catalogRes = await fetch(`${BASE_URL}/products`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(catalogRes.status, 200);
    const catalog = await catalogRes.json();
    assert.ok(catalog.length > 0, 'Catalog must have at least one product');
    const productId = catalog[0].id;

    const nowSec = Math.floor(Date.now() / 1000);
    const expiry60 = nowSec + 60 * 86400;   // expires in 60 days (safe)
    const expiry10 = nowSec + 10 * 86400;   // expires in 10 days (warn)
    const expiry3  = nowSec + 3 * 86400;    // expires in  3 days (block)

    // 2. Salesperson cannot create batch
    const noPermsRes = await fetch(`${BASE_URL}/batches`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${salesToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ productId, batchNo: 'B-INVALID', receivedQuantity: 10 })
    });
    assert.equal(noPermsRes.status, 403, 'Salesperson must not create batches');

    // 3. Create batch A (earliest expiry — should be picked first)
    const batchARes = await fetch(`${BASE_URL}/batches`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        productId, batchNo: 'BATCH-A', expiryDate: expiry10,
        rackBin: 'A1-Bin3', receivedQuantity: 50
      })
    });
    assert.equal(batchARes.status, 201, 'Batch A creation failed');
    const batchA = await batchARes.json();
    assert.equal(batchA.batchNo, 'BATCH-A');
    assert.equal(batchA.receivedQuantity, 50);
    const batchAId = batchA.id;

    // 4. Create batch B (later expiry)
    const batchBRes = await fetch(`${BASE_URL}/batches`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        productId, batchNo: 'BATCH-B', expiryDate: expiry60,
        rackBin: 'A2-Bin1', receivedQuantity: 100
      })
    });
    assert.equal(batchBRes.status, 201, 'Batch B creation failed');

    // 5. Create batch C (near-block threshold: 3 days)
    const batchCRes = await fetch(`${BASE_URL}/batches`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        productId, batchNo: 'BATCH-C', expiryDate: expiry3,
        receivedQuantity: 20
      })
    });
    assert.equal(batchCRes.status, 201, 'Batch C creation failed');
    const batchCId = (await batchCRes.json()).id;

    // 6. List batches for product — FEFO order: C first (earliest), then A, then B
    const listRes = await fetch(`${BASE_URL}/batches?productId=${productId}`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(listRes.status, 200);
    const listData = await listRes.json();
    const batchNos = listData.batches.map(b => b.batchNo);
    assert.equal(batchNos[0], 'BATCH-C', 'FEFO: BATCH-C (3d expiry) must come first');
    assert.equal(batchNos[1], 'BATCH-A', 'FEFO: BATCH-A (10d expiry) must come second');
    assert.equal(batchNos[2], 'BATCH-B', 'FEFO: BATCH-B (60d expiry) must come last');

    // Check nearExpiry / blocked flags (default config: warn=30d, block=7d)
    const batchCEntry = listData.batches.find(b => b.batchNo === 'BATCH-C');
    assert.ok(batchCEntry.nearExpiry, 'BATCH-C within 30d must be nearExpiry');
    assert.ok(batchCEntry.blocked,    'BATCH-C within 7d must be blocked');
    const batchBEntry = listData.batches.find(b => b.batchNo === 'BATCH-B');
    assert.ok(!batchBEntry.nearExpiry, 'BATCH-B at 60d must not be nearExpiry');

    // 7. Expiry alerts endpoint returns batches within warn window
    const alertsRes = await fetch(`${BASE_URL}/batches/expiry-alerts`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(alertsRes.status, 200);
    const alertsData = await alertsRes.json();
    const alertBatchNos = alertsData.alerts.map(a => a.batchNo);
    assert.ok(alertBatchNos.includes('BATCH-C'), 'BATCH-C must appear in expiry alerts');
    assert.ok(alertBatchNos.includes('BATCH-A'), 'BATCH-A (10d) must appear in expiry alerts');
    assert.ok(!alertBatchNos.includes('BATCH-B'), 'BATCH-B (60d) must not appear in expiry alerts');

    // 8. Update alert config
    const configRes = await fetch(`${BASE_URL}/batches/alert-config`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${ownerToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ warnDays: 15, blockDays: 5 })
    });
    assert.equal(configRes.status, 200);
    const configData = await configRes.json();
    assert.equal(configData.warnDays, 15);
    assert.equal(configData.blockDays, 5);

    // 9. Re-list with new config — BATCH-B should still not appear in alerts
    const alertsRes2 = await fetch(`${BASE_URL}/batches/expiry-alerts`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const alertsData2 = await alertsRes2.json();
    assert.ok(!alertsData2.alerts.map(a => a.batchNo).includes('BATCH-B'), 'BATCH-B still safe at 15d warn');

    // 10. Patch batch rack bin
    const patchRes = await fetch(`${BASE_URL}/batches/${batchAId}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${warehouseToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ rackBin: 'B3-Bin7' })
    });
    assert.equal(patchRes.status, 200, 'Patch batch failed');

    // 11. Invalid product id rejected
    const badProductRes = await fetch(`${BASE_URL}/batches`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ productId: 'nonexistent-product', batchNo: 'BAD', receivedQuantity: 10 })
    });
    assert.equal(badProductRes.status, 404, 'Nonexistent product must return 404');

    // 12. receivedQuantity <= 0 rejected
    const badQtyRes = await fetch(`${BASE_URL}/batches`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ productId, batchNo: 'BAD-QTY', receivedQuantity: 0 })
    });
    assert.equal(badQtyRes.status, 400, 'Zero quantity must be rejected');

    // 13. Tenant isolation: cross-company batch list must be empty
    const crossListRes = await fetch(`${BASE_URL}/batches?productId=${productId}`, {
      headers: { Authorization: `Bearer ${ownerComp2Token}` }
    });
    assert.equal(crossListRes.status, 404, 'Cross-company product lookup must return 404');
  });
});
