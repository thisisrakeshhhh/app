import assert from 'node:assert/strict';

const WEB_URL = 'https://appdashboardadmin.vercel.app';
const API_URL = 'https://routeflow-api-staging.thisisrakesh21.workers.dev';

async function runWebsiteTests() {
  console.log('================================================================');
  console.log('🌐 ROUTEFLOW WEBSITE & CLIENT-SIDE INTEGRATION TEST SUITE');
  console.log(`🌍 Target Website: ${WEB_URL}`);
  console.log(`⚡ Backend Staging API: ${API_URL}`);
  console.log('================================================================\n');

  // 1. PAGE ACCESSIBILITY & PERFORMANCE AUDIT
  console.log('▶ [1/4] PAGE ROUTING & HTTP HEALTH CHECKS');
  const pages = [
    { path: '/', expectedText: 'RouteFlow' },
    { path: '/login', expectedText: 'Management Console' },
    { path: '/dashboard', expectedText: 'RouteFlow' },
    { path: '/privacy', expectedText: 'RouteFlow' }
  ];

  for (const page of pages) {
    const t0 = Date.now();
    const res = await fetch(`${WEB_URL}${page.path}`);
    const duration = Date.now() - t0;
    assert.equal(res.status, 200, `Page ${page.path} returned status ${res.status}`);
    const html = await res.text();
    assert.ok(html.includes(page.expectedText), `Page ${page.path} missing expected text: ${page.expectedText}`);
    console.log(`  ✓ ${page.path.padEnd(12)} -> HTTP 200 OK (${duration}ms) [Payload: ${html.length} bytes]`);
  }

  // 2. RESPONSIVE DESIGN & VIEWPORT META CHECKS
  console.log('\n▶ [2/4] MOBILE RESPONSIVENESS & META TAG VALIDATION');
  const loginHtml = await (await fetch(`${WEB_URL}/login`)).text();
  assert.ok(loginHtml.includes('viewport'), 'Viewport meta tag must be configured for responsive devices');
  console.log('  ✓ Responsive viewport meta tag confirmed');
  
  // Verify branding & security
  assert.ok(!/zomato|blinkit|airbnb|front warrior|debug otp|test otp/i.test(loginHtml), 'Zero prohibited terms in login HTML');
  console.log('  ✓ Zero prohibited terms / debug OTP leaks in HTML source');

  // 3. AUTHENTICATION FLOWS (CLIENT CREDENTIALS VERIFICATION)
  console.log('\n▶ [3/4] CLIENT AUTHENTICATION FLOW VIA BACKEND API');
  const roles = [
    { username: 'owner', role: 'OWNER', name: 'System Owner' },
    { username: 'sales', role: 'SALESPERSON', name: 'Rakesh Kumar' },
    { username: 'warehouse', role: 'WAREHOUSE_MANAGER', name: 'Manoj Kumar' },
    { username: 'delivery', role: 'DELIVERY_EXECUTIVE', name: 'Suresh Yadav' }
  ];

  for (const r of roles) {
    const res = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: r.username, password: 'RouteFlow@2026!' })
    });
    assert.equal(res.status, 200, `Login for ${r.username} must return 200`);
    const data = await res.json();
    assert.ok(data.access_token || data.accessToken, `Access token missing for ${r.username}`);
    assert.equal(data.user.role, r.role, `Role mismatch for ${r.username}`);
    console.log(`  ✓ Role [${r.role.padEnd(19)}] Authenticated -> User: "${data.user.name || data.user.fullName}"`);
  }

  // Verify bad password rejection
  const badLogin = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'owner', password: 'WrongPassword123!' })
  });
  assert.equal(badLogin.status, 401, 'Bad credentials must be rejected with 401');
  console.log('  ✓ Invalid password safely rejected with HTTP 401 Unauthorized');

  // 4. DATA CONTRACT INTEGRITY FOR WEB CONSOLE
  console.log('\n▶ [4/4] WEB CONSOLE DATA PIPELINES');
  const ownerAuth = await (await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'owner', password: 'RouteFlow@2026!' })
  })).json();
  const token = ownerAuth.access_token || ownerAuth.accessToken;

  // Overview metrics / control room data
  const retailers = await (await fetch(`${API_URL}/retailers`, { headers: { Authorization: `Bearer ${token}` } })).json();
  assert.ok(Array.isArray(retailers), 'Retailers must return an array');
  console.log(`  ✓ Retailer Directory: ${retailers.length} shops registered in beat plan`);

  const products = await (await fetch(`${API_URL}/products`, { headers: { Authorization: `Bearer ${token}` } })).json();
  const productList = products.products || products;
  assert.ok(Array.isArray(productList), 'Products must return an array');
  console.log(`  ✓ Product Catalog: ${productList.length} active wholesale inventory SKUs`);

  const orders = await (await fetch(`${API_URL}/orders`, { headers: { Authorization: `Bearer ${token}` } })).json();
  const orderList = orders.orders || orders;
  assert.ok(Array.isArray(orderList), 'Orders must return an array');
  console.log(`  ✓ Live Orders Feed: ${orderList.length} orders processed in system`);

  const handovers = await (await fetch(`${API_URL}/cash-handovers`, { headers: { Authorization: `Bearer ${token}` } })).json();
  const handoverList = handovers.handovers || handovers;
  assert.ok(Array.isArray(handoverList), 'Cash handovers must return an array');
  console.log(`  ✓ Cash Reconciliation: ${handoverList.length} driver depot handovers logged`);

  console.log('\n================================================================');
  console.log('🎉 WEBSITE & INTEGRATION AUDIT COMPLETED WITH 100% SUCCESS!');
  console.log('================================================================');
}

runWebsiteTests().catch(err => {
  console.error('\n❌ WEBSITE TEST FAILED:', err);
  process.exit(1);
});
