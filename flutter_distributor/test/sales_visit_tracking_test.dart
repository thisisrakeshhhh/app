import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalRepository repo;
  late ApiService api;

  const testSession = UserSession(
    userId: 'usr_sales_akhendera',
    name: 'Akhendera Singh',
    activeOrganizationId: 'org_jodhpur_dist',
    activeRole: 'SALES',
    organizations: [
      OrganizationMembership(
        id: 'org_jodhpur_dist',
        name: 'Jodhpur FMCG Distributors',
        role: 'SALES',
        isActive: true,
      ),
    ],
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalRepository(db);
    api = ApiService.internalForTesting(
      database: db,
      localRepo: repo,
      sessionProvider: () => testSession,
    );
    await api.syncForTesting(seed: true);
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await db.close();
  });

  group('Sales Beat Visit Tracking & Order-to-Inventory Sync Tests', () {
    test('1. Start and End visit accurately tracks elapsed time and format', () async {
      final shop = api.retailers.first;
      expect(shop.isCheckedIn, isFalse);
      expect(shop.totalTimeSpentSeconds, equals(0));

      // Start Visit
      api.startShopVisit(shop.id);
      expect(shop.isCheckedIn, isTrue);
      expect(shop.visitedToday, isTrue);
      expect(api.activeVisitShopId, equals(shop.id));

      // Simulate 15 seconds spent
      shop.currentVisitStartTime = DateTime.now().subtract(const Duration(seconds: 15));
      expect(shop.currentVisitSeconds, greaterThanOrEqualTo(14));

      // End Visit
      final elapsed = api.endShopVisit(shop.id);
      expect(shop.isCheckedIn, isFalse);
      expect(elapsed, greaterThanOrEqualTo(14));
      expect(shop.totalTimeSpentSeconds, greaterThanOrEqualTo(14));
      expect(shop.totalTimeSpentFormatted, contains('s'));
    });

    test('2. Skip shop records reason and terminates any active visit', () async {
      final shop = api.retailers.first;
      api.startShopVisit(shop.id);
      expect(api.activeVisitShopId, equals(shop.id));

      // Skip shop with reason "Shop Closed"
      api.skipShopVisit(shop.id, 'Shop Closed');

      expect(shop.isSkipped, isTrue);
      expect(shop.skipReason, equals('Shop Closed'));
      expect(api.activeVisitShopId, isNull);
      expect(api.customersSkippedTodayCount, equals(1));
    });

    test('3. Zomato-style Distance sequencing orders shops nearest to rep location', () {
      const repLat = 26.2850;
      const repLng = 73.0180;

      // Sardarpura Shop 1 (~300m away)
      const shop1Lat = 26.2875;
      const shop1Lng = 73.0195;
      final dist1 = ApiService.calculateDistanceMeters(repLat, repLng, shop1Lat, shop1Lng);

      // Nai Sadak Shop (~2.5km away)
      const shop2Lat = 26.2980;
      const shop2Lng = 73.0250;
      final dist2 = ApiService.calculateDistanceMeters(repLat, repLng, shop2Lat, shop2Lng);

      expect(dist1, lessThan(dist2));
      expect(dist1, lessThan(1000)); // Under 1 km
      expect(dist2, greaterThan(1000)); // Over 1 km
    });

    test('4. Booking order while checked in atomically creates order and decrements inventory', () async {
      final shop = api.retailers.first;
      api.startShopVisit(shop.id);
      api.selectShop(shop);

      final product = api.products.first;
      final initialBoxes = product.godownStockBoxes;
      expect(initialBoxes, greaterThan(5));

      // Add item to cart
      api.addToCart(product, OrderUnit.box, 2);
      expect(api.cart.isNotEmpty, isTrue);

      // Confirm order durable
      final order = await api.confirmOrderDurable(
        shopId: shop.id,
        paymentMode: 'CREDIT',
      );

      expect(order, isNotNull);
      expect(order.shopId, equals(shop.id));
      expect(shop.todayOrderTotalPaise, equals(order.totalPaise));

      // Verify inventory was automatically deducted
      final updatedProduct = api.products.firstWhere((p) => p.id == product.id);
      expect(updatedProduct.godownStockBoxes, equals(initialBoxes - 2));

      // Verify stock movement ledger in SQLite
      final movements = await (db.select(db.inventoryMovements)..where((tbl) => tbl.productId.equals(product.id))).get();
      expect(movements.any((m) => m.movementType == 'DISPATCH' && m.cartonDelta == -2), isTrue);
    });

    test('5. Trip Out and Trip In properly records vehicle and odometer reading', () {
      expect(api.isTripActive, isFalse);

      // Start Trip
      api.startTrip(
        routeName: 'Sardarpura Commercial Beat (SAR-02)',
        vehicleNo: 'RJ19GJ4742',
        meterReading: '42850',
      );
      expect(api.isTripActive, isTrue);
      expect(api.activeTripVehicleNo, equals('RJ19GJ4742'));
      expect(api.activeTripMeterReading, equals('42850'));

      // End Trip
      api.endTrip(meterReading: '42885');
      expect(api.isTripActive, isFalse);
      expect(api.activeTripEndMeterReading, equals('42885'));
    });
  });
}
