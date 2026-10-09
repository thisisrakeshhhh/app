async function test() {
  const loginRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username: "warehouse", password: "password123" })
  });
  const loginData = await loginRes.json();
  console.log("Login HTTP status:", loginRes.status, "User role:", loginData.role, "Token exists:", !!loginData.access_token);
  const token = loginData.access_token;

  const stockRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/warehouse/stock", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  const stockData = await stockRes.json();
  console.log("Stock items count:", stockData.items?.length);
  if (stockData.items?.length > 0) {
    console.log("Sample product:", stockData.items[0].name, "stock:", stockData.items[0].stockQuantity, "barcode:", stockData.items[0].barcode);
  }

  const pickingRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/warehouse/picking-queue", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  const pickingData = await pickingRes.json();
  console.log("Picking orders count:", pickingData.orders?.length);
  if (pickingData.orders?.length > 0) {
    console.log("Sample picking order:", pickingData.orders[0].id, "status:", pickingData.orders[0].status, "items:", pickingData.orders[0].items?.length);
  }

  const dispatchRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/warehouse/dispatch-batches", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  const dispatchData = await dispatchRes.json();
  console.log("Dispatch batches count:", dispatchData.batches?.length);
  if (dispatchData.batches?.length > 0) {
    console.log("Sample dispatch batch:", dispatchData.batches[0].batchCode, "status:", dispatchData.batches[0].status, "cartons:", dispatchData.batches[0].totalCartons);
  }

  const returnsRes = await fetch("https://routeflow-api-staging.thisisrakesh21.workers.dev/warehouse/returns", {
    headers: { "Authorization": `Bearer ${token}` }
  });
  const returnsData = await returnsRes.json();
  console.log("Pending customer returns count:", returnsData.returns?.length);
  console.log("Pending driver returns count:", returnsData.undeliveredGoods?.length);
}
test().catch(console.error);
