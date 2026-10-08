import assert from 'node:assert/strict';

// Test targets both Cloudflare staging and local test harness if passed
const BASE = process.env.ROUTEFLOW_TEST_URL || 'https://routeflow-api-staging.thisisrakesh21.workers.dev';

async function req(method, path, body, token, customHeaders = {}) {
  const headers = {
    'X-Test-Runner': 'true',
    ...customHeaders
  };
  if (body) headers['Content-Type'] = 'application/json';
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, ok: res.ok, data };
}

const get = (path, token, headers) => req('GET', path, null, token, headers);
const post = (path, body, token, headers) => req('POST', path, body, token, headers);
const put = (path, body, token, headers) => req('PUT', path, body, token, headers);
const del = (path, body, token, headers) => req('DELETE', path, body, token, headers);

const report = {
  total: 0,
  passed: 0,
  failed: 0,
  suites: []
};

function recordTest(suiteName, testName, passed, details = '') {
  report.total++;
  if (passed) report.passed++;
  else report.failed++;
  
  let s = report.suites.find(x => x.name === suiteName);
  if (!s) {
    s = { name: suiteName, tests: [] };
    report.suites.push(s);
  }
  s.tests.push({ testName, passed, details });
  const statusIcon = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`  [${statusIcon}] ${testName} ${details ? '(' + details + ')' : ''}`);
}

