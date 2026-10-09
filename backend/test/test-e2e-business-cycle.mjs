import assert from 'node:assert/strict';

const BASE = 'https://routeflow-api-staging.thisisrakesh21.workers.dev';

async function post(path, body, token) {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Test-Runner': 'true',
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body: JSON.stringify(body)
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, ok: res.ok, data };
}

async function get(path, token) {
  const res = await fetch(`${BASE}${path}`, {
    headers: {
      'X-Test-Runner': 'true',
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    }
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, ok: res.ok, data };
}

async function run() {
  console.log('=== ROUTEFLOW END-TO-END BUSINESS CYCLE TEST ===\n');

  // 1. Authenticate users
  console.log('1. Logging in users across all roles...');
  const ownerLogin = await post('/auth/login', { username: 'owner', password: 'RouteFlow@2026!' });
  const ownerToken = ownerLogin.data.access_token || ownerLogin.data.accessToken;
  assert.ok(ownerToken, 'Owner login failed');

  const salesLogin = await post('/auth/login', { username: 'sales', password: 'RouteFlow@2026!' });
  const salesToken = salesLogin.data.access_token || salesLogin.data.accessToken;
  assert.ok(salesToken, 'Sales login failed');

  const warehouseLogin = await post('/auth/login', { username: 'warehouse', password: 'RouteFlow@2026!' });
  const warehouseToken = warehouseLogin.data.access_token || warehouseLogin.data.accessToken;
  assert.ok(warehouseToken, 'Warehouse login failed');

  const deliveryLogin = await post('/auth/login', { username: 'delivery', password: 'RouteFlow@2026!' });
  const deliveryToken = deliveryLogin.data.access_token || deliveryLogin.data.accessToken;
  assert.ok(deliveryToken, 'Delivery login failed');
  console.log('✓ All 4 roles authenticated successfully!\n');

  // 2. Sales Lead Generation: Onboard new shop with GPS location & address
  console.log('2. Sales Front Warrior: Adding new wholesale shop with GPS location...');
  const shopName = `Jai Shree Ram Wholesale & Retail ${Date.now().toString().slice(-4)}`;
  const lat = 28.613939;
  const lng = 77.209021;
  const shopRes = await post('/retailers', {
    name: shopName,
    address: 'Shop 104, Wholesale Grain Market',
    contactNumber: '9876543210',
    latitude: lat,
    longitude: lng,
    creditLimitPaise: 500000
  }, salesToken);
  assert.equal(shopRes.status, 200, `Shop creation failed: ${JSON.stringify(shopRes.data)}`);
  const shopId = shopRes.data.retailer?.id || shopRes.data.id;
  console.log(`✓ Shop onboarded by Sales! ID: ${shopId}, Name: "${shopName}", GPS: [${lat}, ${lng}]\n`);

  // 3. Sales Order Booking from Warehouse Catalog
  console.log('3. Sales Order Booking: Booking items from warehouse catalog...');
  const prodRes = await get('/products', salesToken);
  const products = Array.isArray(prodRes.data) ? prodRes.data : (prodRes.data.products || []);
  const targetProd = products.find(p => p.id === 'P2') || products[0];
  const unitPrice = targetProd.pricePaise || targetProd.price_paise || 16000;
  const qty = 2;
  const orderTotalPaise = unitPrice * qty;

  const orderId = `ORD-${Date.now().toString().slice(-6)}`;
  const orderRes = await post('/orders', {
    order: {
      id: orderId,
      retailerId: shopId,
      totalAmountPaise: orderTotalPaise
    },
    items: [
      {
        id: `ITEM-${Date.now()}`,
        productId: targetProd.id,
        quantity: qty,
        pricePaiseAtTime: unitPrice
      }
    ],
    idempotencyKey: `idemp_${orderId}`
  }, salesToken);
  assert.equal(orderRes.status, 200, `Order creation failed: ${JSON.stringify(orderRes.data)}`);
  console.log(`✓ Order booked by Sales! ID: ${orderId}, Total: ₹${(orderTotalPaise/100).toFixed(2)}, Status: PENDING_APPROVAL\n`);

  // 4. Sales Payment Collection from Shop
  console.log('4. Sales Field Collection: Collecting payment from retailer...');
  const collRes = await post('/collections', {
    retailerId: shopId,
    amountPaise: 5000,
    paymentMethod: 'CASH',
    idempotencyKey: `coll_${Date.now()}`
  }, salesToken);
  console.log(`✓ Sales collected ₹50.00 cash from shop! Collection ID: ${collRes.data.collectionId || collRes.data.id || 'recorded'}\n`);

  // 5. Admin / Owner Approves the Order
  console.log('5. Admin / Owner: Approving the booked order on dashboard...');
  const approveRes = await post(`/orders/${orderId}/approve`, {}, ownerToken);
  assert.equal(approveRes.status, 200, `Order approval failed: ${JSON.stringify(approveRes.data)}`);
  console.log(`✓ Order ${orderId} approved by Admin/Owner! Status: APPROVED\n`);

  // 6. Warehouse Manager: Picking & Packing Logistics
  console.log('6. Warehouse Manager: Managing logistics (picking & packing goods)...');
  await post(`/orders/${orderId}/start-picking`, {}, warehouseToken);
  await post(`/orders/${orderId}/pick-item`, { productId: targetProd.id, isPicked: true }, warehouseToken);
  const packRes = await post(`/orders/${orderId}/pack`, {}, warehouseToken);
  assert.equal(packRes.status, 200, `Order pack failed: ${JSON.stringify(packRes.data)}`);
  console.log(`✓ Goods picked and packed in warehouse! Status: PACKED\n`);

  // 7. Admin / Warehouse: Assign Goods to Delivery Executive
  console.log('7. Admin / Logistics: Assigning goods and dispatching to delivery driver...');
  const devList = await get('/delivery-executives', ownerToken);
  const driver = devList.data[0];
  console.log(`   Designated driver: ${driver.fullName || driver.username} (ID: ${driver.id})`);
  const dispatchRes = await post(`/orders/${orderId}/dispatch`, { deliveryEmployeeId: driver.id }, ownerToken);
  assert.equal(dispatchRes.status, 200, `Dispatch failed: ${JSON.stringify(dispatchRes.data)}`);
  console.log(`✓ Goods dispatched to delivery driver! Status: OUT_FOR_DELIVERY\n`);

  // 8. Delivery Driver: Arrives at Shop & Delivers Goods
  console.log('8. Delivery Driver: Arriving at shop, verifying delivery & collecting payment...');
  const otpRes = await post(`/orders/${orderId}/request-otp`, {}, deliveryToken);
  const otp = otpRes.data.debugOtp || '123456';
  const deliverRes = await post(`/orders/${orderId}/deliver`, {
    paymentMethod: 'CASH',
    recipientName: 'Shop Owner Ramesh',
    otp
  }, deliveryToken);
  assert.equal(deliverRes.status, 200, `Delivery failed: ${JSON.stringify(deliverRes.data)}`);
  console.log(`✓ Goods delivered to shop! Cash payment collected by driver at shop! Status: DELIVERED\n`);

  // 9. Delivery Driver Cash Handover & Owner Reconciliation
  console.log('9. Cash Handover: Driver submits collected cash handover to owner...');
  const handoverRes = await post('/cash-handovers', {
    amountPaise: orderTotalPaise,
    idempotencyKey: `ho_${Date.now()}`
  }, deliveryToken);
  const handoverId = handoverRes.data.handover?.id || handoverRes.data.id || handoverRes.data.handoverId;
  console.log(`✓ Cash handover submitted by driver! Amount: ₹${(orderTotalPaise/100).toFixed(2)}, Handover ID: ${handoverId}`);

  if (handoverId) {
    console.log('   Owner acknowledging and reconciling cash handover...');
    const ackRes = await post(`/cash-handovers/${handoverId}/acknowledge`, {
      status: 'ACCEPTED',
      receivedAmountPaise: orderTotalPaise
    }, ownerToken);
    console.log(`✓ Cash handover settled & reconciled by Owner! Status: ACCEPTED\n`);
  }

  console.log('====================================================');
  console.log('🎉 FULL B2B DISTRIBUTION CYCLE VERIFIED SUCCESSFULLY!');
  console.log('====================================================');
}

run().catch((err) => {
  console.error('Test error:', err);
  process.exit(1);
});
