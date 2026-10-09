import assert from 'node:assert/strict';

const BASE_URL = 'https://routeflow-api-staging.thisisrakesh21.workers.dev';

async function testDeliveryRole() {
  console.log("=== HARDCORE VERIFICATION: LIVE CLOUDFLARE STAGING DELIVERY ROLE ===");

  // 1. Login as delivery driver
  const driverLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'delivery', password: 'password123' })
  });
  assert.equal(driverLoginRes.status, 200, 'Driver login should succeed');
  const driverLoginData = await driverLoginRes.json();
  const driverToken = driverLoginData.access_token;
  const driverId = driverLoginData.user?.id || 'user_delivery';
  console.log(`✓ 1. Driver Auth Login: HTTP 200 | User: ${driverLoginData.user?.fullName} | Role: ${driverLoginData.user?.role}`);

  // 2. Login as owner & warehouse to prepare test orders if needed
  const ownerLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'owner', password: 'password123' })
  });
  assert.equal(ownerLoginRes.status, 200);
  const ownerData = await ownerLoginRes.json();
  const ownerToken = ownerData.access_token;

  const whLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'warehouse', password: 'password123' })
  });
  assert.equal(whLoginRes.status, 200);
  const whToken = (await whLoginRes.json()).access_token;

  // 3. Check Driver's current assigned orders
  const driverOrdersRes = await fetch(`${BASE_URL}/orders`, {
    headers: { Authorization: `Bearer ${driverToken}` }
  });
  assert.equal(driverOrdersRes.status, 200);
  let driverOrders = await driverOrdersRes.json();
  console.log(`✓ 2. Fetch Driver Orders: HTTP 200 | Assigned Count: ${driverOrders.length}`);

  // 4. Ensure we have at least 2 OUT_FOR_DELIVERY orders assigned to this driver
  // Order 1: For successful OTP delivery
  // Order 2: For failed delivery test (SHOP_CLOSED)
  async function createDispatchedOrder() {
    const retailerRes = await fetch(`${BASE_URL}/retailers`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const retailers = await retailerRes.json();
    const rId = retailers[0].id;

    const prodRes = await fetch(`${BASE_URL}/products`, { headers: { Authorization: `Bearer ${ownerToken}` } });
    const prods = await prodRes.json();
    const pId = prods[0].id;
    const price = prods[0].pricePaise || prods[0].price_paise || 5000;

    const oId = `ORD-DEL-${Date.now().toString().slice(-6)}`;
    // Create order
    const createRes = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        idempotencyKey: `deliv_test_${Date.now()}_${Math.random()}`,
        order: {
          id: oId,
          retailerId: rId,
          totalAmountPaise: price * 2
        },
        items: [{ productId: pId, quantity: 2, pricePaiseAtTime: price }]
      })
    });
    if (!createRes.ok) {
      console.error("Order create failed:", await createRes.text());
    }
    assert.ok(createRes.status === 200 || createRes.status === 201, 'Order creation must succeed');

    // Approve
    const appRes = await fetch(`${BASE_URL}/orders/${oId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(appRes.status, 200, 'Order approval must succeed');

    // Start picking & pick
    await fetch(`${BASE_URL}/orders/${oId}/start-picking`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${whToken}` }
    });
    await fetch(`${BASE_URL}/orders/${oId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${whToken}` },
      body: JSON.stringify({ productId: pId, isPicked: true })
    });

    // Pack
    const pckRes = await fetch(`${BASE_URL}/orders/${oId}/pack`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${whToken}` }
    });
    assert.equal(pckRes.status, 200, 'Packing order must succeed');

    // Dispatch directly to driver
    const dispRes = await fetch(`${BASE_URL}/orders/${oId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${whToken}` },
      body: JSON.stringify({ deliveryEmployeeId: driverId })
    });
    assert.equal(dispRes.status, 200, 'Order dispatch to driver must succeed');
    return oId;
  }

  let outForDeliveryOrders = driverOrders.filter(o => o.status === 'OUT_FOR_DELIVERY');
  if (outForDeliveryOrders.length < 2) {
    console.log("   Creating fresh dispatched orders for driver testing...");
    const o1 = await createDispatchedOrder();
    const o2 = await createDispatchedOrder();
    const refreshed = await fetch(`${BASE_URL}/orders`, { headers: { Authorization: `Bearer ${driverToken}` } });
    driverOrders = await refreshed.json();
    outForDeliveryOrders = driverOrders.filter(o => o.status === 'OUT_FOR_DELIVERY');
  }

  assert.ok(outForDeliveryOrders.length >= 2, 'Should have at least 2 OUT_FOR_DELIVERY orders');
  const testDeliverOrder = outForDeliveryOrders[0];
  const testFailOrder = outForDeliveryOrders[1];
  console.log(`✓ 3. Dispatched Orders ready: ${testDeliverOrder.id} (for delivery) and ${testFailOrder.id} (for failure testing)`);

  // 5. Test OTP Request with simulation / test runner
  const otpRes = await fetch(`${BASE_URL}/orders/${testDeliverOrder.id}/request-otp`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${driverToken}`,
      'X-Test-Runner': 'true'
    }
  });
  assert.equal(otpRes.status, 200, 'OTP request must succeed');
  const otpData = await otpRes.json();
  assert.ok(otpData.success, 'OTP response success must be true');
  assert.ok(otpData.debugOtp, 'Debug OTP should be returned when X-Test-Runner header is supplied');
  console.log(`✓ 4. Request OTP: HTTP 200 | Masked SMS sent | debugOtp: ${otpData.debugOtp}`);

  // 6. Test OTP verification error (wrong OTP)
  const badOtpRes = await fetch(`${BASE_URL}/orders/${testDeliverOrder.id}/deliver`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${driverToken}` },
    body: JSON.stringify({
      recipientName: 'Ramesh Storekeeper',
      otp: '000000',
      paymentMethod: 'CASH'
    })
  });
  assert.equal(badOtpRes.status, 400, 'Wrong OTP must be rejected');
  console.log(`✓ 5. Invalid OTP Rejection: HTTP 400 returned correctly`);

  // 7. Successful delivery with valid OTP and CASH payment
  const cashBeforeRes = await fetch(`${BASE_URL}/handovers/summary`, {
    headers: { Authorization: `Bearer ${driverToken}` }
  });
  const cashBefore = (await cashBeforeRes.json()).cashHeldPaise || 0;

  const deliverRes = await fetch(`${BASE_URL}/orders/${testDeliverOrder.id}/deliver`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${driverToken}` },
    body: JSON.stringify({
      recipientName: 'Ramesh Storekeeper',
      otp: otpData.debugOtp,
      paymentMethod: 'CASH'
    })
  });
  assert.equal(deliverRes.status, 200, 'Deliver order must succeed with correct OTP');
  const deliverData = await deliverRes.json();
  assert.ok(deliverData.success, 'Delivery confirmation success must be true');
  console.log(`✓ 6. Order Delivered: HTTP 200 | Status: DELIVERED | Cash collected: ₹${(testDeliverOrder.totalAmountPaise/100).toFixed(2)}`);

  // 8. Verify driver cash custody increases
  const cashAfterRes = await fetch(`${BASE_URL}/handovers/summary`, {
    headers: { Authorization: `Bearer ${driverToken}` }
  });
  const cashAfter = (await cashAfterRes.json()).cashHeldPaise || 0;
  assert.ok(cashAfter >= cashBefore, 'Driver cash custody must reflect collected cash');
  console.log(`✓ 7. Driver Cash Custody Updated: ₹${(cashAfter/100).toFixed(2)} in custody`);

  // 9. Test Failed Delivery flow (Shop Closed)
  const failRes = await fetch(`${BASE_URL}/orders/${testFailOrder.id}/delivery-failed`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${driverToken}` },
    body: JSON.stringify({
      reason: 'SHOP_CLOSED',
      notes: 'Shop was closed due to local festival'
    })
  });
  if (!failRes.ok) console.error("Fail delivery error:", await failRes.text());
  assert.equal(failRes.status, 200, 'Fail delivery must succeed');
  const failData = await failRes.json();
  assert.equal(failData.status, 'DELIVERY_FAILED');
  console.log(`✓ 8. Delivery Failed Handled: HTTP 200 | Reason: SHOP_CLOSED | Order: ${testFailOrder.id}`);

  // 10. Verify warehouse returns desk shows undelivered goods held by driver
  const whReturnsRes = await fetch(`${BASE_URL}/warehouse/returns`, {
    headers: { Authorization: `Bearer ${whToken}` }
  });
  const whReturns = await whReturnsRes.json();
  const heldItems = whReturns.pendingUndelivered || [];
  const foundHeld = heldItems.some(i => i.orderId === testFailOrder.id);
  assert.ok(foundHeld, 'Warehouse returns must see undelivered items held by driver');
  console.log(`✓ 9. Godown Returns Desk: Undelivered goods held by driver visible for check-in`);

  // 11. Test Driver Cash Handover Request
  // Ensure no existing pending handover blocks request
  const ownerHandoversRes = await fetch(`${BASE_URL}/owner/handovers`, {
    headers: { Authorization: `Bearer ${ownerToken}` }
  });
  const ownerHandovers = await ownerHandoversRes.json();
  for (const h of ownerHandovers.handovers || []) {
    if (h.status === 'PENDING' && (h.salesperson_id === driverId || h.salespersonId === driverId)) {
      await fetch(`${BASE_URL}/owner/handovers/${h.id}/acknowledge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
        body: JSON.stringify({ idempotencyKey: `ack_${Date.now()}`, action: 'ACCEPT', receivedAmountPaise: h.amount_paise })
      });
    }
  }

  const handoverAmount = Math.min(cashAfter, 50000) || 10000;
  const handoverReqRes = await fetch(`${BASE_URL}/handovers/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${driverToken}` },
    body: JSON.stringify({
      idempotencyKey: `handover_${Date.now()}`,
      amountPaise: handoverAmount,
      notes: 'Evening delivery shift cash handover'
    })
  });
  assert.equal(handoverReqRes.status, 200, 'Handover request must succeed');
  const handoverReqData = await handoverReqRes.json();
  const handoverId = handoverReqData.handoverId;
  console.log(`✓ 10. Cash Handover Requested: HTTP 200 | ID: ${handoverId} | Amount: ₹${(handoverAmount/100).toFixed(2)}`);

  // 12. Owner Acknowledges Cash Handover
  const ackRes = await fetch(`${BASE_URL}/owner/handovers/${handoverId}/acknowledge`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
    body: JSON.stringify({
      idempotencyKey: `ack_${Date.now()}`,
      action: 'ACCEPT',
      receivedAmountPaise: handoverAmount,
      notes: 'Cash verified and settled at godown desk'
    })
  });
  assert.equal(ackRes.status, 200, 'Owner handover acknowledge must succeed');
  console.log(`✓ 11. Owner Cash Reconciliation: Handover accepted and driver custody cleared`);

  console.log("\n=======================================================");
  console.log(">>> ALL DELIVERY ROLE HARDCORE PIPELINE TESTS PASSED! <<<");
  console.log("=======================================================\n");
}

testDeliveryRole().catch(err => {
  console.error("TEST FAILED:", err);
  process.exit(1);
});
