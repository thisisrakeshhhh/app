import assert from 'node:assert';

const BASE_URL = process.env.BASE_URL || 'http://127.0.0.1:8787';

async function req(path, method = 'GET', body = null, token = null, extraHeaders = {}) {
  const headers = { 'Content-Type': 'application/json', ...extraHeaders };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : null
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: res.status, ok: res.ok, body: json || text };
}

async function login(username, password) {
  const res = await req('/auth/login', 'POST', { username, password });
  assert.strictEqual(res.status, 200, `Login failed for ${username}: ${JSON.stringify(res.body)}`);
  return res.body.access_token;
}

async function getRetailer(token) {
  const res = await req('/retailers', 'GET', null, token);
  const list = Array.isArray(res.body) ? res.body : res.body.retailers;
  return list.find(r => r.id === 'R4');
}

async function getP1(token) {
  const res = await req('/products', 'GET', null, token);
  const list = Array.isArray(res.body) ? res.body : res.body.products;
  return list.find(p => p.id === 'P1');
}

async function run() {
  console.log('--- Verifying Remaining-Return Limits ---');
  
  const ownerToken = await login('owner', 'password123');
  const salesToken = await login('sales', 'password123');
  const warehouseToken = await login('warehouse', 'password123');
  const deliveryToken = await login('delivery', 'password123');

  // 1. Snapshot initial state of Retailer R4 and Product P1
  const r4 = await getRetailer(salesToken);
  const initOutstanding = r4.outstandingAmountPaise;

  const p1 = await getP1(salesToken);
  const initStock = p1.stockQuantity;
  console.log(`Initial State -> R4 Balance: ${initOutstanding} paise, P1 Stock: ${initStock} units`);

  // 2. Submit, Approve, Dispatch, and Deliver an order
  const orderId = `ord_ret_test_${Date.now()}`;
  const now = Date.now();
  const orderRes = await req('/orders', 'POST', {
    order: {
      id: orderId,
      retailerId: 'R4',
      employeeId: 'user_sales',
      status: 'SUBMITTED',
      totalAmountPaise: 450000,
      createdAt: now,
      updatedAt: now
    },
    items: [
      { id: `item_${orderId}`, productId: 'P1', quantity: 10, freeQuantity: 1, pricePaiseAtTime: 45000, isPicked: false }
    ],
    idempotencyKey: `idemp_${orderId}`
  }, salesToken);
  assert.ok(orderRes.status === 200 || orderRes.status === 201, `Order creation failed: ${JSON.stringify(orderRes.body)}`);
  console.log(`Created Order: ${orderId} (10 paid, 1 free)`);

  // Owner Approve
  const approveRes = await req(`/orders/${orderId}/approve`, 'POST', {}, ownerToken);
  assert.strictEqual(approveRes.status, 200, `Approval failed`);

  // Warehouse start picking
  const pickRes = await req(`/orders/${orderId}/start-picking`, 'POST', {}, warehouseToken);
  assert.strictEqual(pickRes.status, 200, `Start picking failed`);

  const pickItemRes = await req(`/orders/${orderId}/pick-item`, 'POST', { productId: 'P1', isPicked: true }, warehouseToken);
  assert.strictEqual(pickItemRes.status, 200, `Pick item failed`);

  // Warehouse pack
  const packRes = await req(`/orders/${orderId}/pack`, 'POST', {}, warehouseToken);
  assert.strictEqual(packRes.status, 200, `Pack failed`);

  // Warehouse dispatch
  const dispatchRes = await req(`/orders/${orderId}/dispatch`, 'POST', { deliveryEmployeeId: 'user_delivery' }, warehouseToken);
  assert.strictEqual(dispatchRes.status, 200, `Dispatch failed`);

  // Delivery OTP confirmation
  const deliverRes = await req(`/orders/${orderId}/deliver`, 'POST', {
    paymentMethod: 'CREDIT',
    otp: '123456',
    recipientName: 'Sharmaji'
  }, deliveryToken, { 'X-Test-Runner': 'true', 'X-Test-Bypass-Delivery-Otp': 'true' });
  assert.strictEqual(deliverRes.status, 200, `Delivery failed: ${JSON.stringify(deliverRes.body)}`);
  console.log(`Order ${orderId} DELIVERED successfully.`);

  // Verify stock and balance after delivery
  const p1AfterDel = await getP1(salesToken);
  const r1AfterDel = await getRetailer(salesToken);
  const deliveredStock = p1AfterDel.stockQuantity;
  const deliveredBalance = r1AfterDel.outstandingAmountPaise;
  console.log(`Post-Delivery State -> R1 Balance: ${deliveredBalance} paise, P1 Stock: ${deliveredStock}`);

  // 3. First Return Request: 4 paid units (out of 10), 0 free units (out of 1)
  const ret1Res = await req('/returns', 'POST', {
    orderId,
    items: [{ productId: 'P1', requestedQuantity: 4, freeQuantity: 0 }],
    notes: 'Return 4 paid units'
  }, salesToken);
  assert.strictEqual(ret1Res.status, 200, `Return 1 failed: ${JSON.stringify(ret1Res.body)}`);
  const ret1Id = ret1Res.body.returnId;
  console.log(`Return 1 submitted: ${ret1Id} (4 paid units)`);

  // Check that stock and balance are UNCHANGED upon return request
  const p1Check1 = await getP1(salesToken);
  const r1Check1 = await getRetailer(salesToken);
  assert.strictEqual(p1Check1.stockQuantity, deliveredStock, 'Stock changed prematurely upon return request!');
  assert.strictEqual(r1Check1.outstandingAmountPaise, deliveredBalance, 'Balance changed prematurely upon return request!');

  // 4. Second Return Request: EXCEEDING remaining delivered quantity
  // Delivered: 10 paid. Already requested in Ret 1: 4. Remaining: 6.
  // Attempt to return: 7 paid units (4 + 7 = 11 > 10).
  console.log('Attempting Second Return with requestedQuantity = 7 (exceeds remaining 6)...');
  const ret2ExcessRes = await req('/returns', 'POST', {
    orderId,
    items: [{ productId: 'P1', requestedQuantity: 7, freeQuantity: 0 }],
    notes: 'Excess return attempt'
  }, salesToken);

  console.log(`Excess return response: HTTP ${ret2ExcessRes.status}, body:`, ret2ExcessRes.body);
  assert.ok(ret2ExcessRes.status === 409 || ret2ExcessRes.status === 400 || ret2ExcessRes.status === 500, 'Excess return was not rejected!');
  const errorMsg = typeof ret2ExcessRes.body === 'string' ? ret2ExcessRes.body : JSON.stringify(ret2ExcessRes.body);
  assert.ok(errorMsg.includes('exceeds remaining') || errorMsg.includes('Return exceeds remaining delivered quantity'), 'Expected remaining quantity violation');

  // Verify stock, balance, and credit notes after rejection
  const p1Check2 = await getP1(salesToken);
  const r1Check2 = await getRetailer(salesToken);
  assert.strictEqual(p1Check2.stockQuantity, deliveredStock, 'Stock mutated on rejected excess return!');
  assert.strictEqual(r1Check2.outstandingAmountPaise, deliveredBalance, 'Balance mutated on rejected excess return!');
  console.log('Confirmed: Stock and balance unchanged after excess return rejection.');

  // 5. Attempt return exceeding free quantity
  // Delivered: 1 free. Remaining: 1. Attempt to return: 2 free units.
  console.log('Attempting Return with freeQuantity = 2 (exceeds delivered 1)...');
  const retFreeExcessRes = await req('/returns', 'POST', {
    orderId,
    items: [{ productId: 'P1', requestedQuantity: 1, freeQuantity: 2 }],
    notes: 'Excess free return attempt'
  }, salesToken);
  assert.ok(retFreeExcessRes.status >= 400, 'Excess free return was not rejected!');
  console.log('Confirmed: Excess free return rejected.');

  // 6. Valid Second Return Request: exact remaining (6 paid units, 1 free unit)
  // 4 (prior) + 6 (new) = 10 (total delivered paid)
  // 0 (prior) + 1 (new) = 1 (total delivered free)
  console.log('Submitting valid Second Return with remaining 6 paid units and 1 free unit...');
  const ret2ValidRes = await req('/returns', 'POST', {
    orderId,
    items: [{ productId: 'P1', requestedQuantity: 6, freeQuantity: 1 }],
    notes: 'Valid remaining return'
  }, salesToken);
  assert.strictEqual(ret2ValidRes.status, 200, `Valid return failed: ${JSON.stringify(ret2ValidRes.body)}`);
  const ret2Id = ret2ValidRes.body.returnId;
  console.log(`Return 2 submitted: ${ret2Id} (6 paid, 1 free)`);

  // 7. Third Return Request: Even 1 additional unit must now be rejected
  console.log('Attempting Third Return with requestedQuantity = 1 when 0 remain...');
  const ret3Res = await req('/returns', 'POST', {
    orderId,
    items: [{ productId: 'P1', requestedQuantity: 1, freeQuantity: 0 }],
    notes: 'Exhausted return attempt'
  }, salesToken);
  assert.ok(ret3Res.status >= 400, 'Exhausted return was not rejected!');
  console.log('Confirmed: Return rejected when remaining quantity is 0.');

  console.log('\n--- ALL REMAINING-RETURN LIMIT CHECKS PASSED ---');
}

run().catch(err => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
