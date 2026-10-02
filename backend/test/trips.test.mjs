import assert from 'node:assert/strict';

export async function runTripsTest(baseUrl) {
  // 1. Login Owner
  const ownerRes = await fetch(`${baseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'owner', password: 'password123' })
  });
  const ownerData = await ownerRes.json();
  const ownerToken = ownerData.access_token;

  // 2. Fetch or create order to assign
  const ordersRes = await fetch(`${baseUrl}/orders`, {
    headers: { Authorization: `Bearer ${ownerToken}` }
  });
  const orders = await ordersRes.json();
  assert.ok(orders.length > 0, 'Should have orders to build trip');
  const orderId = orders[0].id;

  // 3. Create Delivery Trip
  const createTripRes = await fetch(`${baseUrl}/trips`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${ownerToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      driverId: 'user_delivery',
      vehicleNumber: 'RJ-14-GB-9988',
      routeArea: 'Jaipur Mansarovar & Sanganer',
      orderIds: [orderId]
    })
  });

  const tripData = await createTripRes.json();
  assert.equal(createTripRes.status, 200);
  assert.ok(tripData.id, 'Trip ID returned');
  assert.equal(tripData.vehicleNumber, 'RJ-14-GB-9988');

  // 4. Fetch Driver Active Trip
  const driverRes = await fetch(`${baseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'delivery', password: 'password123' })
  });
  const driverData = await driverRes.json();
  const driverToken = driverData.access_token;

  const activeTripRes = await fetch(`${baseUrl}/trips/active`, {
    headers: { Authorization: `Bearer ${driverToken}` }
  });
  const activeTrip = await activeTripRes.json();
  assert.equal(activeTrip.id, tripData.id);
  assert.equal(activeTrip.stops.length, 1);
  assert.equal(activeTrip.stops[0].orderId, orderId);

  // 5. Test duplicate order IDs in trip creation
  const dupTripRes = await fetch(`${baseUrl}/trips`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${ownerToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      driverId: 'user_delivery',
      vehicleNumber: 'RJ-14-GB-9988',
      routeArea: 'Jaipur Central',
      orderIds: [orderId, orderId]
    })
  });
  assert.equal(dupTripRes.status, 400, 'Duplicate order IDs must be rejected');

  // 6. Test assigning order that is already assigned to active trip
  const busyOrderTripRes = await fetch(`${baseUrl}/trips`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${ownerToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      driverId: 'user_delivery',
      vehicleNumber: 'RJ-14-GB-9988',
      routeArea: 'Jaipur Central',
      orderIds: [orderId]
    })
  });
  assert.equal(busyOrderTripRes.status, 400, 'Order already assigned to trip must be rejected');

  // 7. Test management role querying /trips/active without driverId query param
  const ownerActiveNoParam = await fetch(`${baseUrl}/trips/active`, {
    headers: { Authorization: `Bearer ${ownerToken}` }
  });
  assert.equal(ownerActiveNoParam.status, 400, 'Management role must provide driverId query param');

  // 8. Test management role querying /trips/active with driverId
  const ownerActiveWithParam = await fetch(`${baseUrl}/trips/active?driverId=user_delivery`, {
    headers: { Authorization: `Bearer ${ownerToken}` }
  });
  assert.equal(ownerActiveWithParam.status, 200);
  const ownerActiveData = await ownerActiveWithParam.json();
  assert.equal(ownerActiveData.id, tripData.id);

  // 9. Reorder: reject order not on trip
  const reorderForeignRes = await fetch(`${baseUrl}/trips/${tripData.id}/reorder`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${driverToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ stopOrder: ['order_does_not_exist'] })
  });
  assert.equal(reorderForeignRes.status, 400, 'Foreign order in reorder must be rejected');

  // 10. Reorder: valid stop sequence
  const reorderValidRes = await fetch(`${baseUrl}/trips/${tripData.id}/reorder`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${driverToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ stopOrder: [orderId] })
  });
  assert.equal(reorderValidRes.status, 200, 'Valid reorder must succeed');

  // 11. Start trip
  const startTripRes = await fetch(`${baseUrl}/trips/${tripData.id}/start`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${driverToken}` }
  });
  assert.equal(startTripRes.status, 200);
  const startData = await startTripRes.json();
  assert.equal(startData.status, 'OUT_FOR_DELIVERY');

  // 12. Complete trip
  const completeTripRes = await fetch(`${baseUrl}/trips/${tripData.id}/complete`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${driverToken}` }
  });
  assert.equal(completeTripRes.status, 200);
  const completeData = await completeTripRes.json();
  assert.equal(completeData.status, 'COMPLETED');

  // 13. Reorder completed trip must be rejected
  const reorderCompletedRes = await fetch(`${baseUrl}/trips/${tripData.id}/reorder`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${driverToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ stopOrder: [orderId] })
  });
  assert.equal(reorderCompletedRes.status, 400, 'Reordering completed trip must be rejected');
}