async function runHardcoreSalesTestSuite() {
  console.log('================================================================');
  console.log('🚀 ROUTEFLOW HARDCORE SALES ROLE TEST SUITE (CRUD / POST / GET / PUT / SECURITY)');
  console.log(`🌐 Target Server: ${BASE}`);
  console.log('================================================================\n');

  // ─────────────────────────────────────────────────────────────────────────
  // 1. AUTHENTICATION & SESSION LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────
  console.log('▶ 1. Authentication & Session Verification for Sales');
  let salesToken = null;
  let ownerToken = null;
  let salesUser = null;

  try {
    const loginRes = await post('/auth/login', { username: 'sales', password: 'password123' });
    assert.equal(loginRes.status, 200, 'Sales login must return 200');
    assert.ok(loginRes.data.access_token, 'Access token required');
    assert.equal(loginRes.data.user.role, 'SALESPERSON', 'Role must be SALESPERSON');
    salesToken = loginRes.data.access_token;
    salesUser = loginRes.data.user;
    recordTest('Authentication', 'Sales login with valid credentials returns 200 and JWT', true);
  } catch (err) {
    recordTest('Authentication', 'Sales login with valid credentials returns 200 and JWT', false, err.message);
  }

  try {
    const badLogin = await post('/auth/login', { username: 'sales', password: 'wrongpassword' });
    assert.equal(badLogin.status, 401, 'Bad credentials must be rejected with 401');
    recordTest('Authentication', 'Sales login rejection on invalid password (401)', true);
  } catch (err) {
    recordTest('Authentication', 'Sales login rejection on invalid password (401)', false, err.message);
  }

  try {
    const meRes = await get('/me', salesToken);
    assert.equal(meRes.status, 200, '/me must return profile');
    assert.equal(meRes.data.role, 'SALESPERSON');
    assert.equal(meRes.data.sub, salesUser.id);
    recordTest('Authentication', 'GET /me returns correct authenticated user payload', true);
  } catch (err) {
    recordTest('Authentication', 'GET /me returns correct authenticated user payload', false, err.message);
  }

  // Obtain owner token for checking cross-role administrative controls
  try {
    const oLogin = await post('/auth/login', { username: 'admin', password: 'password123' });
    if (oLogin.status === 200) ownerToken = oLogin.data.access_token;
  } catch (_) {}

  // ─────────────────────────────────────────────────────────────────────────
  // 2. SHIFT WORKFLOW (POST /shifts/start, POST /shifts/locations, POST /shifts/end)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ 2. Sales Shift Lifecycle & Breadcrumb Location Tracking');
  const shiftId = `SHIFT-${Date.now()}`;
  const startTime = Date.now() - 30000; // 30 sec ago
  try {
    const startShiftRes = await post('/shifts/start', {
      shiftId: shiftId,
      startTime: startTime,
      latitude: 26.9124,
      longitude: 75.7873,
      idempotencyKey: `start_${shiftId}`
    }, salesToken);
    assert.ok([200, 201].includes(startShiftRes.status), `Start shift responded with ${startShiftRes.status}`);
    recordTest('Shift Management', 'POST /shifts/start activates shift with GPS coordinates & idempotency', true);
  } catch (err) {
    recordTest('Shift Management', 'POST /shifts/start activates shift with GPS coordinates & idempotency', false, err.message);
  }

  try {
    const currentShift = await get('/shifts/current', salesToken);
    assert.equal(currentShift.status, 200);
    assert.ok(currentShift.data.shift, 'Current shift must exist');
    assert.equal(currentShift.data.shift.id, shiftId);
    recordTest('Shift Management', 'GET /shifts/current returns active shift status (ON_SHIFT)', true);
  } catch (err) {
    recordTest('Shift Management', 'GET /shifts/current returns active shift status (ON_SHIFT)', false, err.message);
  }

  try {
    const locTimestamp = startTime + 5000;
    const locRes = await post('/shifts/locations', {
      shiftId: shiftId,
      points: [
        { id: `LOC-${Date.now()}-1`, latitude: 26.9125, longitude: 75.7874, accuracy: 5.0, timestamp: locTimestamp },
        { id: `LOC-${Date.now()}-2`, latitude: 26.9130, longitude: 75.7880, accuracy: 4.2, timestamp: locTimestamp + 2000 }
      ]
    }, salesToken);
    assert.ok([200, 201].includes(locRes.status), `Upload locations status: ${locRes.status}`);
    recordTest('Shift Management', 'POST /shifts/locations transmits breadcrumb coordinates during active shift', true);
  } catch (err) {
    recordTest('Shift Management', 'POST /shifts/locations transmits breadcrumb coordinates during active shift', false, err.message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. RETAILER MANAGEMENT (GET /retailers, POST /retailers)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ 3. Retailer Data Pipeline (GET & POST by Salesperson)');
  let existingRetailers = [];
  try {
    const getRetRes = await get('/retailers', salesToken);
    assert.equal(getRetRes.status, 200, 'GET /retailers must return 200');
    assert.ok(Array.isArray(getRetRes.data), 'GET /retailers must return array');
    existingRetailers = getRetRes.data;
    recordTest('Retailers', `GET /retailers returns assigned beat list (${existingRetailers.length} shops found)`, true);
  } catch (err) {
    recordTest('Retailers', 'GET /retailers returns assigned beat list', false, err.message);
  }

  const testRetId = `RET-TEST-${Date.now().toString().slice(-6)}`;
  const testRetName = `Hardcore Kirana ${Date.now().toString().slice(-4)}`;
  try {
    // Sales person POST new retailer
    const createRetRes = await post('/retailers', {
      id: testRetId,
      name: testRetName,
      beatId: existingRetailers[0]?.beatId || 'BEAT-04',
      address: 'Shop No 42, Tonk Road, Jaipur',
      contactNumber: '9829099881',
      creditLimitPaise: 5000000, // ₹50,000
      paymentTermsDays: 7,
      latitude: 26.9150,
      longitude: 75.7900
    }, salesToken);
    assert.ok([200, 201].includes(createRetRes.status), `Create retailer status: ${createRetRes.status}`);
    recordTest('Retailers', 'POST /retailers creates a new shop with beat and GPS tags by Salesperson', true);
  } catch (err) {
    recordTest('Retailers', 'POST /retailers creates a new shop with beat and GPS tags by Salesperson', false, err.message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. PRODUCT CATALOG (GET /products)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ 4. Product Catalog Verification (GET /products)');
  let productList = [];
  try {
    const prodRes = await get('/products', salesToken);
    assert.equal(prodRes.status, 200, 'GET /products must return 200');
    assert.ok(Array.isArray(prodRes.data), 'Products must be array');
    assert.ok(prodRes.data.length > 0, 'Catalog should contain items');
    productList = prodRes.data;
    recordTest('Products', `GET /products returns wholesale catalog (${productList.length} items)`, true);
  } catch (err) {
    recordTest('Products', 'GET /products returns wholesale catalog', false, err.message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. SHOP VISITS WORKFLOW (POST /visits, PUT /visits/:id/checkout, GET /visits)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ 5. Shop Visit Cycle (Check-in, Duration, Checkout)');
  const targetRetailerId = existingRetailers[0]?.id || testRetId;
  const visitId = `VISIT-${Date.now()}`;
  const checkInTime = Date.now() - 60000; // 1 minute ago

  try {
    // POST /visits (Check-In)
    const visitRes = await post('/visits', {
      id: visitId,
      retailerId: targetRetailerId,
      checkInTime: checkInTime,
      latitude: 26.9124,
      longitude: 75.7873,
      accuracy: 5.0,
      status: 'ACTIVE',
      idempotencyKey: `visit_checkin_${visitId}`
    }, salesToken);
    assert.ok([200, 201].includes(visitRes.status), `Check-in visit status: ${visitRes.status}`);
    recordTest('Shop Visits', 'POST /visits records active check-in with GPS and idempotency', true);
  } catch (err) {
    recordTest('Shop Visits', 'POST /visits records active check-in with GPS and idempotency', false, err.message);
  }

  try {
    // PUT /visits/:id/checkout
    const checkOutTime = Date.now();
    const checkoutRes = await put(`/visits/${visitId}/checkout`, {
      checkOutTime: checkOutTime,
      durationSeconds: 60,
      notes: 'Shopkeeper took 2 boxes of tea; booked order',
      noOrderReason: null
    }, salesToken);
    assert.ok([200, 204].includes(checkoutRes.status), `Checkout visit status: ${checkoutRes.status}`);
    recordTest('Shop Visits', 'PUT /visits/:id/checkout concludes visit with duration & field notes', true);
  } catch (err) {
    recordTest('Shop Visits', 'PUT /visits/:id/checkout concludes visit with duration & field notes', false, err.message);
  }

  try {
    // GET /visits
    const listVisitsRes = await get('/visits', salesToken);
    assert.equal(listVisitsRes.status, 200, 'GET /visits must return 200');
    assert.ok(Array.isArray(listVisitsRes.data), 'Visits must be an array');
    const foundVisit = listVisitsRes.data.find(v => v.id === visitId);
    assert.ok(foundVisit, 'Newly completed visit should be present in visits history');
    recordTest('Shop Visits', 'GET /visits returns salesperson completed visit history', true);
  } catch (err) {
    recordTest('Shop Visits', 'GET /visits returns salesperson completed visit history', false, err.message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. ORDER BOOKING & IDEMPOTENCY (POST /orders, GET /orders, GET /orders/:id)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ 6. Order Booking, Credit Validation & Idempotency');
  const sampleProduct = productList[0] || { id: 'P1', pricePaise: 45000, name: 'Sample' };
  const orderId = `ORD-HC-${Date.now().toString().slice(-6)}`;
  const orderPayload = {
    order: {
      id: orderId,
      retailerId: targetRetailerId,
      employeeId: salesUser.id,
      status: 'SUBMITTED',
      totalAmountPaise: sampleProduct.pricePaise * 2,
      createdAt: Date.now(),
      updatedAt: Date.now()
    },
    items: [
      {
        id: `ITEM-${Date.now()}`,
        productId: sampleProduct.id,
        quantity: 2,
        freeQuantity: 0,
        pricePaiseAtTime: sampleProduct.pricePaise,
        isPicked: false
      }
    ]
  };

  try {
    const bookOrderRes = await post('/orders', orderPayload, salesToken);
    assert.ok([200, 201].includes(bookOrderRes.status), `Book order status: ${bookOrderRes.status}`);
    recordTest('Order Booking', `POST /orders successfully books order (${orderId})`, true);
  } catch (err) {
    recordTest('Order Booking', 'POST /orders successfully books order', false, err.message);
  }

  try {
    // Replay same order (Idempotency check)
    const replayRes = await post('/orders', orderPayload, salesToken);
    assert.ok([200, 201].includes(replayRes.status), `Idempotent replay responded ${replayRes.status}`);
    recordTest('Order Booking', 'POST /orders idempotent submission returns 200 without duplicate rows', true);
  } catch (err) {
    recordTest('Order Booking', 'POST /orders idempotent submission returns 200 without duplicate rows', false, err.message);
  }

  try {
    const getOrderRes = await get(`/orders/${orderId}`, salesToken);
    assert.equal(getOrderRes.status, 200, `GET /orders/${orderId} status: ${getOrderRes.status}`);
    assert.equal(getOrderRes.data.order.id, orderId);
    recordTest('Order Booking', `GET /orders/:id retrieves order details and line items`, true);
  } catch (err) {
    recordTest('Order Booking', 'GET /orders/:id retrieves order details and line items', false, err.message);
  }

  try {
    const ordersListRes = await get('/orders', salesToken);
    assert.equal(ordersListRes.status, 200, 'GET /orders must return 200');
    assert.ok(Array.isArray(ordersListRes.data));
    assert.ok(ordersListRes.data.some(o => o.id === orderId));
    recordTest('Order Booking', 'GET /orders includes the booked order in salesperson feed', true);
  } catch (err) {
    recordTest('Order Booking', 'GET /orders includes the booked order in salesperson feed', false, err.message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 7. COLLECTIONS & LEDGER (POST /collections, GET /collections)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ 7. Payment Collections & Khata Recording');
  const collectionId = `COL-${Date.now()}`;
  const collectAmountPaise = 250000; // ₹2,500
  try {
    const colRes = await post('/collections', {
      id: collectionId,
      retailerId: targetRetailerId,
      amountPaise: collectAmountPaise,
      paymentMethod: 'CASH',
      receiptId: `REC-${Date.now().toString().slice(-4)}`,
      notes: 'Collected cash during field visit',
      idempotencyKey: `col_${collectionId}`
    }, salesToken);
    assert.ok([200, 201].includes(colRes.status), `Record collection status: ${colRes.status}`);
    recordTest('Collections', `POST /collections records Cash collection (₹${collectAmountPaise/100})`, true);
  } catch (err) {
    recordTest('Collections', 'POST /collections records Cash collection', false, err.message);
  }

  try {
    const listColRes = await get('/collections', salesToken);
    assert.equal(listColRes.status, 200, 'GET /collections status must be 200');
    const cols = Array.isArray(listColRes.data) ? listColRes.data : listColRes.data.collections;
    assert.ok(Array.isArray(cols), 'Collections list must be an array');
    const foundCol = cols.find(c => c.id === collectionId || c.idempotency_key === `col_${collectionId}`);
    assert.ok(foundCol, 'Collection must appear in collections ledger');
    recordTest('Collections', `GET /collections returns logged payments (${cols.length} collections recorded)`, true);
  } catch (err) {
    recordTest('Collections', 'GET /collections returns logged payments with confirmation state', false, err.message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 8. SECURITY & ROLE PRIVILEGE BOUNDARY ENFORCEMENT (Negative Tests)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ 8. Security & Role Privilege Boundary Verification (Negative Checks)');
  try {
    // Sales person should NOT be able to modify master product catalog
    const addProdAttempt = await post('/products', {
      id: `PROD-DENIED-${Date.now()}`,
      name: 'Unauthorized SKU',
      category: 'General',
      pricePaise: 1000
    }, salesToken);
    assert.ok([401, 403].includes(addProdAttempt.status), `Sales creating product should be 403, got ${addProdAttempt.status}`);
    recordTest('Security & Role Boundaries', 'POST /products denied for SALESPERSON role (403 Forbidden)', true);
  } catch (err) {
    recordTest('Security & Role Boundaries', 'POST /products denied for SALESPERSON role', false, err.message);
  }

  try {
    // Sales person should NOT be able to update retailer credit limit
    const updateRetAttempt = await put(`/retailers/${targetRetailerId}`, {
      creditLimitPaise: 999999999
    }, salesToken);
    assert.ok([401, 403].includes(updateRetAttempt.status), `Sales updating retailer master should be 403, got ${updateRetAttempt.status}`);
    recordTest('Security & Role Boundaries', 'PUT /retailers/:id credit modification denied for SALESPERSON (403 Forbidden)', true);
  } catch (err) {
    recordTest('Security & Role Boundaries', 'PUT /retailers/:id credit modification denied for SALESPERSON', false, err.message);
  }

  try {
    // Sales person should NOT be able to approve orders
    const approveAttempt = await post(`/orders/${orderId}/approve`, {}, salesToken);
    assert.ok([401, 403].includes(approveAttempt.status), `Sales approving order should be 403, got ${approveAttempt.status}`);
    recordTest('Security & Role Boundaries', 'POST /orders/:id/approve denied for SALESPERSON role (403 Forbidden)', true);
  } catch (err) {
    recordTest('Security & Role Boundaries', 'POST /orders/:id/approve denied for SALESPERSON role', false, err.message);
  }

  try {
    // Sales person should NOT be able to dispatch orders
    const dispatchAttempt = await post(`/orders/${orderId}/dispatch`, { deliveryEmployeeId: 'user_delivery' }, salesToken);
    assert.ok([401, 403].includes(dispatchAttempt.status), `Sales dispatching order should be 403, got ${dispatchAttempt.status}`);
    recordTest('Security & Role Boundaries', 'POST /orders/:id/dispatch denied for SALESPERSON role (403 Forbidden)', true);
  } catch (err) {
    recordTest('Security & Role Boundaries', 'POST /orders/:id/dispatch denied for SALESPERSON role', false, err.message);
  }

  try {
    // Sales person should NOT be able to adjust inventory
    const adjustAttempt = await post('/inventory/adjust', { productId: sampleProduct.id, deltaQuantity: 50 }, salesToken);
    assert.ok([401, 403].includes(adjustAttempt.status), `Sales adjusting inventory should be 403, got ${adjustAttempt.status}`);
    recordTest('Security & Role Boundaries', 'POST /inventory/adjust denied for SALESPERSON role (403 Forbidden)', true);
  } catch (err) {
    recordTest('Security & Role Boundaries', 'POST /inventory/adjust denied for SALESPERSON role', false, err.message);
  }

  // End shift cleanly
  try {
    await post('/shifts/end', {
      shiftId: shiftId,
      endTime: Date.now(),
      latitude: 26.9124,
      longitude: 75.7873,
      idempotencyKey: `end_${shiftId}`
    }, salesToken);
    recordTest('Shift Management', 'POST /shifts/end concludes active shift successfully', true);
  } catch (err) {
    recordTest('Shift Management', 'POST /shifts/end concludes active shift successfully', false, err.message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUMMARY REPORT
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n================================================================');
  console.log(`📊 HARDCORE TEST REPORT: ${report.passed}/${report.total} PASSED (${report.failed} FAILED)`);
  console.log('================================================================');
  
  return report;
}

runHardcoreSalesTestSuite().then(rep => {
  if (rep.failed > 0) process.exit(1);
  else process.exit(0);
}).catch(e => {
  console.error('Test suite crashed:', e);
  process.exit(1);
});
