import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.ROUTEFLOW_TEST_URL || 'http://127.0.0.1:8787';

describe('RouteFlow Hardcore Stress, Concurrency & Security Penetration Suite', () => {
  let ownerToken = '';
  let salesToken = '';
  let whToken = '';
  let comp2OwnerToken = '';
  let sharedRetailerId = '';
  let sharedProductId = '';

  const login = async (username, password = 'password123') => {
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    const data = await res.json();
    return { status: res.status, data };
  };

  test('0. Setup: Authenticate accounts across roles and tenants', async () => {
    const ownerRes = await login('owner');
    assert.equal(ownerRes.status, 200);
    ownerToken = ownerRes.data.access_token;

    const salesRes = await login('sales');
    assert.equal(salesRes.status, 200);
    salesToken = salesRes.data.access_token;

    const whRes = await login('warehouse');
    assert.equal(whRes.status, 200);
    whToken = whRes.data.access_token;

    const comp2Res = await login('owner_comp2');
    assert.equal(comp2Res.status, 200);
    comp2OwnerToken = comp2Res.data.access_token;

    // Create a base retailer for test assertions
    const retRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${ownerToken}`
      },
      body: JSON.stringify({
        clientBatchId: `batch_setup_ret_${Date.now()}`,
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_setup_ret_${Date.now()}`,
            idempotencyKey: `idem_setup_ret_${Date.now()}`,
            mutationType: 'CREATE_RETAILER',
            payload: {
              shopName: 'Shared Test Kirana',
              phone: '9829001234',
              classification: 'CLASS_A',
              defaultCreditLimitPaise: 5000000
            }
          }
        ]
      })
    });
    assert.equal(retRes.status, 200);
    const retData = await retRes.json();
    sharedRetailerId = retData.results[0].serverBusinessId;
    assert.ok(sharedRetailerId, 'Shared retailer must be created');

    // Create a base product
    const prodRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${ownerToken}`
      },
      body: JSON.stringify({
        clientBatchId: `batch_setup_prod_${Date.now()}`,
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_setup_prod_${Date.now()}`,
            idempotencyKey: `idem_setup_prod_${Date.now()}`,
            mutationType: 'CREATE_PRODUCT',
            payload: {
              sku: `SETUP_${Date.now()}`,
              name: 'Shared Setup Product',
              pricePaise: 5000,
              initialStockPieces: 200
            }
          }
        ]
      })
    });
    assert.equal(prodRes.status, 200);
    const prodData = await prodRes.json();
    sharedProductId = prodData.results[0].serverBusinessId;
    assert.ok(sharedProductId, 'Shared product must be created');
  });

  test('1. Multi-Client Concurrency Race: 10 concurrent orders competing for last 5 pieces', async () => {
    // 1. Owner creates a dedicated test product with stock = 5, reserved = 0
    const prodCode = `STRESS_CONC_${Date.now()}`;
    const createProdRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${ownerToken}`
      },
      body: JSON.stringify({
        clientBatchId: `batch_create_${prodCode}`,
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_prod_${prodCode}`,
            idempotencyKey: `idem_prod_${prodCode}`,
            mutationType: 'CREATE_PRODUCT',
            payload: {
              sku: prodCode,
              name: 'Finite Stock Energy Drink',
              pricePaise: 5000,
              initialStockPieces: 5
            }
          }
        ]
      })
    });
    assert.equal(createProdRes.status, 200);
    const createProdData = await createProdRes.json();
    const productId = createProdData.results[0].serverBusinessId;
    assert.ok(productId, 'Product must be created');

    // 2. Fire 10 simultaneous orders at the exact same millisecond, each ordering 1 piece
    const orderPromises = Array.from({ length: 10 }).map((_, idx) => {
      const mutId = `mut_conc_ord_${prodCode}_${idx}`;
      return fetch(`${BASE_URL}/sync/push`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${salesToken}`
        },
        body: JSON.stringify({
          clientBatchId: `batch_conc_${prodCode}_${idx}`,
          organizationId: 'comp_1',
          mutations: [
            {
              mutationId: mutId,
              idempotencyKey: `idem_conc_${prodCode}_${idx}`,
              mutationType: 'CREATE_ORDER',
              payload: {
                retailerId: sharedRetailerId,
                items: [
                  {
                    productId,
                    orderedQuantity: 1,
                    orderedUnit: 'piece',
                    unitPricePaise: 5000
                  }
                ]
              }
            }
          ]
        })
      }).then(async res => ({ status: res.status, body: await res.json() }));
    });

    const responses = await Promise.all(orderPromises);

    // Exactly 5 must succeed with 200 COMMITTED, and 5 must fail with 400 INSUFFICIENT_STOCK
    const successCount = responses.filter(r => r.status === 200 && r.body.results?.[0]?.status === 'COMMITTED').length;
    const rejectedCount = responses.filter(r => r.status === 400 && r.body.error === 'INSUFFICIENT_STOCK').length;

    assert.equal(successCount, 5, `Expected exactly 5 successful orders, got ${successCount}`);
    assert.equal(rejectedCount, 5, `Expected exactly 5 rejected orders due to stock exhaustion, got ${rejectedCount}`);

    // Verify eleventh order is strictly rejected as well
    const eleventhRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: `batch_eleventh_${prodCode}`,
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_eleventh_${prodCode}`,
            idempotencyKey: `idem_eleventh_${prodCode}`,
            mutationType: 'CREATE_ORDER',
            payload: {
              retailerId: sharedRetailerId,
              items: [{ productId, orderedQuantity: 1, orderedUnit: 'piece', unitPricePaise: 5000 }]
            }
          }
        ]
      })
    });
    assert.equal(eleventhRes.status, 400);
    const eleventhBody = await eleventhRes.json();
    assert.equal(eleventhBody.error, 'INSUFFICIENT_STOCK');
  });

  test('2. High-Concurrency Idempotency Storm: 20 simultaneous identical pushes', async () => {
    // 1. Create a product with 100 stock
    const stormCode = `STORM_${Date.now()}`;
    const createProdRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${ownerToken}`
      },
      body: JSON.stringify({
        clientBatchId: `batch_create_${stormCode}`,
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_prod_${stormCode}`,
            idempotencyKey: `idem_prod_${stormCode}`,
            mutationType: 'CREATE_PRODUCT',
            payload: {
              sku: stormCode,
              name: 'Idempotency Storm Biscuit',
              pricePaise: 2000,
              initialStockPieces: 100
            }
          }
        ]
      })
    });
    const createProdData = await createProdRes.json();
    assert.equal(createProdRes.status, 200);
    const productId = createProdData.results[0].serverBusinessId;

    // 2. Fire 20 identical requests with identical mutationId and idempotencyKey
    const stormIdemKey = `idem_storm_unique_${stormCode}`;
    const stormMutId = `mut_storm_unique_${stormCode}`;
    const stormPayload = {
      clientBatchId: `batch_storm_${stormCode}`,
      organizationId: 'comp_1',
      mutations: [
        {
          mutationId: stormMutId,
          idempotencyKey: stormIdemKey,
          mutationType: 'CREATE_ORDER',
          payload: {
            retailerId: sharedRetailerId,
            items: [{ productId, orderedQuantity: 5, orderedUnit: 'piece', unitPricePaise: 2000 }]
          }
        }
      ]
    };

    const stormPromises = Array.from({ length: 20 }).map(() =>
      fetch(`${BASE_URL}/sync/push`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${salesToken}`
        },
        body: JSON.stringify(stormPayload)
      }).then(async res => ({ status: res.status, body: await res.json() }))
    );

    const stormResponses = await Promise.all(stormPromises);

    // Every single one must succeed with HTTP 200
    for (const res of stormResponses) {
      assert.equal(res.status, 200);
      assert.equal(res.body.results[0].status, 'COMMITTED');
    }

    // Every single response must report the exact same serverBusinessId
    const firstBusinessId = stormResponses[0].body.results[0].serverBusinessId;
    assert.ok(firstBusinessId);
    for (const res of stormResponses) {
      assert.equal(res.body.results[0].serverBusinessId, firstBusinessId);
    }
  });

  test('3. Data Tamper & Negative Invariant Rejections', async () => {
    // 3.1 Order with negative quantity
    const negQtyRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_neg_qty',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_neg_qty_${Date.now()}`,
            idempotencyKey: `idem_neg_qty_${Date.now()}`,
            mutationType: 'CREATE_ORDER',
            payload: {
              retailerId: sharedRetailerId,
              items: [{ productId: sharedProductId, orderedQuantity: -10, orderedUnit: 'piece' }]
            }
          }
        ]
      })
    });
    assert.equal(negQtyRes.status, 400);
    const negQtyBody = await negQtyRes.json();
    assert.equal(negQtyBody.error, 'INVALID_ORDER_QUANTITY');

    // 3.2 Order with fractional / non-integer quantity
    const fracQtyRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_frac_qty',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_frac_qty_${Date.now()}`,
            idempotencyKey: `idem_frac_qty_${Date.now()}`,
            mutationType: 'CREATE_ORDER',
            payload: {
              retailerId: sharedRetailerId,
              items: [{ productId: sharedProductId, orderedQuantity: 2.75, orderedUnit: 'piece' }]
            }
          }
        ]
      })
    });
    assert.equal(fracQtyRes.status, 400);
    const fracQtyBody = await fracQtyRes.json();
    assert.equal(fracQtyBody.error, 'INVALID_ORDER_QUANTITY');

    // 3.3 Order with empty items array
    const emptyItemsRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_empty_items',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_empty_items_${Date.now()}`,
            idempotencyKey: `idem_empty_items_${Date.now()}`,
            mutationType: 'CREATE_ORDER',
            payload: {
              retailerId: sharedRetailerId,
              items: []
            }
          }
        ]
      })
    });
    assert.equal(emptyItemsRes.status, 400);
    const emptyItemsBody = await emptyItemsRes.json();
    assert.equal(emptyItemsBody.error, 'EMPTY_ORDER');
  });

  test('4. Ruthless Server RBAC Penetration Matrix', async () => {
    // 4.1 Salesperson attempts to update classification settings -> 403
    const classRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_sales_class',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_hack_class_${Date.now()}`,
            idempotencyKey: `idem_hack_class_${Date.now()}`,
            mutationType: 'UPDATE_CLASS_SETTINGS',
            payload: { classification: 'CLASS_A', creditLimitPaise: 99999999 }
          }
        ]
      })
    });
    assert.equal(classRes.status, 403);
    const classBody = await classRes.json();
    assert.equal(classBody.error, 'FORBIDDEN_ROLE_ACTION');

    // 4.2 Salesperson attempts to create product -> 403
    const prodRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_sales_prod',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_hack_prod_${Date.now()}`,
            idempotencyKey: `idem_hack_prod_${Date.now()}`,
            mutationType: 'CREATE_PRODUCT',
            payload: { name: 'Hacked Product', pricePaise: 100 }
          }
        ]
      })
    });
    assert.equal(prodRes.status, 403);
    const prodBody = await prodRes.json();
    assert.equal(prodBody.error, 'FORBIDDEN_ROLE_ACTION');

    // 4.3 Salesperson attempts to approve retailer -> 403
    const appRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${salesToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_sales_app',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_hack_app_${Date.now()}`,
            idempotencyKey: `idem_hack_app_${Date.now()}`,
            mutationType: 'APPROVE_RETAILER',
            payload: { retailerId: sharedRetailerId, creditLimitPaise: 1000000 }
          }
        ]
      })
    });
    assert.equal(appRes.status, 403);
    const appBody = await appRes.json();
    assert.equal(appBody.error, 'FORBIDDEN_ROLE_ACTION');

    // 4.4 Warehouse attempts to create order -> 403
    const whOrderRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${whToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_wh_order',
        organizationId: 'comp_1',
        mutations: [
          {
            mutationId: `mut_wh_order_${Date.now()}`,
            idempotencyKey: `idem_wh_order_${Date.now()}`,
            mutationType: 'CREATE_ORDER',
            payload: { retailerId: sharedRetailerId, items: [{ productId: sharedProductId, orderedQuantity: 1 }] }
          }
        ]
      })
    });
    assert.equal(whOrderRes.status, 403);
    const whOrderBody = await whOrderRes.json();
    assert.equal(whOrderBody.error, 'FORBIDDEN_ROLE_ACTION');
  });

  test('5. Multi-Tenant Cross-Access Breach Attack', async () => {
    // Comp 2 tries to order Comp 1 retailer
    const crossRes = await fetch(`${BASE_URL}/sync/push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${comp2OwnerToken}`
      },
      body: JSON.stringify({
        clientBatchId: 'batch_cross_ret',
        organizationId: 'comp_2',
        mutations: [
          {
            mutationId: `mut_cross_ret_${Date.now()}`,
            idempotencyKey: `idem_cross_ret_${Date.now()}`,
            mutationType: 'CREATE_ORDER',
            payload: {
              retailerId: sharedRetailerId, // Belongs to comp_1
              items: [{ productId: sharedProductId, orderedQuantity: 1, orderedUnit: 'piece' }]
            }
          }
        ]
      })
    });
    assert.equal(crossRes.status, 400);
    const crossBody = await crossRes.json();
    assert.equal(crossBody.error, 'RETAILER_NOT_FOUND');
  });
});
