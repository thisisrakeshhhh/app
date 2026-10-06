import test from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.ROUTEFLOW_TEST_URL || 'http://127.0.0.1:8787';

test('Production Governance, Onboarding Wizard, Permissions, Audit, CSV Export, GRN and Payments', async (t) => {
  let ownerToken = '';
  let companyId = '';
  let supplierId = '';
  let testProductId = '';

  // 1. Register Owner
  await t.test('1. Register Owner for fresh business', async () => {
    const username = `own_gov_${Date.now()}`;
    const res = await fetch(`${BASE_URL}/auth/register-owner`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        businessName: 'Rajasthan Provisions Hub',
        fullName: 'Shyam Sundar',
        username,
        password: 'RouteFlow@2026!Secure'
      })
    });
    assert.equal(res.status, 201, 'Owner registration succeeded');
    const data = await res.json();
    assert.ok(data.access_token, 'Access token returned');
    ownerToken = data.access_token;
    companyId = data.user.company_id;
  });

  // 2. Company Onboarding Wizard
  await t.test('2. Company Onboarding Wizard (Multi-entity setup)', async () => {
    const res = await fetch(`${BASE_URL}/onboarding/wizard-setup`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${ownerToken}`,
        'X-Device-Id': 'web-console-test'
      },
      body: JSON.stringify({
        company: { name: 'Rajasthan Provisions Hub Pvt Ltd' },
        beats: [
          { name: 'Tonk Road Beat', code: 'TONK', area: 'Tonk Road, Jaipur' },
          { name: 'C-Scheme Beat', code: 'CSCH', area: 'C-Scheme, Jaipur' }
        ],
        employees: [
          { username: `sales_tonk_${Date.now()}`, fullName: 'Ramesh Sharma', role: 'SALESPERSON', phone: '9829012345' },
          { username: `wh_tonk_${Date.now()}`, fullName: 'Mukesh Godown', role: 'WAREHOUSE_MANAGER', phone: '9829054321' },
          { username: `del_tonk_${Date.now()}`, fullName: 'Sohan Van', role: 'DELIVERY_EXECUTIVE', phone: '9829098765' }
        ],
        products: [
          { name: 'Fortune Mustard Oil 1L', sku: 'OIL-FORT-1L', pricePaise: 14500, openingStock: 120, unit: 'Bottle', category: 'Oils' },
          { name: 'India Gate Basmati Rice 5kg', sku: 'RICE-IG-5K', pricePaise: 52000, openingStock: 60, unit: 'Bag', category: 'Grains' }
        ],
        retailers: [
          { name: 'Khandelwal Kirana', contactNumber: '9414011111', address: 'Tonk Phatak, Jaipur', creditLimitPaise: 1000000, openingBalancePaise: 250000 },
          { name: 'Pink City Mart', contactNumber: '9414022222', address: 'Bapu Nagar, Jaipur', creditLimitPaise: 1500000, openingBalancePaise: 0 }
        ]
      })
    });
    assert.equal(res.status, 200, 'Wizard setup succeeded');
    const data = await res.json();
    assert.equal(data.success, true);
  });

  // 3. Role Permissions Management
  await t.test('3. Role Permissions: Read & Update', async () => {
    const getRes = await fetch(`${BASE_URL}/permissions`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(getRes.status, 200);
    const getData = await getRes.json();
    assert.ok(Array.isArray(getData.permissions), 'Permissions list returned');

    // Update Salesperson permissions: allow up to 8% discount
    const putRes = await fetch(`${BASE_URL}/permissions`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${ownerToken}`
      },
      body: JSON.stringify({
        role: 'SALESPERSON',
        canApproveOrders: false,
        canEditStock: false,
        canGiveDiscount: true,
        canReversePayment: false,
        maxDiscountPct: 8.0
      })
    });
    assert.equal(putRes.status, 200);
    const putData = await putRes.json();
    assert.equal(putData.success, true);
  });

  // 4. Audit Log Querying
  await t.test('4. Full Audit Log Querying', async () => {
    const res = await fetch(`${BASE_URL}/audit-logs?limit=10`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data.auditLogs), 'Audit logs array returned');
    assert.ok(data.auditLogs.length >= 2, 'Audit logs recorded for onboarding and permissions');
    const actions = data.auditLogs.map(l => l.action);
    assert.ok(actions.includes('ONBOARDING_WIZARD_COMPLETED') || actions.includes('PERMISSIONS_UPDATED'));
  });

  // 5. CSV Exports & Full Backup
  await t.test('5. CSV Exports & Full JSON Backup', async () => {
    const prodRes = await fetch(`${BASE_URL}/export/products`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(prodRes.status, 200);
    assert.equal(prodRes.headers.get('Content-Type')?.includes('text/csv'), true);
    const prodCsv = await prodRes.text();
    assert.ok(prodCsv.includes('Fortune Mustard Oil 1L'), 'Product CSV contains product');

    const retRes = await fetch(`${BASE_URL}/export/retailers`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(retRes.status, 200);
    const retCsv = await retRes.text();
    assert.ok(retCsv.includes('Khandelwal Kirana'), 'Retailer CSV contains retailer');

    const backupRes = await fetch(`${BASE_URL}/export/backup-json`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(backupRes.status, 200);
    const backupData = await backupRes.json();
    assert.equal(backupData.companyId, companyId);
    assert.ok(Array.isArray(backupData.products));
    assert.ok(Array.isArray(backupData.retailers));
  });

  // 6. Suppliers & GRN Inward Stock Workflow
  await t.test('6. Suppliers & GRN Inward Stock Lifecycle', async () => {
    // 6.1 Create Supplier
    const supRes = await fetch(`${BASE_URL}/suppliers`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${ownerToken}`
      },
      body: JSON.stringify({
        name: 'Adani Wilmar Depot Jaipur',
        contactNumber: '01412345678',
        gstin: '08AAAAA0000A1Z5',
        city: 'Jaipur'
      })
    });
    assert.equal(supRes.status, 201);
    const supData = await supRes.json();
    supplierId = supData.supplier.id;

    // Get a product id
    const productsRes = await fetch(`${BASE_URL}/products`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const products = await productsRes.json();
    const oilProduct = products.find(p => p.sku === 'OIL-FORT-1L');
    assert.ok(oilProduct, 'Found oil product');
    testProductId = oilProduct.id;
    const initialStock = oilProduct.stockQuantity;

    // 6.2 Create GRN
    const grnRes = await fetch(`${BASE_URL}/grn`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${ownerToken}`
      },
      body: JSON.stringify({
        supplierId,
        invoiceNumber: 'INV-ADANI-2026-99',
        items: [
          {
            productId: testProductId,
            batchNo: 'BATCH-OIL-OCT26',
            quantityReceived: 50,
            unitCostPaise: 13000,
            rackBin: 'Rack-A1'
          }
        ]
      })
    });
    assert.equal(grnRes.status, 201);
    const grnData = await grnRes.json();
    const grnId = grnData.grn.id;

    // 6.3 Approve GRN (Stock must increment by 50)
    const appRes = await fetch(`${BASE_URL}/grn/${grnId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(appRes.status, 200);

    // Verify stock incremented
    const updatedProductsRes = await fetch(`${BASE_URL}/products`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    const updatedProducts = await updatedProductsRes.json();
    const updatedOil = updatedProducts.find(p => p.id === testProductId);
    assert.equal(updatedOil.stockQuantity, initialStock + 50, 'Physical godown stock atomically incremented');
  });
});
