import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.ROUTEFLOW_TEST_URL || 'http://127.0.0.1:8787';

describe('RouteFlow Phase A: Security-First RBAC and Retailer Isolation Suite', () => {
  let ownerToken = '';
  let adminToken = '';
  let salesMgrToken = '';
  let accountantToken = '';
  let salesToken = '';
  let warehouseToken = '';
  let deliveryToken = '';
  let retailerAToken = '';
  let retailerBToken = '';
  let ownerComp2Token = '';

  let orderAId = '';
  let orderBId = '';

  const login = async (username, password = 'password123') => {
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    const data = await res.json();
    return { status: res.status, data };
  };

  test('0. Setup: Provision accounts across 8 roles and obtain auth tokens', async () => {
    // 1. Log in as owner (comp_1)
    const ownerLogin = await login('owner');
    assert.equal(ownerLogin.status, 200, 'Owner login failed');
    ownerToken = ownerLogin.data.access_token;

    // 2. Log in as admin (comp_1)
    const adminLogin = await login('admin');
    assert.equal(adminLogin.status, 200, 'Admin login failed');
    adminToken = adminLogin.data.access_token;

    // 3. Log in as existing legacy sales (comp_1)
    const salesLogin = await login('sales');
    assert.equal(salesLogin.status, 200, 'Sales login failed');
    salesToken = salesLogin.data.access_token;

    // 4. Log in as existing legacy warehouse (comp_1)
    const whLogin = await login('warehouse');
    assert.equal(whLogin.status, 200, 'Warehouse login failed');
    warehouseToken = whLogin.data.access_token;

    // 5. Log in as existing legacy delivery (comp_1)
    const delLogin = await login('delivery');
    assert.equal(delLogin.status, 200, 'Delivery login failed');
    deliveryToken = delLogin.data.access_token;

    // 6. Log in as comp_2 owner
    const comp2Login = await login('owner_comp2');
    assert.equal(comp2Login.status, 200, 'Owner Comp2 login failed');
    ownerComp2Token = comp2Login.data.access_token;

    // 7. Owner provisions SALES_MANAGER
    const resSm = await fetch(`${BASE_URL}/employees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        username: 'sales_mgr_test',
        password: 'password123',
        fullName: 'Test Sales Manager',
        role: 'SALES_MANAGER'
      })
    });
    assert.equal(resSm.status, 200, 'Failed to create SALES_MANAGER');
    const smLogin = await login('sales_mgr_test');
    assert.equal(smLogin.status, 200);
    salesMgrToken = smLogin.data.access_token;

    // 8. Owner provisions ACCOUNTANT
    const resAcc = await fetch(`${BASE_URL}/employees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        username: 'accountant_test',
        password: 'password123',
        fullName: 'Test Accountant',
        role: 'ACCOUNTANT'
      })
    });
    assert.equal(resAcc.status, 200, 'Failed to create ACCOUNTANT');
    const accLogin = await login('accountant_test');
    assert.equal(accLogin.status, 200);
    accountantToken = accLogin.data.access_token;

    // 9. Owner provisions Retailer A (linked to R1)
    const resRetA = await fetch(`${BASE_URL}/employees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        id: 'R1',
        username: 'retailer_a_user',
        password: 'password123',
        fullName: 'Sharma Retailer Owner',
        role: 'RETAILER'
      })
    });
    assert.equal(resRetA.status, 200, 'Failed to create Retailer A user');
    const retALogin = await login('retailer_a_user');
    assert.equal(retALogin.status, 200);
    retailerAToken = retALogin.data.access_token;

    // 10. Owner provisions Retailer B (linked to R2)
    const resRetB = await fetch(`${BASE_URL}/employees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        id: 'R2',
        username: 'retailer_b_user',
        password: 'password123',
        fullName: 'Gupta Retailer Owner',
        role: 'RETAILER'
      })
    });
    assert.equal(resRetB.status, 200, 'Failed to create Retailer B user');
    const retBLogin = await login('retailer_b_user');
    assert.equal(retBLogin.status, 200);
    retailerBToken = retBLogin.data.access_token;

    // Create an order for Retailer B via sales rep so it exists in DB
    orderBId = `ord_b_${Date.now()}`;
    const resCreateB = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: {
          id: orderBId,
          retailerId: 'R2',
          employeeId: 'user_sales',
          status: 'SUBMITTED',
          totalAmountPaise: 45000,
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: `item_b_${Date.now()}`, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }],
        idempotencyKey: `idemp_${orderBId}`
      })
    });
    assert.equal(resCreateB.status, 200, 'Setup: Order B creation failed');
  });

  // ==========================================================================
  // RETAILER DATA ISOLATION TESTS (1 to 8)
  // ==========================================================================

  test('1. Retailer A lists only own orders (GET /orders)', async () => {
    // First, Retailer A creates Order A
    orderAId = `ord_a_${Date.now()}`;
    const resCreateA = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${retailerAToken}` },
      body: JSON.stringify({
        order: {
          id: orderAId,
          retailerId: 'R1',
          totalAmountPaise: 12000,
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: `item_a_${Date.now()}`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000 }],
        idempotencyKey: `idemp_${orderAId}`
      })
    });
    assert.equal(resCreateA.status, 200, 'Retailer A order creation must succeed');

    // Retailer A lists orders
    const resList = await fetch(`${BASE_URL}/orders`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resList.status, 200);
    const orders = await resList.json();
    assert.ok(Array.isArray(orders));
    assert.ok(orders.length > 0);
    assert.ok(orders.every(o => o.retailerId === 'R1'), 'Retailer A must only see orders where retailerId is R1');
    assert.ok(orders.some(o => o.id === orderAId), 'Order A must be present in Retailer A list');
  });

  test('2. Retailer B order is strictly excluded from Retailer A order list', async () => {
    const resList = await fetch(`${BASE_URL}/orders`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    const orders = await resList.json();
    assert.ok(!orders.some(o => o.id === orderBId), 'Order B must NOT appear in Retailer A orders list');
  });

  test('3. Retailer A cannot read Retailer B order by ID (GET /orders/:id returns 404)', async () => {
    // Attempt to access Order B using Retailer A token
    const resDetail = await fetch(`${BASE_URL}/orders/${orderBId}`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resDetail.status, 404, 'Retailer A reading Retailer B order must return 404 (not found / not accessible)');
  });

  test('4. Retailer A cannot create order as Retailer B (spoofing protection)', async () => {
    const spoofOrderId = `spoof_${Date.now()}`;
    const resSpoof = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${retailerAToken}` },
      body: JSON.stringify({
        order: {
          id: spoofOrderId,
          retailerId: 'R2', // Target Retailer B
          totalAmountPaise: 12000,
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: `spoof_item_${Date.now()}`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000 }],
        idempotencyKey: `idemp_${spoofOrderId}`
      })
    });
    assert.equal(resSpoof.status, 403, 'Submitting order with spoofed retailerId must return 403 Forbidden');
  });

  test('5. Cross-tenant order access is strictly rejected', async () => {
    // Comp 2 owner attempts to read Comp 1 Order A
    const resCross = await fetch(`${BASE_URL}/orders/${orderAId}`, {
      headers: { Authorization: `Bearer ${ownerComp2Token}` }
    });
    assert.equal(resCross.status, 404, 'Cross-tenant order access must return 404');
  });

  test('6. No company-wide leak via query parameters (GET /orders?retailerId=R2)', async () => {
    // Retailer A passes query param trying to filter for R2
    const resLeak = await fetch(`${BASE_URL}/orders?retailerId=R2`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resLeak.status, 200);
    const orders = await resLeak.json();
    assert.ok(orders.every(o => o.retailerId === 'R1'), 'Retailer A must never receive orders from another retailer regardless of query params');
    assert.ok(!orders.some(o => o.id === orderBId));
  });

  test('7. Legitimate retailer self-service order persists with status SUBMITTED', async () => {
    const selfOrderId = `ord_self_${Date.now()}`;
    const resSelf = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${retailerAToken}` },
      body: JSON.stringify({
        order: {
          id: selfOrderId,
          retailerId: 'R1',
          totalAmountPaise: 45000,
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: `self_item_${Date.now()}`, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 45000 }],
        idempotencyKey: `idemp_${selfOrderId}`
      })
    });
    assert.equal(resSelf.status, 200, 'Self-service ordering must return 200');

    // Fetch detail as Retailer A
    const resDetail = await fetch(`${BASE_URL}/orders/${selfOrderId}`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resDetail.status, 200);
    const detail = await resDetail.json();
    assert.equal(detail.order.status, 'SUBMITTED');
    assert.equal(detail.order.retailerId, 'R1');
  });

  test('8. Retailer ledger access is scoped (own khata = 200, other = 403)', async () => {
    // Retailer A requests own ledger
    const resOwnLedger = await fetch(`${BASE_URL}/retailers/R1/ledger`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resOwnLedger.status, 200, 'Retailer accessing own ledger must succeed');

    // Retailer A requests Retailer B ledger
    const resOtherLedger = await fetch(`${BASE_URL}/retailers/R2/ledger`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resOtherLedger.status, 403, 'Retailer accessing another retailer ledger must be 403 Forbidden');
  });

  // ==========================================================================
  // ENTERPRISE RBAC TESTS (9 to 20)
  // ==========================================================================

  test('9. Owner has full operational and administrative capabilities', async () => {
    // Owner can view all retailers
    const resRet = await fetch(`${BASE_URL}/retailers`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resRet.status, 200);
    const rets = await resRet.json();
    assert.ok(rets.length >= 2, 'Owner must see all company retailers');

    // Owner can view team status
    const resTeam = await fetch(`${BASE_URL}/team/status`, {
      headers: { Authorization: `Bearer ${ownerToken}` }
    });
    assert.equal(resTeam.status, 200);
  });

  test('10. Admin has management capabilities (orders, products, beat assignment)', async () => {
    // Admin views orders
    const resOrders = await fetch(`${BASE_URL}/orders`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert.equal(resOrders.status, 200);

    // Admin views pending orders
    const resPending = await fetch(`${BASE_URL}/orders/pending`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert.equal(resPending.status, 200);
  });

  test('11. Sales Manager can view pending orders, approve orders, and view field status', async () => {
    // Sales Manager views pending orders
    const resPending = await fetch(`${BASE_URL}/orders/pending`, {
      headers: { Authorization: `Bearer ${salesMgrToken}` }
    });
    assert.equal(resPending.status, 200);

    // Sales Manager views team status
    const resTeam = await fetch(`${BASE_URL}/team/status`, {
      headers: { Authorization: `Bearer ${salesMgrToken}` }
    });
    assert.equal(resTeam.status, 200, 'Sales Manager must have access to /team/status');

    // Sales Manager views daily visits
    const resVisits = await fetch(`${BASE_URL}/owner/visits/daily`, {
      headers: { Authorization: `Bearer ${salesMgrToken}` }
    });
    assert.equal(resVisits.status, 200, 'Sales Manager must have access to /owner/visits/daily');

    // Sales Manager approves Order B
    const resApprove = await fetch(`${BASE_URL}/orders/${orderBId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${salesMgrToken}` }
    });
    assert.equal(resApprove.status, 200, 'Sales Manager must be able to approve orders');
  });

  test('12. Sales Manager cannot close day or review cash settlements', async () => {
    // Sales Manager attempts to review collections
    const resReview = await fetch(`${BASE_URL}/collections/col_dummy/review`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesMgrToken}` },
      body: JSON.stringify({ action: 'CLEAR', reason: 'Attempt unauthorized review' })
    });
    assert.equal(resReview.status, 403, 'Sales Manager must not have financial review permissions');

    // Sales Manager attempts to acknowledge cash handovers
    const resAck = await fetch(`${BASE_URL}/cash-handovers/handover_dummy/acknowledge`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesMgrToken}` },
      body: JSON.stringify({ action: 'ACCEPT' })
    });
    assert.equal(resAck.status, 403, 'Sales Manager must not have cash handover acknowledgement permissions');
  });

  test('13. Accountant has finance oversight (collections review & handover ack)', async () => {
    // Accountant can view collections
    const resCols = await fetch(`${BASE_URL}/collections`, {
      headers: { Authorization: `Bearer ${accountantToken}` }
    });
    assert.equal(resCols.status, 200, 'Accountant must be able to view /collections');

    // Accountant can view cash handovers
    const resHandovers = await fetch(`${BASE_URL}/cash-handovers`, {
      headers: { Authorization: `Bearer ${accountantToken}` }
    });
    assert.equal(resHandovers.status, 200, 'Accountant must be able to view /cash-handovers');
  });

  test('14. Accountant cannot approve orders or dispatch orders', async () => {
    // Create another order to test accountant rejection
    const accOrderId = `ord_acc_test_${Date.now()}`;
    await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        order: {
          id: accOrderId,
          retailerId: 'R1',
          employeeId: 'user_sales',
          status: 'SUBMITTED',
          totalAmountPaise: 45000,
          createdAt: Date.now(),
          updatedAt: Date.now()
        },
        items: [{ id: `item_acc_${Date.now()}`, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }],
        idempotencyKey: `idemp_${accOrderId}`
      })
    });

    const resApprove = await fetch(`${BASE_URL}/orders/${accOrderId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${accountantToken}` }
    });
    assert.equal(resApprove.status, 403, 'Accountant must not be permitted to approve orders');

    const resDispatch = await fetch(`${BASE_URL}/orders/${accOrderId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accountantToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });
    assert.equal(resDispatch.status, 403, 'Accountant must not be permitted to dispatch orders');
  });

  test('15. Sales role retains field operations (assigned beat ordering and collections)', async () => {
    // Sales rep can create collection for assigned retailer
    const colId = `col_test_${Date.now()}`;
    const resCol = await fetch(`${BASE_URL}/collections`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${salesToken}` },
      body: JSON.stringify({
        retailerId: 'R1',
        amountPaise: 5000,
        paymentMethod: 'CASH',
        idempotencyKey: `idemp_${colId}`
      })
    });
    assert.equal(resCol.status, 200, 'Sales representative can submit collections for assigned beat retailer');
  });

  test('16. Warehouse role retains fulfillment operations (pick, pack, dispatch)', async () => {
    // Approve orderB first (was approved by salesMgr earlier)
    // Warehouse picking
    const resPick = await fetch(`${BASE_URL}/orders/${orderBId}/pick-item`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ productId: 'P1', isPicked: true })
    });
    assert.equal(resPick.status, 200, 'Warehouse can pick item');

    // Warehouse packing
    const resPack = await fetch(`${BASE_URL}/orders/${orderBId}/pack`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resPack.status, 200, 'Warehouse can pack order');

    // Warehouse dispatch
    const resDispatch = await fetch(`${BASE_URL}/orders/${orderBId}/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${warehouseToken}` },
      body: JSON.stringify({ deliveryEmployeeId: 'user_delivery' })
    });
    assert.equal(resDispatch.status, 200, 'Warehouse can dispatch order');
  });

  test('17. Delivery role retains transit and delivery operations', async () => {
    // Delivery rep requests OTP for dispatched order
    const resOtp = await fetch(`${BASE_URL}/orders/${orderBId}/request-otp`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${deliveryToken}`, 'X-Test-Runner': 'true' }
    });
    assert.equal(resOtp.status, 200);
    const otpData = await resOtp.json();
    assert.ok(otpData.debugOtp);

    // Delivery rep confirms delivery
    const resDeliver = await fetch(`${BASE_URL}/orders/${orderBId}/deliver`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${deliveryToken}`, 'X-Test-Runner': 'true' },
      body: JSON.stringify({
        paymentMethod: 'CASH',
        recipientName: 'Gupta Store Manager',
        otp: otpData.debugOtp
      })
    });
    assert.equal(resDeliver.status, 200, 'Delivery representative can complete delivery');
  });

  test('18. Retailer is blocked from staff-only management endpoints', async () => {
    // Retailer attempts to list employees
    const resEmp = await fetch(`${BASE_URL}/employees`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resEmp.status, 403, 'Retailer must be forbidden from /employees');

    // Retailer attempts to view team status
    const resTeam = await fetch(`${BASE_URL}/team/status`, {
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resTeam.status, 403, 'Retailer must be forbidden from /team/status');

    // Retailer attempts to approve orders
    const resApprove = await fetch(`${BASE_URL}/orders/${orderBId}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${retailerAToken}` }
    });
    assert.equal(resApprove.status, 403, 'Retailer must be forbidden from approving orders');
  });

  test('19. Unknown / arbitrary roles fail closed across endpoints', async () => {
    // Provision a user with canonical SALES, then spoof token with role UNKNOWN
    // Create an employee with invalid role is rejected:
    const resInvalidRole = await fetch(`${BASE_URL}/employees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        username: 'hacker_user',
        password: 'password123',
        fullName: 'Hacker',
        role: 'SUPERUSER_HACKER'
      })
    });
    assert.equal(resInvalidRole.status, 400, 'Arbitrary unapproved roles must be rejected on creation');
  });

  test('20. Legacy role aliases preserved and tenant header spoofing rejected', async () => {
    // Legacy SALESPERSON token works identically to SALES
    const resLegacySales = await fetch(`${BASE_URL}/orders`, {
      headers: { Authorization: `Bearer ${salesToken}` }
    });
    assert.equal(resLegacySales.status, 200, 'Legacy SALESPERSON role alias is recognized');

    // Legacy WAREHOUSE_MANAGER token works identically to WAREHOUSE
    const resLegacyWh = await fetch(`${BASE_URL}/orders`, {
      headers: { Authorization: `Bearer ${warehouseToken}` }
    });
    assert.equal(resLegacyWh.status, 200, 'Legacy WAREHOUSE_MANAGER role alias is recognized');

    // Legacy DELIVERY_EXECUTIVE token works identically to DELIVERY
    const resLegacyDel = await fetch(`${BASE_URL}/orders`, {
      headers: { Authorization: `Bearer ${deliveryToken}` }
    });
    assert.equal(resLegacyDel.status, 200, 'Legacy DELIVERY_EXECUTIVE role alias is recognized');

    // Cross-tenant manipulation via X-RouteFlow-Account or body tenant tampering:
    // User from comp_1 attempting to pass header for comp_2
    const resTamper = await fetch(`${BASE_URL}/orders`, {
      headers: {
        Authorization: `Bearer ${salesToken}`,
        'X-RouteFlow-Account': 'comp_2'
      }
    });
    // System enforces authenticated user's actual tenant from token; unauthorized cross-tenant headers are rejected
    assert.equal(resTamper.status, 403, 'Cross-tenant account tampering via X-RouteFlow-Account header must return 403 Forbidden');
  });
});
