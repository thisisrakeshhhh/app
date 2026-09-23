import { test, describe, before } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { sign } from '@tsndr/cloudflare-worker-jwt';

const BASE_URL = 'http://127.0.0.1:8787';

describe('RouteFlow API End-to-End Integration Suite', () => {
  let ownerToken = '';
  let salesToken = '';
  let warehouseToken = '';
  let deliveryToken = '';
  let salesRefreshToken = '';

  test('1. Auth: Valid logins across all active roles', async () => {
    // Owner
    const resOwner = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'owner', password: 'password123' })
    });
    assert.equal(resOwner.status, 200, 'Owner login failed');
    const ownerData = await resOwner.json();
    assert.ok(ownerData.access_token);
    assert.equal(ownerData.user.role, 'OWNER');
    ownerToken = ownerData.access_token;

    // Salesperson
    const resSales = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123' })
    });
    assert.equal(resSales.status, 200, 'Sales login failed');
    const salesData = await resSales.json();
    assert.equal(salesData.user.role, 'SALESPERSON');
    salesToken = salesData.access_token;
    salesRefreshToken = salesData.refresh_token;

    // Warehouse Manager
    const resWh = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'warehouse', password: 'password123' })
    });
    assert.equal(resWh.status, 200, 'Warehouse login failed');
    const whData = await resWh.json();
    assert.equal(whData.user.role, 'WAREHOUSE_MANAGER');
    warehouseToken = whData.access_token;

    // Delivery Executive
    const resDel = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'delivery', password: 'password123' })
    });
    assert.equal(resDel.status, 200, 'Delivery login failed');
    const delData = await resDel.json();
    assert.equal(delData.user.role, 'DELIVERY_EXECUTIVE');
    deliveryToken = delData.access_token;
  });

  test('2. Auth Security: Rejections for invalid and disabled users', async () => {
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

  test('3. Auth Session: Refresh token rotation and reuse detection', async () => {
    // Rotate token
    const resRotate = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: salesRefreshToken })
    });
    assert.equal(resRotate.status, 200, 'Token rotation failed');
    const rotateData = await resRotate.json();
    assert.ok(rotateData.access_token);
    assert.ok(rotateData.refresh_token);
    assert.notEqual(rotateData.refresh_token, salesRefreshToken);

    const newRefreshToken = rotateData.refresh_token;

    // Replay attack: try to reuse the OLD refresh token
    const resReplay = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: salesRefreshToken })
    });
    assert.equal(resReplay.status, 401, 'Should detect reuse and return 401');

    // Verify all sessions were revoked for that user due to reuse detection
    const resAfterRevoke = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: newRefreshToken })
    });
    assert.equal(resAfterRevoke.status, 401, 'Subsequent session should be revoked after reuse detection');

    // Re-login sales for remaining tests
    const reLogin = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123' })
    });
    const reData = await reLogin.json();
    salesToken = reData.access_token;
  });

  test('4. Catalog: Server-authorized retailers and products formatting', async () => {
    // Retailers
    const resRet = await fetch(`${BASE_URL}/retailers`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    assert.equal(resRet.status, 200);
    const retailers = await resRet.json();
    assert.ok(retailers.length >= 6, 'Should load BEAT-04 retailers');
    const r1 = retailers.find(r => r.id === 'R1');
    assert.ok(r1, 'R1 must be present');
    assert.equal(r1.beatId, 'BEAT-04');
    assert.ok(typeof r1.creditLimitPaise === 'number');
    assert.ok(typeof r1.outstandingAmountPaise === 'number');

    // Products
    const resProd = await fetch(`${BASE_URL}/products`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    assert.equal(resProd.status, 200);
    const products = await resProd.json();
    assert.ok(products.length >= 10, 'Should load P1-P10 products');
    const p1 = products.find(p => p.id === 'P1');
    assert.ok(p1, 'P1 must be present');
    assert.equal(p1.pricePaise, 45000);
    assert.ok(typeof p1.stockQuantity === 'number');
    assert.ok(typeof p1.reservedQuantity === 'number');
  });

  test('5. Complete Server-Backed Order Journey', async () => {
    const testOrderId = `test_ord_${Date.now()}`;
    const idempotencyKey = `idemp_${Date.now()}`;

    // Get current stock and retailer balance before
    const prodRes = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const prods = await prodRes.json();
    const p1Before = prods.find(p => p.id === 'P1');
    const p2Before = prods.find(p => p.id === 'P2');
    const retRes = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const rets = await retRes.json();
    const r1Before = rets.find(r => r.id === 'R1');

    console.log(`\n--- Test Order Journey for: ${testOrderId} ---`);
    console.log(`Initial stock P1: ${p1Before.stockQuantity} (reserved: ${p1Before.reservedQuantity})`);
    console.log(`Initial retailer R1 outstanding: ${r1Before.outstandingAmountPaise} paise`);

    // STEP A: Salesperson submits order
    // Item 1: P1, qty: 2, free: 1 (price 45000 * 2 = 90000)
    // Item 2: P2, qty: 3, free: 0 (price 12000 * 3 = 36000)
    // Total: 126000 paise
    const totalAmount = (2 * 45000) + (3 * 12000);
    const orderPayload = {
      order: {
        id: testOrderId,
        retailerId: 'R1',
        employeeId: 'user_sales',
        status: 'SUBMITTED',
        totalAmountPaise: totalAmount,
        createdAt: Date.now(),
        updatedAt: Date.now()
      },
      items: [
        {
          id: `${testOrderId}_item1`,
          orderId: testOrderId,
          productId: 'P1',
          quantity: 2,
          freeQuantity: 1,
          pricePaiseAtTime: 45000,
          isPicked: false
        },
        {
          id: `${testOrderId}_item2`,
          orderId: testOrderId,
          productId: 'P2',
          quantity: 3,
          freeQuantity: 0,
          pricePaiseAtTime: 12000,
          isPicked: false
        }
      ],
      idempotencyKey: idempotencyKey
    };

    const resSubmit = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${salesToken}`
      },
      body: JSON.stringify(orderPayload)
    });
    assert.equal(resSubmit.status, 200, 'Order submission failed');
    const submitData = await resSubmit.json();
    assert.equal(submitData.orderId, testOrderId);

    // Verify Idempotent retry does not duplicate
    const resRetry = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${salesToken}`
      },
      body: JSON.stringify(orderPayload)
    });
    assert.equal(resRetry.status, 200);
    const retryData = await resRetry.json();
    assert.equal(retryData.orderId, testOrderId);
    assert.equal(retryData.idempotent, true, 'Retry must be idempotent');

    // STEP B: Owner views pending orders and approves
    const resPending = await fetch(`${BASE_URL}/orders/pending`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resPending.status, 200);
    const pendingList = await resPending.json();
    assert.ok(pendingList.some(o => o.id === testOrderId), 'Order must be in pending list');

    // Owner approves order
    const resApprove = await fetch(`${BASE_URL}/orders/${testOrderId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resApprove.status, 200, 'Order approval failed');

    // Verify stock reserved atomically
    const pResAfterApprove = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const prodsAfterApprove = await pResAfterApprove.json();
    const p1AfterApprove = prodsAfterApprove.find(p => p.id === 'P1');
    const p2AfterApprove = prodsAfterApprove.find(p => p.id === 'P2');
    assert.equal(p1AfterApprove.reservedQuantity, p1Before.reservedQuantity + 3, 'P1 reserved quantity must include free units (2+1)');
    assert.equal(p2AfterApprove.reservedQuantity, p2Before.reservedQuantity + 3, 'P2 reserved quantity must match required');
    console.log(`Stock after approval: P1 reserved = ${p1AfterApprove.reservedQuantity} (stock: ${p1AfterApprove.stockQuantity})`);

    // Repeated approval is idempotent
    const resApproveAgain = await fetch(`${BASE_URL}/orders/${testOrderId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resApproveAgain.status, 200);
    const approveAgainData = await resApproveAgain.json();
    assert.equal(approveAgainData.idempotent, true);

    // STEP C: Warehouse picks items
    // Pick item 1
    const resPick1 = await fetch(`${BASE_URL}/orders/${testOrderId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P1', isPicked: true })
    });
    assert.equal(resPick1.status, 200, 'Pick item 1 failed');

    // Try packing before item 2 is picked -> MUST FAIL
    const resEarlyPack = await fetch(`${BASE_URL}/orders/${testOrderId}/pack`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resEarlyPack.status, 400, 'Packing must fail when unpicked items remain');

    // Pick item 2
    const resPick2 = await fetch(`${BASE_URL}/orders/${testOrderId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P2', isPicked: true })
    });
    assert.equal(resPick2.status, 200, 'Pick item 2 failed');

    // STEP D: Warehouse packs order
    const resPack = await fetch(`${BASE_URL}/orders/${testOrderId}/pack`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resPack.status, 200, 'Packing should succeed after all items picked');

    // STEP E: Warehouse dispatches order
    // Try dispatching without delivery executive -> MUST FAIL
    const resNoDriver = await fetch(`${BASE_URL}/orders/${testOrderId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({})
    });
    assert.equal(resNoDriver.status, 400, 'Dispatch must require assigned delivery executive');

    // Dispatch with assigned delivery executive user_delivery
    const resDispatch = await fetch(`${BASE_URL}/orders/${testOrderId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });
    assert.equal(resDispatch.status, 200, 'Dispatch failed');

    // Verify stock deduction and reservation release
    const pResAfterDispatch = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const prodsAfterDispatch = await pResAfterDispatch.json();
    const p1AfterDispatch = prodsAfterDispatch.find(p => p.id === 'P1');
    const p2AfterDispatch = prodsAfterDispatch.find(p => p.id === 'P2');
    assert.equal(p1AfterDispatch.stockQuantity, p1Before.stockQuantity - 3, 'P1 stock must be deducted by total quantity (2+1)');
    assert.equal(p1AfterDispatch.reservedQuantity, p1Before.reservedQuantity, 'P1 reservation must be released');
    console.log(`Stock after dispatch: P1 stock = ${p1AfterDispatch.stockQuantity} (reserved: ${p1AfterDispatch.reservedQuantity})`);

    // Repeated dispatch is idempotent
    const resDispatchAgain = await fetch(`${BASE_URL}/orders/${testOrderId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });
    assert.equal(resDispatchAgain.status, 200);
    const dispatchAgainData = await resDispatchAgain.json();
    assert.equal(dispatchAgainData.idempotent, true);

    // STEP F: Delivery completion
    // Non-assigned user attempting delivery -> MUST FAIL
    const resWrongDeliver = await fetch(`${BASE_URL}/orders/${testOrderId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({ paymentMethod: 'CREDIT' })
    });
    assert.equal(resWrongDeliver.status, 403, 'Unauthorized user cannot complete delivery');

    // Assigned driver completes delivery with CREDIT payment
    const resDeliver = await fetch(`${BASE_URL}/orders/${testOrderId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CREDIT' })
    });
    assert.equal(resDeliver.status, 200, 'Delivery completion failed');

    // Verify retailer balance posted
    const retResAfter = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const retsAfter = await retResAfter.json();
    const r1After = retsAfter.find(r => r.id === 'R1');
    assert.equal(
      r1After.outstandingAmountPaise,
      r1Before.outstandingAmountPaise + totalAmount,
      'Retailer outstanding balance must increase by order total for CREDIT payment'
    );
    console.log(`Retailer balance after CREDIT delivery: ${r1After.outstandingAmountPaise} paise (increased by ${totalAmount})`);

    // Repeated delivery is idempotent
    const resDeliverAgain = await fetch(`${BASE_URL}/orders/${testOrderId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}` },
      body: JSON.stringify({ paymentMethod: 'CREDIT' })
    });
    assert.equal(resDeliverAgain.status, 200);
    const deliverAgainData = await resDeliverAgain.json();
    assert.equal(deliverAgainData.idempotent, true);

    // Check final order state
    const resFinal = await fetch(`${BASE_URL}/orders/${testOrderId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const finalData = await resFinal.json();
    assert.equal(finalData.order.status, 'DELIVERED');
    assert.equal(finalData.order.paymentMethod, 'CREDIT');
    assert.equal(finalData.order.deliveryEmployeeId, 'user_delivery');
    console.log(`Order ${testOrderId} final status: ${finalData.order.status}, payment: ${finalData.order.paymentMethod}`);
  });

  test('6. Order Rejection and Stock Reservation Rollback', async () => {
    const rejectOrderId = `test_rej_${Date.now()}`;
    const idempotencyKey = `idemp_rej_${Date.now()}`;

    // Get P3 stock before
    const prodResBefore = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const p3Before = (await prodResBefore.json()).find(p => p.id === 'P3');

    // Submit order for 5 units of P3
    const orderPayload = {
      order: {
        id: rejectOrderId,
        retailerId: 'R2',
        employeeId: 'user_sales',
        status: 'SUBMITTED',
        totalAmountPaise: 5 * 65000,
        createdAt: Date.now(),
        updatedAt: Date.now()
      },
      items: [
        {
          id: `${rejectOrderId}_item`,
          orderId: rejectOrderId,
          productId: 'P3',
          quantity: 5,
          freeQuantity: 0,
          pricePaiseAtTime: 65000,
          isPicked: false
        }
      ],
      idempotencyKey: idempotencyKey
    };

    const resSubmit = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(orderPayload)
    });
    assert.equal(resSubmit.status, 200);

    // Owner approves
    const resApprove = await fetch(`${BASE_URL}/orders/${rejectOrderId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resApprove.status, 200);

    // Verify reserved
    const p3Reserved = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P3');
    assert.equal(p3Reserved.reservedQuantity, p3Before.reservedQuantity + 5);

    // Owner rejects with reason
    const resReject = await fetch(`${BASE_URL}/orders/${rejectOrderId}/reject`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ reason: 'Customer requested cancellation prior to packing' })
    });
    assert.equal(resReject.status, 200);

    // Verify stock reservation was released back to 0
    const p3AfterReject = (await (await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } })).json()).find(p => p.id === 'P3');
    assert.equal(p3AfterReject.reservedQuantity, p3Before.reservedQuantity, 'Reservation must be rolled back on rejection');

    // Verify order details reflect rejection
    const orderRes = await fetch(`${BASE_URL}/orders/${rejectOrderId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const orderData = await orderRes.json();
    assert.equal(orderData.order.status, 'REJECTED');
    assert.equal(orderData.order.rejectionReason, 'Customer requested cancellation prior to packing');
    console.log(`Rejection verified: reason preserved and stock reservation rolled back`);
  });

  test('7. Advanced Auth: Expired tokens, Logout session revocation, and Cross-tenant isolation', async () => {
    // Read secret from .dev.vars without printing it
    const devVars = fs.readFileSync('.dev.vars', 'utf-8');
    const secretLine = devVars.split('\n').find(l => l.startsWith('JWT_SECRET='));
    const jwtSecret = secretLine ? secretLine.substring('JWT_SECRET='.length).trim() : 'dummy';

    // A. Expired token rejection
    const expiredToken = await sign({
      sub: 'user_sales',
      company_id: 'comp_1',
      role: 'SALESPERSON',
      name: 'Rakesh Kumar',
      exp: Math.floor(Date.now() / 1000) - 60
    }, jwtSecret);

    const resExpired = await fetch(`${BASE_URL}/retailers`, {
      headers: { Authorization: `Bearer ${expiredToken}` }
    });
    assert.equal(resExpired.status, 401, 'Expired token must return 401');

    // B. Logout revokes server session
    const tempLogin = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123' })
    });
    const { access_token: tempAccess, refresh_token: tempRefresh } = await tempLogin.json();

    const resLogout = await fetch(`${BASE_URL}/auth/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tempAccess}` }
    });
    assert.equal(resLogout.status, 200, 'Logout must succeed');

    const resRefreshAfterLogout = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: tempRefresh })
    });
    assert.equal(resRefreshAfterLogout.status, 401, 'Refresh token must be invalid after logout');

    // Re-login sales for subsequent tests
    const salesReLogin = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'sales', password: 'password123' })
    });
    salesToken = (await salesReLogin.json()).access_token;

    // C. Cross-tenant isolation: Accessing non-tenant retailer
    const fakeCrossOrder = {
      order: {
        id: `cross_ord_${Date.now()}`,
        retailerId: 'foreign_retailer_99',
        employeeId: 'user_sales',
        status: 'SUBMITTED',
        totalAmountPaise: 45000,
        createdAt: Date.now(),
        updatedAt: Date.now()
      },
      items: [
        {
          id: `item_cross_${Date.now()}`,
          orderId: `cross_ord_${Date.now()}`,
          productId: 'P1',
          quantity: 1,
          freeQuantity: 0,
          pricePaiseAtTime: 45000,
          isPicked: false
        }
      ],
      idempotencyKey: `idemp_cross_${Date.now()}`
    };

    const resCross = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify(fakeCrossOrder)
    });
    assert.equal(resCross.status, 400, 'Cross-company retailer must be rejected');
  });

  test('8. Concurrency & Integrity: Race-condition stock reservation and submission rollback', async () => {
    // Check initial stock of P8 (Sugar 5kg, total stock = 60)
    const prodRes = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const p8Initial = (await prodRes.json()).find(p => p.id === 'P8');
    const availableP8 = p8Initial.stockQuantity - p8Initial.reservedQuantity;

    // Order 1 requires 60% of available stock
    const qty1 = Math.floor(availableP8 * 0.6);
    // Order 2 requires 60% of available stock (combined 120% > available)
    const qty2 = Math.floor(availableP8 * 0.6);

    const orderId1 = `race_ord_1_${Date.now()}`;
    const orderId2 = `race_ord_2_${Date.now()}`;

    // Submit Order 1
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: {
          id: orderId1,
          retailerId: 'R1',
          employeeId: 'user_sales',
          status: 'SUBMITTED',
          totalAmountPaise: qty1 * 22000,
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: `${orderId1}_item`, orderId: orderId1, productId: 'P8', quantity: qty1, freeQuantity: 0, pricePaiseAtTime: 22000, isPicked: false }],
        idempotencyKey: `idemp_${orderId1}`
      })
    });

    // Submit Order 2
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: {
          id: orderId2,
          retailerId: 'R1',
          employeeId: 'user_sales',
          status: 'SUBMITTED',
          totalAmountPaise: qty2 * 22000,
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: `${orderId2}_item`, orderId: orderId2, productId: 'P8', quantity: qty2, freeQuantity: 0, pricePaiseAtTime: 22000, isPicked: false }],
        idempotencyKey: `idemp_${orderId2}`
      })
    });

    // Concurrent Approvals
    const [resApprove1, resApprove2] = await Promise.all([
      fetch(`${BASE_URL}/orders/${orderId1}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } }),
      fetch(`${BASE_URL}/orders/${orderId2}/approve`, { method: 'POST', headers: { Authorization: `Bearer ${ownerToken}` } })
    ]);

    const statuses = [resApprove1.status, resApprove2.status];
    assert.ok(statuses.includes(200), 'At least one approval must succeed');
    assert.ok(statuses.includes(400), 'Competing approval must fail with 400 Insufficient stock');

    // Verify stock was not over-reserved
    const prodResAfter = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const p8After = (await prodResAfter.json()).find(p => p.id === 'P8');
    assert.ok(p8After.reservedQuantity <= p8After.stockQuantity, 'Reserved quantity must never exceed available stock');

    // Clean up: reject the approved order so stock is released
    const approvedId = resApprove1.status === 200 ? orderId1 : orderId2;
    await fetch(`${BASE_URL}/orders/${approvedId}/reject`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ reason: 'Cleanup after concurrency test' })
    });

    // Verify Submission Rollback on error
    const failedOrderId = `fail_ord_${Date.now()}`;
    const resFailedSubmit = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: {
          id: failedOrderId,
          retailerId: 'R1',
          employeeId: 'user_sales',
          status: 'SUBMITTED',
          totalAmountPaise: 9999999, // price mismatch
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: `${failedOrderId}_item`, orderId: failedOrderId, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 9999999, isPicked: false }],
        idempotencyKey: `idemp_${failedOrderId}`
      })
    });
    assert.equal(resFailedSubmit.status, 400, 'Price mismatch submission must fail');

    // Verify order does NOT exist in DB
    const resCheckOrder = await fetch(`${BASE_URL}/orders/${failedOrderId}`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resCheckOrder.status, 404, 'Failed submission must completely roll back');
  });
});
