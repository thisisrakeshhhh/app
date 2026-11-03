import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.ROUTEFLOW_TEST_URL || 'http://127.0.0.1:8787';

describe('RouteFlow Phase C: Real Cloudflare D1 Sync Endpoints & Integrity Suite', () => {
  let ownerToken = '';
  let salesToken = '';
  let warehouseToken = '';
  let comp2OwnerToken = '';

  const login = async (username, password = 'password123') => {
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    const data = await res.json();
    return { status: res.status, data };
  };

  test('0. Setup: Authenticate accounts across roles', async () => {
    const ownerRes = await login('owner');
    assert.equal(ownerRes.status, 200);
    ownerToken = ownerRes.data.access_token;

    const salesRes = await login('sales');
    assert.equal(salesRes.status, 200);
    salesToken = salesRes.data.access_token;

    const whRes = await login('warehouse');
    assert.equal(whRes.status, 200);
    warehouseToken = whRes.data.access_token;

    const comp2Res = await login('owner_comp2');
    assert.equal(comp2Res.status, 200);
    comp2OwnerToken = comp2Res.data.access_token;
  });

  test('1. Tenant Boundary: Reject mismatched organizationId and userId', async () => {
    // Attempt to push as comp_1 user with comp_2 organizationId
    const res = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_cross_tenant_01',
        organizationId: 'comp_2',
        mutations: [
          {
            mutationId: 'mut_test_01',
            idempotencyKey: 'idem_cross_tenant',
            mutationType: 'CREATE_RETAILER',
            payload: { shopName: 'Rogue Shop', phone: '9829001122' }
          }
        ]
      })
    });
    assert.equal(res.status, 403, 'Should reject mismatched organizationId with 403');
    const json = await res.json();
    assert.equal(json.error, 'TENANT_MISMATCH');
  });

  test('2. Server RBAC: Salesperson can create shop with class NEW and credit limit 0', async () => {
    const idemKey = `idem_sales_shop_${Date.now()}`;
    const res = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_sales_shop_01',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_sales_shop_01',
            sequenceOrder: 1,
            idempotencyKey: idemKey,
            mutationType: 'CREATE_RETAILER',
            provisionalBusinessId: 'LOCAL-SHP-101',
            payload: {
              shopName: 'Shri Ram Kirana',
              ownerName: 'Ram Lal',
              phone: '9829011111',
              classification: 'NEW',
              defaultCreditLimitPaise: 0,
              route: 'BEAT-04'
            }
          }
        ]
      })
    });
    assert.equal(res.status, 200, 'Salesperson should create NEW shop');
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.processedCount, 1);
    assert.equal(json.results[0].status, 'COMMITTED');
    assert.ok(json.results[0].serverBusinessId.startsWith('ret_'));
  });

  test('3. Server RBAC: Salesperson cannot set non-NEW class or non-zero credit limit', async () => {
    // Attempt to set Class A
    const resA = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_sales_illegal_class',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_illegal_01',
            idempotencyKey: `idem_illegal_a_${Date.now()}`,
            mutationType: 'CREATE_RETAILER',
            payload: {
              shopName: 'Illegal Class Shop',
              phone: '9829022222',
              classification: 'Class A',
              defaultCreditLimitPaise: 0
            }
          }
        ]
      })
    });
    assert.equal(resA.status, 403, 'Should reject Class A setting by salesperson');
    const jsonA = await resA.json();
    assert.equal(jsonA.error, 'FORBIDDEN_ROLE_ACTION');

    // Attempt to set credit limit > 0
    const resB = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_sales_illegal_credit',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_illegal_02',
            idempotencyKey: `idem_illegal_b_${Date.now()}`,
            mutationType: 'CREATE_RETAILER',
            payload: {
              shopName: 'Illegal Credit Shop',
              phone: '9829033333',
              classification: 'NEW',
              defaultCreditLimitPaise: 5000000
            }
          }
        ]
      })
    });
    assert.equal(resB.status, 403, 'Should reject non-zero credit limit by salesperson');
  });

  test('4. Server RBAC: Role segregation for GRN, Class Settings, and Orders', async () => {
    // Salesperson cannot push GRN
    const resGrn = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_sales_grn',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_sales_grn',
            idempotencyKey: `idem_sales_grn_${Date.now()}`,
            mutationType: 'RECEIVE_GRN',
            payload: { items: [{ productId: 'prod_1', piecesReceived: 50 }] }
          }
        ]
      })
    });
    assert.equal(resGrn.status, 403, 'Salesperson must not receive GRN');

    // Warehouse cannot create order
    const resWhOrder = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${warehouseToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_wh_order',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_wh_order',
            idempotencyKey: `idem_wh_order_${Date.now()}`,
            mutationType: 'CREATE_ORDER',
            payload: { retailerId: 'ret_1', items: [{ productId: 'prod_1', orderedQuantity: 2 }] }
          }
        ]
      })
    });
    assert.equal(resWhOrder.status, 403, 'Warehouse must not create order');

    // Warehouse can receive GRN
    const resWhGrn = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${warehouseToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_wh_grn_ok',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_wh_grn_ok',
            idempotencyKey: `idem_wh_grn_${Date.now()}`,
            mutationType: 'RECEIVE_GRN',
            payload: { items: [{ productId: 'prod_1', piecesReceived: 100 }] }
          }
        ]
      })
    });
    assert.equal(resWhGrn.status, 200, 'Warehouse should receive GRN');
  });

  test('5. Idempotency Guard: Replay returns cached result; Mismatched payload returns 409 Conflict', async () => {
    const idemKey = `idem_guard_test_${Date.now()}`;
    const initialPayload = {
      shopName: 'Idem Store',
      phone: '9829044444',
      classification: 'NEW',
      defaultCreditLimitPaise: 0
    };

    // First push -> 200 OK
    const res1 = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_idem_1',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_idem_01',
            idempotencyKey: idemKey,
            mutationType: 'CREATE_RETAILER',
            payload: initialPayload
          }
        ]
      })
    });
    assert.equal(res1.status, 200);
    const json1 = await res1.json();
    const serverId = json1.results[0].serverBusinessId;
    const serverSeq = json1.results[0].serverSequence;

    // Second push (Exact replay) -> 200 OK with cached: true
    const res2 = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_idem_2',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_idem_01_retry',
            idempotencyKey: idemKey,
            mutationType: 'CREATE_RETAILER',
            payload: initialPayload
          }
        ]
      })
    });
    assert.equal(res2.status, 200);
    const json2 = await res2.json();
    assert.equal(json2.results[0].cached, true);
    assert.equal(json2.results[0].serverBusinessId, serverId);
    assert.equal(json2.results[0].serverSequence, serverSeq);

    // Third push (Payload mismatch on same key) -> 409 Conflict
    const res3 = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_idem_3',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_idem_01_tampered',
            idempotencyKey: idemKey,
            mutationType: 'CREATE_RETAILER',
            payload: { ...initialPayload, shopName: 'Altered Store Name' }
          }
        ]
      })
    });
    assert.equal(res3.status, 409, 'Should reject payload mismatch with 409');
    const json3 = await res3.json();
    assert.equal(json3.error, 'IDEMPOTENCY_PAYLOAD_MISMATCH');
  });

  test('6. Server Recalculation & Overselling Protection on Order Push', async () => {
    // 1. Overselling protection: Request 99999 units of prod_1
    const resOversell = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_oversell',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_order_oversell',
            idempotencyKey: `idem_oversell_${Date.now()}`,
            mutationType: 'CREATE_ORDER',
            payload: {
              retailerId: 'ret_1',
              items: [
                {
                  productId: 'prod_1',
                  orderedQuantity: 99999,
                  unitPricePaise: 5000
                }
              ]
            }
          }
        ]
      })
    });
    assert.equal(resOversell.status, 400, 'Should reject overselling with 400');
    const jsonOversell = await resOversell.json();
    assert.equal(jsonOversell.error, 'INSUFFICIENT_STOCK');

    // 2. Legitimate order with client total mismatch: server recalculates and commits
    const resOrder = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_valid_order',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: 'mut_valid_order',
            sequenceOrder: 10,
            idempotencyKey: `idem_order_valid_${Date.now()}`,
            mutationType: 'CREATE_ORDER',
            provisionalBusinessId: 'LOCAL-ORD-501',
            payload: {
              retailerId: 'ret_1',
              items: [
                {
                  productId: 'prod_1', // price_paise = 5000 in seeds
                  orderedQuantity: 2,
                  gstRate: 5.0
                }
              ],
              totals: {
                totalAmountPaise: 999999 // intentionally bogus client total
              }
            }
          }
        ]
      })
    });
    assert.equal(resOrder.status, 200);
    const jsonOrder = await resOrder.json();
    assert.equal(jsonOrder.results[0].status, 'COMMITTED');
    // Expected server calculation: 2 * 5000 = 10000 paise
    const totals = jsonOrder.results[0].serverCalculatedTotals;
    assert.equal(totals.totalAmountPaise, 10000);
    assert.ok(totals.taxableAmountPaise > 0);
    assert.ok(totals.gstAmountPaise > 0);
  });

  test('7. Delta Pull: POST /sync/pull retrieves catalog and order updates', async () => {
    const res = await fetch(`${BASE_URL}/sync/pull`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        organizationId: 'comp_1',
        lastServerSequence: 0,
        limit: 50
      })
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.ok(Array.isArray(json.delta.products));
    assert.ok(json.delta.products.length > 0, 'Products should not be empty');
    assert.ok(Array.isArray(json.delta.classSettings));
    assert.ok(Array.isArray(json.delta.orderStatusUpdates));
  });
});
