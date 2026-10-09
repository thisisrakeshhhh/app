async function verifyStagingWarehouse() {
  console.log("=== HARDCORE VERIFICATION: LIVE CLOUDFLARE STAGING WAREHOUSE API ===");

  // 1. Auth Login
  const loginRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username: "warehouse", password: "password123" })
  });
  if (!loginRes.ok) throw new Error(`Login failed with HTTP ${loginRes.status}`);
  const loginData = await loginRes.json();
  console.log(`✓ 1. Auth Login: HTTP 200 | Role: ${loginData.user?.role} | User: ${loginData.user?.fullName}`);
  const token = loginData.access_token;

  // 2. Godown Stock
  const stockRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/warehouse/stock", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  if (!stockRes.ok) throw new Error(`Stock query failed with HTTP ${stockRes.status}`);
  const stockData = await stockRes.json();
  console.log(`✓ 2. Godown Stock: HTTP 200 | Total SKUs: ${stockData.products?.length}`);
  if (stockData.products?.length > 0) {
    const sample = stockData.products[0];
    console.log(`   Sample SKU: ${sample.name} | Total: ${sample.stockQuantity} | Available: ${sample.availableStock} | Reserved: ${sample.reservedStock}`);
  }

  // 3. Picking Queue
  const pickingRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/warehouse/picking-queue", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  if (!pickingRes.ok) throw new Error(`Picking queue query failed with HTTP ${pickingRes.status}`);
  const pickingData = await pickingRes.json();
  console.log(`✓ 3. Picking Queue: HTTP 200 | Orders ready for picking/packing: ${pickingData.orders?.length}`);
  if (pickingData.orders?.length > 0) {
    const o = pickingData.orders[0];
    console.log(`   Sample Order: ${o.id} | Status: ${o.status} | Retailer: ${o.retailerName} | Items: ${o.items?.length}`);
  }

  // 4. Dispatch Batches
  const dispatchRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/warehouse/dispatch-batches", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  if (!dispatchRes.ok) throw new Error(`Dispatch batches query failed with HTTP ${dispatchRes.status}`);
  const dispatchData = await dispatchRes.json();
  const batches = Array.isArray(dispatchData) ? dispatchData : dispatchData.batches || [];
  console.log(`✓ 4. Dispatch Batches: HTTP 200 | Batches: ${batches.length}`);
  if (batches.length > 0) {
    const b = batches[0];
    console.log(`   Sample Batch: ${b.batchCode} | Status: ${b.status} | Cartons: ${b.totalCartons} | Driver: ${b.deliveryExecutiveName || b.deliveryExecutiveId}`);
  }

  // 5. Warehouse Returns Desk (Driver undelivered goods)
  const returnsRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/warehouse/returns", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  if (!returnsRes.ok) throw new Error(`Returns query failed with HTTP ${returnsRes.status}`);
  const returnsData = await returnsRes.json();
  console.log(`✓ 5. Driver Returns: HTTP 200 | Pending Undelivered: ${returnsData.pendingUndelivered?.length}`);
  if (returnsData.pendingUndelivered?.length > 0) {
    const r = returnsData.pendingUndelivered[0];
    console.log(`   Driver Return: ${r.id} | Order: ${r.orderId} | Product: ${r.productName} | Qty: ${r.quantity} | Reason: ${r.reason}`);
  }

  // 6. Customer RMA Returns
  const rmaRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/returns/pending", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  if (!rmaRes.ok) throw new Error(`Customer RMA query failed with HTTP ${rmaRes.status}`);
  const rmaData = await rmaRes.json();
  const rmaList = Array.isArray(rmaData) ? rmaData : rmaData.returns || [];
  console.log(`✓ 6. Customer RMA Returns: HTTP 200 | Pending RMA Requests: ${rmaList.length}`);
  if (rmaList.length > 0) {
    const rma = rmaList[0];
    console.log(`   Customer RMA: ${rma.id} | Retailer: ${rma.retailerName} | Reason: ${rma.reason} | Status: ${rma.status}`);
  }

  console.log("\n🎯 ALL 6 LIVE STAGING WAREHOUSE APIS VERIFIED 100% OPERATIONAL!");
}

verifyStagingWarehouse().catch((err) => {
  console.error("Verification failed:", err);
  process.exit(1);
});
