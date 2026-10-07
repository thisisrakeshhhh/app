import test from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.ROUTEFLOW_TEST_URL || 'http://127.0.0.1:8787';

test('Daily Operating System: Control Room, Day Book, Exceptions, Retailer 360, Cash Control, Purchase & Reports', async (t) => {
  let ownerToken = '';
  let companyId = '';

  await t.test('1. Register Owner for fresh operating business', async () => {
    const username = `own_ops_${Date.now()}`;
    const res = await fetch(`${BASE_URL}/auth/register-owner`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        businessName: 'Jaipur Super Stockists',
        fullName: 'Vikram Singh Shekhawat',
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

  const getHeaders = () => ({
    'Content-Type': 'application/json',
    Authorization: `Bearer ${ownerToken}`,
    'X-Test-Runner': 'true'
  });

  await t.test('2. Onboard initial business structure via wizard', async () => {
    const res = await fetch(`${BASE_URL}/onboarding/wizard-setup`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({
        company: { name: 'Jaipur Super Stockists' },
        beats: [{ id: 'BEAT-OPERATING-01', name: 'Vaishali Nagar Loop' }],
        products: [
          { id: 'p_tea_1', name: 'Taj Mahal Tea 250g', pricePaise: 13000, openingStock: 8, tracksExpiry: true },
          { id: 'p_rice_1', name: 'India Gate Rice 5kg', pricePaise: 50000, openingStock: 4, tracksExpiry: true }
        ],
        retailers: [
          { id: 'r_sharma_1', name: 'Sharma Store', contactNumber: '9829012345', creditLimitPaise: 100000, openingBalancePaise: 85000 }
        ]
      })
    });
    const data = await res.json();
    assert.equal(res.status, 200, JSON.stringify(data));
    assert.equal(data.success, true);
  });

  await t.test('3. Owner Control Room pulse returns live metrics', async () => {
    const res = await fetch(`${BASE_URL}/control-room/pulse`, { headers: getHeaders() });
    const data = await res.json();
    assert.equal(res.status, 200, JSON.stringify(data));
    assert.ok(data.todaySales);
    assert.ok(data.todayCollections);
    assert.ok(data.inventory);
    assert.equal(data.inventory.lowStockCount >= 2, true);
    assert.equal(data.topOverdueRetailers.length >= 1, true);
  });

  await t.test('4. Day Book Morning Opening Checklist Submission', async () => {
    const res = await fetch(`${BASE_URL}/day-book/checklist`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({
        type: 'MORNING_OPENING',
        checklist: {
          pendingOrdersVerified: true,
          packedDispatchesInspected: true,
          lowStockReviewed: true,
          staffAttendanceMarked: true,
          deliveryRoutesReady: true
        },
        notes: 'Morning shift godown ready at 08:30 AM',
        snapshot: { lowStockCount: 2, activeStaffCount: 4 }
      })
    });
    const data = await res.json();
    assert.equal(res.status, 200, JSON.stringify(data));
    assert.equal(data.success, true);
  });

  await t.test('5. Day Book Today endpoint returns completed checklists', async () => {
    const res = await fetch(`${BASE_URL}/day-book/today`, { headers: getHeaders() });
    const data = await res.json();
    assert.equal(res.status, 200, JSON.stringify(data));
    assert.ok(data.morningOpening);
    assert.equal(data.morningOpening.status, 'COMPLETED');
    assert.equal(data.morningOpening.checklist.deliveryRoutesReady, true);
  });

  await t.test('6. Exception Center feed aggregates operational alerts', async () => {
    const res = await fetch(`${BASE_URL}/exceptions/feed`, { headers: getHeaders() });
    const data = await res.json();
    assert.equal(res.status, 200, JSON.stringify(data));
    assert.ok(Array.isArray(data.exceptions));
    assert.equal(data.exceptionsCount > 0, true);
    const overdueAlert = data.exceptions.find(e => e.type === 'OVERDUE_RETAILER');
    assert.ok(overdueAlert);
  });

  await t.test('7. Retailer 360 profile with credit, orders & WhatsApp link', async () => {
    const res = await fetch(`${BASE_URL}/retailers/r_sharma_1/360`, { headers: getHeaders() });
    const data = await res.json();
    assert.equal(res.status, 200, JSON.stringify(data));
    assert.ok(data.retailer);
    assert.equal(data.retailer.name, 'Sharma Store');
    assert.equal(data.retailer.outstandingRupees, '850.00');
    assert.ok(data.whatsappShareUrl);
    assert.equal(data.whatsappShareUrl.includes('wa.me'), true);
  });

  await t.test('8. Cash Control: Record operating expense and query cash book', async () => {
    const expRes = await fetch(`${BASE_URL}/cash-control/expenses`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({
        category: 'FUEL_PETROL',
        amountRupees: '450',
        paymentMode: 'CASH',
        description: 'Van RJ-14 delivery fuel refill',
        vehicleNumber: 'RJ-14-GA-1024'
      })
    });
    const expData = await expRes.json();
    assert.equal(expRes.status, 201, JSON.stringify(expData));
    assert.equal(expData.success, true);

    const bookRes = await fetch(`${BASE_URL}/cash-control/daily-book`, { headers: getHeaders() });
    const bookData = await bookRes.json();
    assert.equal(bookRes.status, 200, JSON.stringify(bookData));
    assert.equal(bookData.summary.expensesPaise, 45000);
  });

  await t.test('9. Purchase Planning: Suggestions for low-stock fast movers', async () => {
    const res = await fetch(`${BASE_URL}/purchase-planning/suggestions`, { headers: getHeaders() });
    const data = await res.json();
    assert.equal(res.status, 200, JSON.stringify(data));
    assert.ok(Array.isArray(data.purchaseList));
    assert.equal(data.reorderCount >= 2, true);
    assert.equal(data.purchaseList[0].suggestedReorderUnits > 0, true);
  });

  await t.test('10. Staff Control: Attendance & Shift summary', async () => {
    const res = await fetch(`${BASE_URL}/staff-control/summary`, { headers: getHeaders() });
    const data = await res.json();
    assert.equal(res.status, 200, JSON.stringify(data));
    assert.ok(Array.isArray(data.staff));
    assert.equal(data.staff.length >= 1, true);
  });

  await t.test('11. Reports: Printable HTML daily closing slip', async () => {
    const res = await fetch(`${BASE_URL}/reports/printable/daily-closing`, { headers: getHeaders() });
    const html = await res.text();
    assert.equal(res.status, 200);
    assert.equal(html.includes('ROUTEFLOW OFFICIAL CLOSING SLIP'), true);
  });
});
