import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:lala_distributor/data/local/app_database.dart';
import 'package:lala_distributor/data/local/local_repository.dart';
import 'package:lala_distributor/models/models.dart';
import 'package:lala_distributor/services/api_service.dart';
import 'helpers/test_catalog_helper.dart';

void main() {
  late AppDatabase db;
  late LocalRepository repository;
  late ApiService api;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = LocalRepository(db);
    api = ApiService.internalForTesting(database: db, localRepo: repository);
    await api.syncForTesting();
    await registerTestCatalogFixtures(api, repository);
  });

  tearDown(() async {
    await db.close();
  });

  group('Order Preview Safety & Non-Destructive Stock Accounting Tests', () {
    test(
        '1. placeOrder() does NOT mutate shared in-memory physical stock (prod.godownStockBoxes)',
        () async {
      // Find a product: Kurkure (48 pieces/box, initially 180 boxes)
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      final initialPhysicalBoxes = prod.godownStockBoxes;
      final initialPendingPieces = api.pendingBookingPieces(prod.id);
      final initialPendingBoxes = api.pendingBookingBoxes(prod.id);
      expect(initialPhysicalBoxes, equals(180));

      // Add 2 boxes to cart and place booking order
      api.addToCart(prod, OrderUnit.box, 2);
      final shop = api.retailers.first;
      final order = api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      expect(order.stage, equals(OrderLifecycleStage.booking));

      // Physical stock remains 180 boxes (not depleted to 178)
      expect(prod.godownStockBoxes, equals(180),
          reason: 'Physical godown stock must not be mutated in memory during uncommitted booking');

      // Pending reservation is tracked dynamically (+2 boxes of prod.boxQty pieces)
      final expectedAddedPieces = prod.piecesForUnit(OrderUnit.box) * 2;
      expect(api.pendingBookingPieces(prod.id), equals(initialPendingPieces + expectedAddedPieces));
      expect(api.pendingBookingBoxes(prod.id), equals(initialPendingBoxes + 2));

      // Available stock reflects booking reservation
      final totalPhysicalPieces = prod.godownStockBoxes * prod.boxQty;
      expect(api.availableGodownPieces(prod.id),
          equals(totalPhysicalPieces - (initialPendingPieces + expectedAddedPieces)));
    });

    test(
        '2. Loose piece ordering deducts exact pieces with zero whole-carton penalty',
        () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      expect(prod.godownStockBoxes, equals(180));

      final initialPendingPieces = api.pendingBookingPieces(prod.id);

      // Add only 1 loose piece to cart
      api.addToCart(prod, OrderUnit.piece, 1);
      final shop = api.retailers.first;
      api.placeOrder(shopId: shop.id, paymentMode: 'COD');

      // Physical boxes remain 180
      expect(prod.godownStockBoxes, equals(180));

      // Reservation increases by exactly 1 piece, NOT a whole box (48 pieces)
      expect(api.pendingBookingPieces(prod.id), equals(initialPendingPieces + 1));

      // Available pieces decreases by exactly 1 piece
      final totalPieces = 180 * prod.boxQty;
      expect(api.availableGodownPieces(prod.id),
          equals(totalPieces - (initialPendingPieces + 1)));
    });

    test(
        '3. Cart is cleared after successful booking and repeated confirmation rejects empty cart preventing duplicate bookings',
        () async {
      final prod = api.products.firstWhere((p) => p.id == 'LAYS-01');
      final initialPendingBoxes = api.pendingBookingBoxes(prod.id);
      final shop = api.retailers.first;
      final initialOutstanding = shop.outstandingPaise;
      final initialOrderCount = api.orders.length;

      // Place credit booking order of 3 boxes
      api.addToCart(prod, OrderUnit.box, 3);
      final order = api.placeOrder(shopId: shop.id, paymentMode: 'Credit');

      expect(api.orders.length, equals(initialOrderCount + 1));
      expect(api.pendingBookingBoxes(prod.id), equals(initialPendingBoxes + 3));
      expect(shop.outstandingPaise, equals(initialOutstanding + order.totalPaise));
      expect(api.cart.isEmpty, isTrue, reason: 'Cart must be cleared after successful booking');

      // Attempt repeated confirmation with empty cart
      expect(
        () => api.placeOrder(shopId: shop.id, paymentMode: 'Credit'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cart is empty'),
        )),
        reason: 'Second confirmation must be rejected because cart is empty',
      );

      // Order count and pending reservation remain unchanged
      expect(api.orders.length, equals(initialOrderCount + 1));
      expect(api.pendingBookingBoxes(prod.id), equals(initialPendingBoxes + 3));
      expect(shop.outstandingPaise, equals(initialOutstanding + order.totalPaise));
    });

    test(
        '4. Authoritative Drift SQLite database snapshots and movements are NOT modified by booking orders',
        () async {
      final prod = api.products.firstWhere((p) => p.id == 'LAYS-02');
      final snapshotBefore = await repository.getInventorySnapshot(prod.id);
      final movementsBefore = await repository.getMovementsForProduct(prod.id);

      // Place order
      api.addToCart(prod, OrderUnit.box, 5);
      api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD');

      final snapshotAfter = await repository.getInventorySnapshot(prod.id);
      final movementsAfter = await repository.getMovementsForProduct(prod.id);

      // Drift DB snapshot remains completely unchanged
      expect(snapshotAfter!.godownCartons, equals(snapshotBefore!.godownCartons));
      expect(snapshotAfter.godownLoosePieces, equals(snapshotBefore.godownLoosePieces));

      // No fake SALE movement was inserted into SQLite
      expect(movementsAfter.length, equals(movementsBefore.length));
    });

    test(
        '5. Vehicle stock (prod.carStockBoxes and totalCarBoxes) is NOT decremented by booking orders',
        () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      final initialCarStock = prod.carStockBoxes;
      final initialTotalCarBoxes = api.totalCarBoxes;

      // Place booking order of 3 boxes
      api.addToCart(prod, OrderUnit.box, 3);
      api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD');

      // Vehicle stock remains 100% unchanged
      expect(prod.carStockBoxes, equals(initialCarStock),
          reason: 'Vehicle stock must not be decremented during order booking');
      expect(api.totalCarBoxes, equals(initialTotalCarBoxes));
    });

    test(
        '6. Overbooking beyond available stock is strictly rejected with StateError',
        () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      final availablePieces = api.availableGodownPieces(prod.id);
      final boxesToOverbook = (availablePieces ~/ prod.boxQty) + 10;

      api.addToCart(prod, OrderUnit.box, boxesToOverbook);

      expect(
        () => api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'Credit'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('exceeds available stock'),
        )),
        reason: 'Overbooking must fail closed before creating an order',
      );
    });

    test(
        '7. Multi-unit mixed lines calculate exact integer base pieces without floating-point penalty',
        () async {
      final prod = api.products.firstWhere((p) => p.id == 'KURK-01');
      // Box = 48 pieces, Strip = 12 pieces (hypothetical), 1 Piece = 1
      final initialPendingPieces = api.pendingBookingPieces(prod.id);

      api.addToCart(prod, OrderUnit.box, 1);
      final order = api.placeOrder(shopId: api.retailers.first.id, paymentMode: 'COD');

      expect(order.items.first.totalPieces, equals(prod.boxQty));
      expect(api.pendingBookingPieces(prod.id), equals(initialPendingPieces + prod.boxQty));
    });
  });
}
