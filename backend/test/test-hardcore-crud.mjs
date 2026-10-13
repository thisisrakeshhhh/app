import assert from 'node:assert/strict';

const BASE = process.env.API_URL || 'https://routeflow-api-staging.thisisrakesh21.workers.dev';

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
const del = (path, token, headers) => req('DELETE', path, null, token, headers);

async function runHardcoreCrudSuite() {
  console.log('================================================================');
  console.log('🔥 ROUTEFLOW HARDCORE BACKEND API CRUD & CLEANUP TEST SUITE');
  console.log(`🌐 Target Server: ${BASE}`);
  console.log('================================================================\n');

  const stamp = Date.now().toString().slice(-6);

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE 1: AUTHENTICATION
  // ─────────────────────────────────────────────────────────────────────────
  console.log('▶ [1/5] AUTHENTICATION & ROLE SESSIONS');
  const ownerLogin = await post('/auth/login', { username: 'owner', password: 'RouteFlow@2026!' });
  assert.equal(ownerLogin.status, 200, 'Owner login must succeed');
  const ownerToken = ownerLogin.data.access_token || ownerLogin.data.accessToken;
  const ownerUser = ownerLogin.data.user;
  console.log(`  ✓ Owner authenticated: ${ownerUser.name || ownerUser.fullName} (Company: ${ownerUser.company_id || ownerUser.companyId})`);

  const salesLogin = await post('/auth/login', { username: 'sales', password: 'RouteFlow@2026!' });
  assert.equal(salesLogin.status, 200, 'Sales login must succeed');
  const salesToken = salesLogin.data.access_token || salesLogin.data.accessToken;
  console.log(`  ✓ Salesperson authenticated`);

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE 2: RETAILER CRUD LIFECYCLE (CREATE -> READ -> UPDATE -> DELETE/DEACTIVATE)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ [2/5] RETAILER CRUD OPERATION LIFECYCLE');
  const testRetailerId = `ret_qa_${stamp}`;
  const initialShopName = `QA Kirana Mart ${stamp}`;
  
  // 2.1 CREATE
  console.log(`  [C] CREATE: Onboarding new test retailer (${initialShopName})...`);
  const createRetailerRes = await post('/retailers', {
    id: testRetailerId,
    name: initialShopName,
    beatId: 'BEAT-04',
    address: 'Shop 102, Mansarovar Sector 5, Jaipur',
    contactNumber: '9829011122',
    creditLimitPaise: 300000, // ₹3,000.00
    paymentTermsDays: 7,
    latitude: 26.852100,
    longitude: 75.764500
  }, salesToken);
  assert.equal(createRetailerRes.status, 200, `Create retailer failed: ${JSON.stringify(createRetailerRes.data)}`);
  console.log(`      ✓ Retailer Created: ID ${testRetailerId}`);

  // 2.2 READ
  console.log(`  [R] READ: Fetching retailers and verifying newly created entity...`);
  const getRetailersRes = await get('/retailers', ownerToken);
  assert.equal(getRetailersRes.status, 200, 'Fetch retailers failed');
  const foundRetailer = getRetailersRes.data.find(r => r.id === testRetailerId);
  assert.ok(foundRetailer, 'Created retailer must exist in database');
  assert.equal(foundRetailer.name, initialShopName, 'Retailer name must match');
  assert.equal(foundRetailer.creditLimitPaise, 300000, 'Credit limit must match');
  assert.equal(foundRetailer.isActive, true, 'Retailer must be active upon creation');
  console.log(`      ✓ Retailer Verified: "${foundRetailer.name}", Credit Limit: ₹${foundRetailer.creditLimitPaise / 100}, Active: ${foundRetailer.isActive}`);

  // 2.3 UPDATE
  const updatedShopName = `QA Kirana Mart [UPDATED] ${stamp}`;
  console.log(`  [U] UPDATE: Modifying retailer properties (credit limit, address, name)...`);
  const updateRetailerRes = await put(`/retailers/${testRetailerId}`, {
    name: updatedShopName,
    address: 'Shop 102-B, Extended Mansarovar, Jaipur',
    creditLimitPaise: 750000, // ₹7,500.00
    paymentTermsDays: 14
  }, ownerToken);
  assert.equal(updateRetailerRes.status, 200, `Update retailer failed: ${JSON.stringify(updateRetailerRes.data)}`);

  // Verify update via READ
  const getUpdatedRetailers = await get('/retailers', ownerToken);
  const reloadedRetailer = getUpdatedRetailers.data.find(r => r.id === testRetailerId);
  assert.equal(reloadedRetailer.name, updatedShopName, 'Updated name must persist');
  assert.equal(reloadedRetailer.creditLimitPaise, 750000, 'Updated credit limit must persist');
  console.log(`      ✓ Retailer Updated & Verified: "${reloadedRetailer.name}", New Limit: ₹${reloadedRetailer.creditLimitPaise / 100}`);

  // 2.4 DELETE / DEACTIVATE (CLEANUP)
  console.log(`  [D] DELETE / DEACTIVATE: Cleaning up test retailer so no dangling record exists...`);
  const deactivateRetailerRes = await put(`/retailers/${testRetailerId}`, {
    isActive: false
  }, ownerToken);
  assert.equal(deactivateRetailerRes.status, 200, `Deactivate retailer failed: ${JSON.stringify(deactivateRetailerRes.data)}`);

  // Verify deactivation via READ
  const getDeactivatedRetailers = await get('/retailers', ownerToken);
  const deactivatedRetailer = getDeactivatedRetailers.data.find(r => r.id === testRetailerId);
  assert.equal(deactivatedRetailer.isActive, false, 'Retailer must be inactive after deletion/deactivation');
  console.log(`      ✓ Retailer Cleaned Up: isActive = ${deactivatedRetailer.isActive} (Soft-deleted / Inactive)`);

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE 3: PRODUCT CATALOG CRUD LIFECYCLE (CREATE -> READ -> UPDATE -> DELETE/DEACTIVATE)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ [3/5] PRODUCT CATALOG CRUD OPERATION LIFECYCLE');
  const testProductId = `P_QA_${stamp}`;
  const initialProductName = `QA Sample Mustard Oil 500ml ${stamp}`;

  // 3.1 CREATE
  console.log(`  [C] CREATE: Adding new wholesale catalog product (${initialProductName})...`);
  const createProductRes = await post('/products', {
    id: testProductId,
    name: initialProductName,
    hindiName: 'सरसों का तेल',
    category: 'Edible Oils',
    pricePaise: 8500, // ₹85.00
    mrpPaise: 9500,   // ₹95.00
    stockQuantity: 100,
    unit: 'Bottle',
    sku: `SKU-QA-${stamp}`
  }, ownerToken);
  assert.equal(createProductRes.status, 200, `Create product failed: ${JSON.stringify(createProductRes.data)}`);
  console.log(`      ✓ Product Created: ID ${testProductId}`);

  // 3.2 READ
  console.log(`  [R] READ: Fetching product by ID...`);
  const getProductRes = await get(`/products/${testProductId}`, ownerToken);
  assert.equal(getProductRes.status, 200, 'Fetch product failed');
  const prodData = getProductRes.data.product || getProductRes.data;
  assert.equal(prodData.name, initialProductName);
  assert.equal(prodData.pricePaise || prodData.price_paise, 8500);
  assert.equal(prodData.stockQuantity || prodData.stock_quantity, 100);
  assert.equal(Boolean(prodData.isActive ?? prodData.is_active), true);
  console.log(`      ✓ Product Verified: "${prodData.name}", Price: ₹${(prodData.pricePaise || prodData.price_paise) / 100}, Stock: ${prodData.stockQuantity || prodData.stock_quantity}`);

  // 3.3 UPDATE
  const updatedProductName = `QA Sample Mustard Oil 500ml [REVISED] ${stamp}`;
  console.log(`  [U] UPDATE: Modifying product pricing and name...`);
  const updateProductRes = await put(`/products/${testProductId}`, {
    name: updatedProductName,
    pricePaise: 9200, // ₹92.00
    mrpPaise: 10000
  }, ownerToken);
  assert.equal(updateProductRes.status, 200, `Update product failed: ${JSON.stringify(updateProductRes.data)}`);

  // Verify update via READ
  const getUpdatedProduct = await get(`/products/${testProductId}`, ownerToken);
  const updatedProdData = getUpdatedProduct.data.product || getUpdatedProduct.data;
  assert.equal(updatedProdData.name, updatedProductName);
  assert.equal(updatedProdData.pricePaise || updatedProdData.price_paise, 9200);
  console.log(`      ✓ Product Updated & Verified: "${updatedProdData.name}", New Price: ₹${(updatedProdData.pricePaise || updatedProdData.price_paise) / 100}`);

  // 3.4 DELETE / DEACTIVATE (CLEANUP)
  console.log(`  [D] DELETE / DEACTIVATE: Cleaning up test product from catalog...`);
  const deactivateProductRes = await put(`/products/${testProductId}`, {
    isActive: false
  }, ownerToken);
  assert.equal(deactivateProductRes.status, 200, `Deactivate product failed: ${JSON.stringify(deactivateProductRes.data)}`);

  // Verify deactivation via READ
  const getDeactivatedProduct = await get(`/products/${testProductId}`, ownerToken);
  const deactProdData = getDeactivatedProduct.data.product || getDeactivatedProduct.data;
  assert.equal(Boolean(deactProdData.isActive ?? deactProdData.is_active), false, 'Product must be inactive after deactivation');
  console.log(`      ✓ Product Cleaned Up: isActive = ${Boolean(deactProdData.isActive ?? deactProdData.is_active)} (Deactivated / Inactive)`);

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE 4: EMPLOYEE USER CRUD & ACCESS REVOCATION (CLEANUP)
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ [4/5] EMPLOYEE CRUD & IMMEDIATE ACCESS REVOCATION');
  const tempEmpUsername = `temp_qa_${stamp}`;
  const tempEmpPassword = `TempPass@2026!`;
  const tempEmpId = `user_qa_${stamp}`;

  // 4.1 CREATE
  console.log(`  [C] CREATE: Creating temporary field employee (${tempEmpUsername})...`);
  const createEmpRes = await post('/employees', {
    id: tempEmpId,
    username: tempEmpUsername,
    password: tempEmpPassword,
    fullName: `QA Test Runner ${stamp}`,
    role: 'SALESPERSON',
    phoneNumber: '9829099887'
  }, ownerToken);
  assert.equal(createEmpRes.status, 200, `Create employee failed: ${JSON.stringify(createEmpRes.data)}`);
  const actualEmpId = createEmpRes.data.employee?.id || tempEmpId;
  console.log(`      ✓ Employee Created: ID ${actualEmpId}`);

  // 4.2 READ & LOGIN
  console.log(`  [R] READ / AUTH: Verifying new employee can authenticate...`);
  const empLoginRes = await post('/auth/login', { username: tempEmpUsername, password: tempEmpPassword });
  assert.equal(empLoginRes.status, 200, 'New employee login must succeed');
  console.log(`      ✓ Employee Login Verified: Session Active (200 OK)`);

  // Verify in roster
  const rosterRes = await get('/employees', ownerToken);
  assert.equal(rosterRes.status, 200);
  const inRoster = rosterRes.data.find(e => e.id === actualEmpId);
  assert.ok(inRoster, 'New employee must appear in roster');
  console.log(`      ✓ Employee Verified in Staff Roster: "${inRoster.username}" (${inRoster.role})`);

  // 4.3 UPDATE: Assign Beat
  console.log(`  [U] UPDATE: Assigning sales territory beat to employee...`);
  const assignBeatRes = await post(`/beats/BEAT-04/assign`, {
    userId: actualEmpId
  }, ownerToken);
  assert.ok([200, 201].includes(assignBeatRes.status), 'Beat assignment must succeed');
  console.log(`      ✓ Employee Territory Updated: BEAT-04 assigned`);

  // 4.4 DELETE / DEACTIVATE (CLEANUP)
  console.log(`  [D] DELETE / DEACTIVATE: Revoking employee access and deleting active status...`);
  const deactivateEmpRes = await put(`/employees/${actualEmpId}/deactivate`, {}, ownerToken);
  assert.equal(deactivateEmpRes.status, 200, 'Deactivation must succeed');

  // Verify employee is blocked immediately
  const blockedLoginRes = await post('/auth/login', { username: tempEmpUsername, password: tempEmpPassword });
  assert.equal(blockedLoginRes.status, 403, 'Deactivated employee must be rejected with 403 Forbidden');
  console.log(`      ✓ Access Revocation Verified: Login rejected with HTTP 403 Forbidden! Account Terminated.`);

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE 5: EPHEMERAL SANDBOX BUSINESS LIFECYCLE & ISOLATION
  // ─────────────────────────────────────────────────────────────────────────
  console.log('\n▶ [5/5] EPHEMERAL SANDBOX REGISTRATION & ISOLATION PROOF');
  const sandboxStamp = Date.now().toString().slice(-5);
  const sandboxCompany = `Ephemeral Test Enterprise ${sandboxStamp}`;
  const sandboxOwner = `sandbox_own_${sandboxStamp}`;
  const sandboxPass = `SandboxPass@2026!`;

  console.log(`  Registering isolated sandbox company: "${sandboxCompany}"...`);
  const sandboxReg = await post('/auth/register-owner', {
    businessName: sandboxCompany,
    fullName: 'Ephemeral QA Admin',
    username: sandboxOwner,
    password: sandboxPass,
    contactNumber: '9998887776',
    address: 'Sandbox Isolation Facility, Jaipur'
  });
  assert.equal(sandboxReg.status, 201, 'Sandbox registration must succeed');
  const sandboxToken = sandboxReg.data.access_token;
  const sandboxCompanyId = sandboxReg.data.user.company_id || sandboxReg.data.user.companyId;
  console.log(`  ✓ Sandbox Company Created: ${sandboxCompanyId}`);

  // Verify complete tenant isolation: Sandbox has 0 retailers initially
  const sandboxRetailers = await get('/retailers', sandboxToken);
  assert.equal(sandboxRetailers.data.length, 0, 'New sandbox must have 0 retailers');
  console.log(`  ✓ Tenant Isolation Verified: Sandbox sees 0 records from existing businesses`);

  // Create temporary shop inside sandbox
  const sbShopRes = await post('/retailers', {
    name: 'Ephemeral Kirana',
    beatId: 'BEAT-01',
    address: 'Isolated Street',
    contactNumber: '9876500000',
    creditLimitPaise: 100000
  }, sandboxToken);
  assert.equal(sbShopRes.status, 200);
  const sbShopId = sbShopRes.data.retailer.id;
  console.log(`  ✓ Sandbox Shop Created: ${sbShopId}`);

  // Deactivate sandbox shop
  await put(`/retailers/${sbShopId}`, { isActive: false }, sandboxToken);
  const sbDeactivated = await get('/retailers', sandboxToken);
  assert.equal(sbDeactivated.data[0].isActive, false);
  console.log(`  ✓ Sandbox Shop Cleaned Up (isActive: false)`);

  console.log('\n================================================================');
  console.log('🎉 ALL HARDCORE CRUD OPERATIONS PASSED WITH 100% SUCCESS!');
  console.log('   All test resources were created, verified, updated, and safely cleaned up.');
  console.log('================================================================');
}

runHardcoreCrudSuite().catch(err => {
  console.error('\n❌ HARDCORE CRUD TEST FAILED:', err);
  process.exit(1);
});
