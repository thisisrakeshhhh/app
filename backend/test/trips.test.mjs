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
}
