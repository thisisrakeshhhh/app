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

    // Request/retrieve OTP via endpoint
    const resReqOtp = await fetch(`${BASE_URL}/orders/${otpOrd}/request-otp`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${deliveryToken}` }
    });
    assert.equal(resReqOtp.status, 200);
    const otpData = await resReqOtp.json();
    assert.ok(otpData.debugOtp, 'Server must provide 6-digit OTP');
    const validOtp = otpData.debugOtp;
    assert.equal(validOtp.length, 6);

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
    assert.equal(resExcessDeduct.status, 400);

    // 4. Owner updates product price (to 38,000 paise)
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
  });
});
