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

    // Driver 1 delivers order: succeeds
    const resDel1Deliver = await fetch(`${BASE_URL}/orders/${delOrderId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
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
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}`, 'X-Test-Fail-Invoice': 'true' },
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
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
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
      fetch(`${BASE_URL}/orders/${ordA}/deliver`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` }, body: JSON.stringify({ paymentMethod: 'CREDIT' }) }),
      fetch(`${BASE_URL}/orders/${ordB}/deliver`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` }, body: JSON.stringify({ paymentMethod: 'CREDIT' }) })
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
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'UPI' })
    });
    assert.equal(resUpi.status, 400, 'UPI must be rejected as unverified payment method in this milestone');

    const resCheque = await fetch(`${BASE_URL}/orders/${settleOrd}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CHEQUE' })
    });
    assert.equal(resCheque.status, 400, 'CHEQUE must be rejected as unverified payment method in this milestone');

    // Deliver with CASH (immediate settlement) -> succeeds, balance unchanged
    const r1BeforeCash = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R1');
    const resCash = await fetch(`${BASE_URL}/orders/${settleOrd}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CASH' })
    });
    assert.equal(resCash.status, 200, 'CASH delivery must succeed');

    const r1AfterCash = (await (await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(r => r.id === 'R1');
    assert.equal(r1AfterCash.outstandingAmountPaise, r1BeforeCash.outstandingAmountPaise, 'CASH payment must NOT increase outstanding balance');
  });
});
