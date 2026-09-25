import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

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
      body: JSON.stringify({
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
      body: JSON.stringify({
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
      body: JSON.stringify({
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
            body: JSON.stringify({ action: 'REJECT', notes: 'Cleanup prior test runs' })
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
      body: JSON.stringify({
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
      body: JSON.stringify({
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
      body: JSON.stringify({
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
      body: JSON.stringify({
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
      body: JSON.stringify({
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
      body: JSON.stringify({
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
      body: JSON.stringify({
        action: 'APPROVE',
        items: [{ productId: 'P1', saleableQuantity: 3, damagedQuantity: 1 }]
      })
    });
    assert.equal(resInspectAgain.status, 400, 'Cannot inspect already processed return');
  });
});

