import { test, before } from 'node:test';
import assert from 'node:assert/strict';

const base = process.env.ROUTEFLOW_TEST_URL;
if (!base) throw new Error('Use run-isolated.mjs to execute warehouse tests');

const tokens = {};
const key = () => crypto.randomUUID();

async function req(role, path, body, method) {
  const r = await fetch(base + path, {
    method: method || (body ? 'POST' : 'GET'),
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${tokens[role]}`,
      'X-Test-Runner': 'true',
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const data = await r.json().catch(() => ({}));
  if (Array.isArray(data)) {
    data.httpStatus = r.status;
    return data;
  }
  return { httpStatus: r.status, ...data };
}


const ok = (r) => {
  assert.equal(r.httpStatus, 200, JSON.stringify(r));
  return r;
};

before(async () => {
  for (const role of ['owner', 'sales', 'warehouse', 'delivery', 'admin', 'owner_comp2']) {
    const res = await req(role, '/auth/login', { username: role, password: 'password123' });
    tokens[role] = res.access_token;
  }
});

test('1. Product Barcode Lookup & Image Update', async () => {
  // P1 has seed barcode '8901030000001'
  const found = ok(await req('warehouse', '/products/by-barcode/8901030000001'));
  assert.equal(found.id, 'P1');
  assert.equal(found.barcode, '8901030000001');

  // Unknown barcode returns 404
  const notFound = await req('warehouse', '/products/by-barcode/9999999999999');
  assert.equal(notFound.httpStatus, 404);

  // Update product image
  const imgRes = ok(await req('warehouse', '/products/P1/image', {
    imageUrl: 'https://images.routeflow.internal/products/p1.png',
    imageKey: 'products/p1.png'
  }));
  assert.equal(imgRes.success, true);

  // Verify lookup reflects updated image
  const updated = ok(await req('warehouse', '/products/P1'));
  assert.equal(updated.imageUrl, 'https://images.routeflow.internal/products/p1.png');
});

test('2. Stock Adjustment Atomicity & Constraints', async () => {
  const initialStockRes = ok(await req('warehouse', '/warehouse/stock'));
  const p2 = initialStockRes.products.find((p) => p.id === 'P2');
  const initialStock = p2.stockQuantity;

  // Inward GRN addition
  const inward = ok(await req('warehouse', '/warehouse/stock/adjust', {
    productId: 'P2',
    changeQuantity: 25,
    reason: 'INWARD_GRN',
    notes: 'GRN received from supplier'
  }));
  assert.equal(inward.newStockQuantity, initialStock + 25);

  // Cannot reduce stock below 0
  const overDeduct = await req('warehouse', '/warehouse/stock/adjust', {
    productId: 'P2',
    changeQuantity: -(initialStock + 100),
    reason: 'MANUAL_CORRECTION'
  });
  assert.equal(overDeduct.httpStatus, 400);

  // Verify stock movement ledger has logged the transaction
  const movements = ok(await req('warehouse', '/warehouse/stock/movements?productId=P2'));
  assert.ok(Array.isArray(movements));
  assert.ok(movements.some((m) => m.reason === 'INWARD_GRN' && m.quantity === 25));
});

test('3. Physical Stock Audit Reconciliation', async () => {
  const auditRes = ok(await req('warehouse', '/warehouse/stock/audit', {
    productId: 'P3',
    physicalCount: 45,
    notes: 'Physical count verified on Shelf B'
  }));
  assert.equal(auditRes.newStockQuantity, 45);

  const stockCheck = ok(await req('warehouse', '/warehouse/stock'));
  const p3 = stockCheck.products.find((p) => p.id === 'P3');
  assert.equal(p3.stockQuantity, 45);
});

test('4. Batch GRN and Near Expiry Query', async () => {
  const nowSec = Math.floor(Date.now() / 1000);
  const expiringSoonSec = nowSec + 15 * 86400; // 15 days out

  // Create near-expiry batch
  const batchRes = await req('warehouse', '/warehouse/batches', {
    productId: 'P4',
    batchNo: 'BATCH-EXP-01',
    receivedQuantity: 30,
    expiryDate: expiringSoonSec,
    rackBin: 'Bin-NearExp-1'
  });
  assert.equal(batchRes.httpStatus, 201);

  // Near expiry query returns this batch
  const nearExp = ok(await req('warehouse', '/warehouse/batches/near-expiry'));
  assert.ok(Array.isArray(nearExp));
  assert.ok(nearExp.some((b) => b.batchNo === 'BATCH-EXP-01'));
});

test('5. Picking Queue, Scan Pick & Carton Packing', async () => {
  // Sales creates an order with P1
  const orderId = `ORD_WH_${Date.now()}`;
  const now = Date.now();
  const orderCreate = await req('sales', '/orders', {
    order: {
      id: orderId,
      retailerId: 'R1',
      employeeId: 'user_sales',
      status: 'SUBMITTED',
      totalAmountPaise: 45000,
      createdAt: now,
      updatedAt: now,
    },
    items: [
      { id: `${orderId}_item`, productId: 'P1', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 45000, isPicked: false }
    ],
    idempotencyKey: `idemp_${orderId}`
  });
  assert.ok(orderCreate.httpStatus === 200 || orderCreate.httpStatus === 201, JSON.stringify(orderCreate));
  console.log('orderCreate response:', orderCreate);

  // Owner approves order
  ok(await req('owner', `/orders/${orderId}/approve`, {}));

  // Warehouse gets picking queue
  const queue = ok(await req('warehouse', '/warehouse/picking-queue'));
  const pickOrder = queue.orders.find((o) => o.id === orderId);
  assert.ok(pickOrder, 'Approved order must appear in picking queue');

  // Start picking
  ok(await req('warehouse', `/warehouse/orders/${orderId}/start-picking`, {}));

  // Scan wrong barcode rejects
  const wrongScan = await req('warehouse', `/warehouse/orders/${orderId}/scan-pick`, {
    barcode: '9999999999999' // non-matching barcode
  });
  assert.ok(wrongScan.httpStatus === 400 || wrongScan.httpStatus === 404);

  // Scan correct barcode succeeds
  const rightScan = ok(await req('warehouse', `/warehouse/orders/${orderId}/scan-pick`, {
    barcode: '8901030000001' // P1 barcode
  }));
  assert.equal(rightScan.isPicked, true);

  // Mark packed
  const packRes = ok(await req('warehouse', `/warehouse/orders/${orderId}/mark-packed`, {
    cartonsCount: 2,
    packingNotes: 'Fragile kirana parcel'
  }));
  assert.equal(packRes.status, 'PACKED');
  assert.equal(packRes.cartonsCount, 2);
});

test('6. Dispatch Batch Grouping & Delivery Handover', async () => {
  // Create another packed order
  const orderId2 = `ORD_DSP_${Date.now()}`;
  const now2 = Date.now();
  const ord2Res = await req('sales', '/orders', {
    order: {
      id: orderId2,
      retailerId: 'R2',
      employeeId: 'user_sales',
      status: 'SUBMITTED',
      totalAmountPaise: 12000,
      createdAt: now2,
      updatedAt: now2,
    },
    items: [
      { id: `${orderId2}_item`, productId: 'P2', quantity: 1, freeQuantity: 0, pricePaiseAtTime: 12000, isPicked: false }
    ],
    idempotencyKey: `idemp_${orderId2}`
  });
  console.log('order2 creation response:', ord2Res);
  ok(await req('owner', `/orders/${orderId2}/approve`, {}));

  ok(await req('warehouse', `/warehouse/orders/${orderId2}/start-picking`, {}));
  ok(await req('warehouse', `/warehouse/orders/${orderId2}/scan-pick`, { productId: 'P2' }));
  ok(await req('warehouse', `/warehouse/orders/${orderId2}/mark-packed`, { cartonsCount: 1 }));

  // Get delivery executives
  const drivers = ok(await req('warehouse', '/delivery-executives'));
  assert.ok(drivers.length > 0);
  const driverId = drivers[0].id;

  // Create dispatch batch
  const batchRes = await req('warehouse', '/warehouse/dispatch-batches', {
    orderIds: [orderId2],
    deliveryExecutiveId: driverId,
    notes: 'Morning Sector 1 dispatch'
  });
  assert.equal(batchRes.httpStatus, 201);
  assert.ok(batchRes.batchCode.startsWith('DSP-'));
  assert.equal(batchRes.totalCartons, 1);

  // Handover dispatch batch
  const handover = ok(await req('warehouse', `/warehouse/dispatch-batches/${batchRes.id}/handover`, {}));
  assert.equal(handover.status, 'HANDED_OVER');

  // Verify order is now OUT_FOR_DELIVERY
  const orderDetails = ok(await req('warehouse', `/orders/${orderId2}`));
  assert.equal(orderDetails.order.status, 'OUT_FOR_DELIVERY');
  assert.equal(orderDetails.order.deliveryEmployeeId, driverId);
});

test('7. Return Inspection (Saleable Restocks vs Damaged Blocks)', async () => {
  const stockBefore = ok(await req('warehouse', '/warehouse/stock'));
  const p7 = stockBefore.products.find((p) => p.id === 'P7');
  const initQty = p7.stockQuantity;

  // Inspect saleable return -> Restocks stock
  const saleableRes = ok(await req('warehouse', '/warehouse/returns/inspect', {
    productId: 'P7',
    quantity: 10,
    condition: 'SALEABLE',
    notes: 'Unopened box returned by shop'
  }));
  assert.equal(saleableRes.actionTaken, 'RESTOCKED_TO_GODOWN');
  assert.equal(saleableRes.newStockQuantity, initQty + 10);

  // Inspect damaged return -> Blocks from saleable
  const damagedRes = ok(await req('warehouse', '/warehouse/returns/inspect', {
    productId: 'P7',
    quantity: 5,
    condition: 'DAMAGED',
    notes: 'Torn packaging during transport'
  }));
  assert.equal(damagedRes.actionTaken, 'BLOCKED_DAMAGED');
  assert.equal(damagedRes.restocked, false);
  assert.equal(damagedRes.newStockQuantity, initQty + 10); // Not increased
});

test('8. Role Permissions Enforcement', async () => {
  // Sales cannot adjust warehouse stock
  const salesAdj = await req('sales', '/warehouse/stock/adjust', {
    productId: 'P1',
    changeQuantity: 10,
    reason: 'INWARD_GRN'
  });
  assert.equal(salesAdj.httpStatus, 403);

  // Delivery executive cannot create dispatch batches
  const deliveryDsp = await req('delivery', '/warehouse/dispatch-batches', {
    orderIds: ['dummy'],
  });
  assert.equal(deliveryDsp.httpStatus, 403);
});
